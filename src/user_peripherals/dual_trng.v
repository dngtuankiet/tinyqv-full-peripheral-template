// -----------------------------------------------------------------------------
// dual_trng.v  -  Simple sampler for 32-bit words from one of two TRNG bases
// Behavior:
//   1) Select base with iSel_base (0=long, 1=short)
//   2) Pulse iCalib -> enable selected base for iCalib_cycles clocks
//   3) After calibration, oReady=1
//   4) On rising edge of iRead while READY:
//        - oReady deasserts
//        - enable selected base
//        - shift 32 serial bits into a word
//        - latch to oRandom, oReady=1
// Ring bases are enabled ONLY during CALIBRATION or COLLECTING.
// -----------------------------------------------------------------------------
module dual_trng(
  input  wire        iClk,
  input  wire        iRst,

  // Calibration control
  input  wire        iCalib,          // start calibration for selected base
  input  wire [31:0] iCalib_cycles,   // how many clocks to keep the base enabled

  // Entropy cell controls
  input  wire [23:0] iTrigger,
  input  wire [23:0] iI1,
  input  wire [23:0] iI2,

  // Readout control
  input  wire        iSel_base,       // 0=long, 1=short (latched at calib start)
  input  wire        iRead,           // read request (pulse while READY)

  output wire        oReady,          // READY level (1 when a new read can start)
  output wire [31:0] oRandom          // last completed 32-bit word
);

  // --------------------------
  // Wires / regs
  // --------------------------
  wire [23:0] w_entropy;
  wire        w_oSerial_long;
  wire        w_oSerial_short;

  reg         en_rg_long;
  reg         en_rg_short;

  reg  [31:0] r_random_number;
  reg         r_ready;

  // FSM states
  localparam [1:0] S_IDLE   = 2'b00;
  localparam [1:0] S_CALIB  = 2'b01;
  localparam [1:0] S_READY  = 2'b10;
  localparam [1:0] S_COLLECT= 2'b11;

  reg  [1:0]  state, next_state;

  // Calibration, selection, and sampling
  reg  [31:0] calib_counter;
  reg  [5:0]  bit_counter;            // 0..32
  reg  [31:0] shift_reg;
  reg         selected_base;          // latched when calibration starts

  // iRead rising-edge detect (to avoid repeated triggers if held high)
  reg         r_iRead_q;
  wire        w_iRead_rise = iRead & ~r_iRead_q;

  // --------------------------
  // Entropy fabric (24 cells)
  // --------------------------
  genvar i;
  generate
    for (i = 0; i < 24; i = i + 1) begin : gen_entropy_cells
      entropy_cell ec (
        .T(iTrigger[i]),
        .I1(iI1[i]),
        .I2(iI2[i]),
        .oEntropy(w_entropy[i])
      );
    end
  endgenerate

  // --------------------------
  // Ring generators
  // --------------------------
  rg_base_long u_rg_long (
    .iClk(iClk),
    .iRst(iRst),
    .iEn (en_rg_long),
    .iEntropy(w_entropy[23:0]),
    .oSerial(w_oSerial_long)
  );

  rg_base_short u_rg_short (
    .iClk(iClk),
    .iRst(iRst),
    .iEn (en_rg_short),
    .iEntropy(w_entropy[7:0]),
    .oSerial(w_oSerial_short)
  );

  // --------------------------
  // Sequential: state & datapath
  // --------------------------
  always @(posedge iClk) begin
    if (iRst) begin
      state           <= S_IDLE;
      calib_counter   <= 32'd0;
      bit_counter     <= 6'd0;
      shift_reg       <= 32'd0;
      r_random_number <= 32'd0;
      selected_base   <= 1'b0;
      r_iRead_q       <= 1'b0;
    end else begin
      state     <= next_state;
      r_iRead_q <= iRead;

      // Latch base selection at the moment calibration begins
      if (state == S_IDLE && iCalib) begin
        selected_base <= iSel_base;
      end

      // Calibration counter: run only in S_CALIB
      if (state == S_CALIB) begin
        calib_counter <= calib_counter + 32'd1;
      end else begin
        calib_counter <= 32'd0;
      end

      // Collection: shift exactly 32 bits while enabled
      if (state == S_COLLECT) begin
        if (bit_counter < 6'd32) begin
          shift_reg   <= selected_base
                        ? {shift_reg[30:0], w_oSerial_short}
                        : {shift_reg[30:0], w_oSerial_long};
          bit_counter <= bit_counter + 6'd1;

          // Latch completed word on the 32nd shift (bit_counter==31 before inc)
          if (bit_counter == 6'd31) begin
            r_random_number <= selected_base
              ? {shift_reg[30:0], w_oSerial_short}
              : {shift_reg[30:0], w_oSerial_long};
          end
        end
      end else begin
        bit_counter <= 6'd0;
      end
    end
  end

  // --------------------------
  // Combinational: next state
  // --------------------------
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (iCalib) next_state = S_CALIB;
      end

      S_CALIB: begin
        // Complete after iCalib_cycles clocks (0 means immediate)
        if ((calib_counter + 32'd1) >= iCalib_cycles)
          next_state = S_READY;
      end

      S_READY: begin
        // Start a new sample only on a rising edge of iRead
        if (w_iRead_rise)
          next_state = S_COLLECT;
      end

      S_COLLECT: begin
        if (bit_counter == 6'd32)
          next_state = S_READY;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // --------------------------
  // Combinational: outputs/enables
  // --------------------------
  always @(*) begin
    // Defaults
    en_rg_long   = 1'b0;
    en_rg_short  = 1'b0;
    r_ready      = 1'b0;

    case (state)
      S_IDLE: begin
        // everything disabled
      end

      S_CALIB: begin
        // Enable ONLY selected base during calibration
        if (selected_base) en_rg_short = 1'b1;
        else               en_rg_long  = 1'b1;
      end

      S_READY: begin
        // Ready to accept a read; bases disabled per your requirement
        r_ready = 1'b1;
      end

      S_COLLECT: begin
        // Enable ONLY selected base while collecting
        if (selected_base) en_rg_short = 1'b1;
        else               en_rg_long  = 1'b1;
      end
    endcase
  end

  assign oRandom = r_random_number;
  assign oReady  = r_ready;

endmodule