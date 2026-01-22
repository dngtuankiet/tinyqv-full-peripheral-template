// -----------------------------------------------------------------------------
// upt.v  -  Universal PUF/TRNG peripheral top module
// Description:
//   - Supports two operating modes: TRNG (True Random Number Generator) and PUF (Physical Unclonable Function).
//   - Interfaces with 50 entropy cells for entropy collection and masking.
//   - Includes calibration and seeding logic for ring generator operation.
//   - Provides a state machine to manage calibration, seeding, entropy collection, and data readout.
//   - Outputs 64-bit random or PUF data, split into two 32-bit words.
//   - Handles calibration cycles, entropy masking, and readout synchronization.
// -----------------------------------------------------------------------------
module upt(
  //Control
  input  wire        iMode, // 0: TRNG, 1: PUF

  //For Entropy Cells
  input  wire [49:0] iTrigger,
  input  wire [49:0] iI1,
  input  wire [49:0] iI2,
  input  wire [49:0] iMask, // set 0 to ignore corresponding entropy cell
  output wire [49:0] oCapturedEntropy,
  
  //For RG Base
  input  wire        iClk,
  input  wire        iRst,
  input  wire        iEn,
  input  wire        iInit,
  input  wire [63:0] iSeed,
  output wire [63:0] oTestState,


  // Calibration control
  input  wire        iCalib,          // start calibration signal
  input  wire [31:0] iCalib_cycles,   // how many clocks to keep the base enabled

  

  // Readout control
  input  wire        iRead,           // read request (pulse while READY)
  output wire        oReady,          // READY level (1 when a new read can start)
  output wire [31:0] oSample_0,       // 32-bit LSB sample
  output wire [31:0] oSample_1        // 32-bit MSB sample
);

  // --------------------------
  // Wires / regs
  // --------------------------
  wire [49:0] w_entropy;
  wire        w_oSerial;

  reg         w_enable_rg;

  reg  [63:0] r_random_number;
  reg         w_ready;

  // FSM states
  localparam [2:0] S_IDLE     = 3'b000;
  localparam [2:0] S_SEEDING  = 3'b001;
  localparam [2:0] S_CALIB    = 3'b010;
  localparam [2:0] S_READY    = 3'b011;
  localparam [2:0] S_COLLECT  = 3'b100;

  reg  [2:0]  state, next_state;
  // Calibration, selection, and sampling
  reg  [31:0] calib_counter;
  reg  [6:0]  bit_counter;
  reg  [63:0] shift_reg; //collect oSample


  // Masking
  reg [49:0] r_captured_entropy;
  integer j;
  always @(posedge iClk) begin
    if (iRst) begin
      r_captured_entropy <= 50'd0;
    end else if (iEn && iMode) begin
      for (j = 0; j < 50; j = j + 1) begin
        if (iTrigger[j] & !r_captured_entropy[j]) begin
          r_captured_entropy[j] <= w_entropy[j]; // Capture masked entropy for each cell
        end
      end
    end
  end

  wire [49:0] w_injected_entropy = iMode ? r_captured_entropy & iMask : w_entropy;


  // Edge detection for iRead
  reg r_read_prev;
  wire w_iRead_rise = iRead & ~r_read_prev;

  // --------------------------
  // Entropy fabric (50 cells)
  // --------------------------
  genvar i;
  generate
    for (i = 0; i < 50; i = i + 1) begin : gen_entropy_cells
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
  rg_base_extra_long u_rg_extra_long (
    .iClk(iClk),
    .iRst(iRst),
    .iEn (w_enable_rg),
    .iInit(iInit),
    .iChallenge(iSeed),
    .iEntropy(w_injected_entropy),
    .oState(oTestState),
    .oSerial(w_oSerial)
  );
  // --------------------------
  // Sequential: state & datapath
  // --------------------------
  always @(posedge iClk) begin
    if (iRst) begin
      state           <= S_IDLE;
      calib_counter   <= 32'd0;
      bit_counter     <= 7'd0;
      shift_reg       <= 64'd0;
      r_random_number <= 64'd0;
      r_read_prev     <= 1'b0;
    end else begin
      if(iEn) begin
        state <= next_state;
        r_read_prev <= iRead;

        // Calibration counter: run only in S_CALIB
        calib_counter <= (state == S_CALIB) ? calib_counter + 32'd1 : 32'd0;

        // Collection: shift exactly 64 bits while enabled
        if (state == S_COLLECT && bit_counter < 7'd64) begin
          shift_reg <= {shift_reg[62:0], w_oSerial};
          bit_counter <= bit_counter + 7'd1;

          // Latch completed word on the 64th shift
          if (bit_counter == 7'd63) begin
            r_random_number <= {shift_reg[62:0], w_oSerial};
          end
        end else if (state != S_COLLECT) begin
          bit_counter <= 7'd0;
        end
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
        if (~iMode && iCalib) next_state = S_CALIB;
        if (iMode && iInit) next_state = S_SEEDING;
      end

      S_SEEDING: begin
        if(iCalib) next_state = S_CALIB;
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
        if (bit_counter == 7'd64)
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
    w_enable_rg = 1'b0;
    w_ready = 1'b0;

    case (state)
      S_IDLE: begin
        // All outputs at default values
      end

      S_SEEDING: begin
        // Enable selected ring generator during seeding
        w_enable_rg = iInit;
      end

      S_CALIB, S_COLLECT: begin
        // Enable selected ring generator during calibration and collection
        w_enable_rg = 1'b1;
      end

      S_READY: begin
        // Ready to accept read requests
        w_ready = 1'b1;
      end

      default: begin
        // All outputs at default values
      end
    endcase
  end

  assign oCapturedEntropy = r_captured_entropy;
  assign oSample_0 = iEn ? r_random_number[31:0] : 32'h0;
  assign oSample_1 = iEn ? r_random_number[63:32] : 32'h0;
  assign oReady  = iEn ? w_ready : 1'b0;

endmodule