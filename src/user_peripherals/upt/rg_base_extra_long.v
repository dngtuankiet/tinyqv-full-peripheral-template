//-----Ring Generator Base primitive polynomial-----
module rg_base_extra_long(
  input         iClk,
  input         iRst,
  input         iEn,
  input         iInit,
  input  [63:0] iChallenge,
  input  [49:0] iEntropy,
  output        oSerial,
  output [63:0] oState
);
  reg [63:0] state;
  wire [63:0] next_state;

  assign oSerial = state[0];
  assign oState  = state;

  // Compute next state combinationally
  assign next_state[0]  = state[1] ^ iEntropy[49];
  assign next_state[1]  = state[2] ^ iEntropy[48];
  assign next_state[2]  = state[3] ^ iEntropy[47];
  assign next_state[3]  = state[4];
  assign next_state[4]  = state[5] ^ iEntropy[46];
  assign next_state[5]  = state[6] ^ iEntropy[45];
  assign next_state[6]  = state[7];
  assign next_state[7]  = state[8] ^ iEntropy[44];                   
  assign next_state[8]  = state[9] ^ iEntropy[43];
  assign next_state[9]  = state[10] ^ iEntropy[42];
  assign next_state[10] = state[11] ^ iEntropy[41];
  assign next_state[11] = state[12];
  assign next_state[12] = state[13] ^ iEntropy[40];
  assign next_state[13] = state[14] ^ iEntropy[39];
  assign next_state[14] = state[15] ^ iEntropy[38];
  assign next_state[15] = state[16];             
  assign next_state[16] = state[17] ^ iEntropy[37];
  assign next_state[17] = state[18] ^ iEntropy[36];
  assign next_state[18] = state[19] ^ iEntropy[35];     
  assign next_state[19] = state[20] ^ iEntropy[34];
  assign next_state[20] = state[21] ^ iEntropy[33];
  assign next_state[21] = state[22] ^ iEntropy[32];
  assign next_state[22] = state[23] ^ iEntropy[31];       
  assign next_state[23] = state[24];
  assign next_state[24] = state[25] ^ iEntropy[30];
  assign next_state[25] = state[26] ^ iEntropy[29];    
  assign next_state[26] = state[27] ^ iEntropy[28];
  assign next_state[27] = state[28];       
  assign next_state[28] = state[29] ^ iEntropy[27];
  assign next_state[29] = state[30] ^ iEntropy[26];
  assign next_state[30] = state[31] ^ iEntropy[25];
  assign next_state[31] = state[32];
  assign next_state[32] = state[33] ^ iEntropy[24];
  assign next_state[33] = state[34] ^ iEntropy[23];
  assign next_state[34] = state[35] ^ iEntropy[22];
  assign next_state[35] = state[36] ^ state[28];
  assign next_state[36] = state[37] ^ iEntropy[21];
  assign next_state[37] = state[38] ^ iEntropy[20];
  assign next_state[38] = state[39] ^ iEntropy[19];
  assign next_state[39] = state[40] ^ state[24];
  assign next_state[40] = state[41] ^ iEntropy[18];
  assign next_state[41] = state[42] ^ iEntropy[17];
  assign next_state[42] = state[43] ^ iEntropy[16];
  assign next_state[43] = state[44] ^ iEntropy[15];
  assign next_state[44] = state[45] ^ iEntropy[14];
  assign next_state[45] = state[46] ^ iEntropy[13];
  assign next_state[46] = state[47] ^ state[16];
  assign next_state[47] = state[48] ^ iEntropy[12];
  assign next_state[48] = state[49] ^ iEntropy[11];
  assign next_state[49] = state[50] ^ iEntropy[10];
  assign next_state[50] = state[51] ^ iEntropy[9];
  assign next_state[51] = state[52] ^ state[12];
  assign next_state[52] = state[53] ^ iEntropy[8];
  assign next_state[53] = state[54] ^ iEntropy[7];
  assign next_state[54] = state[55] ^ iEntropy[6];
  assign next_state[55] = state[56] ^ state[7];
  assign next_state[56] = state[57] ^ iEntropy[5];
  assign next_state[57] = state[58] ^ iEntropy[4];
  assign next_state[58] = state[59] ^ iEntropy[3];
  assign next_state[59] = state[60] ^ state[4];
  assign next_state[60] = state[61] ^ iEntropy[2];
  assign next_state[61] = state[62] ^ iEntropy[1];
  assign next_state[62] = state[63] ^ iEntropy[0];
  assign next_state[63] = state[0];

  // Single clocked process for state update
  always @(posedge iClk) begin
    if (iRst) begin
      state <= 64'h0; // Reset state to zero - iEntropy will break the non-zero state
    end 
    else if (iEn) begin
      if(iInit) begin
        state <= iChallenge; // Initialize state with provided value
      end else begin
        state <= next_state; // Normal operation: update state
      end
    end
  end

endmodule