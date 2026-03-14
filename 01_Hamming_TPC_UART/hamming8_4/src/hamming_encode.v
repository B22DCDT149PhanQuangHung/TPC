//////////////////////////////////////////////////////////////////
// =============================================================//
// Hamming(8,4) Encoder (ESA/CCSDS standard, systematic form)
// Output bits: [d3 d2 d1 d0 p3 p2 p1 p0]
// =============================================================//
//////////////////////////////////////////////////////////////////
module hamming_encoder_8_4 (
  input  wire [3:0] d_in,
  output wire [3:0] p,
  output wire [7:0] d_out
);
  // 3 parity nhóm
  assign p[3] = d_in[3] ^ d_in[2] ^ d_in[0];
  assign p[2] = d_in[3] ^ d_in[1] ^ d_in[0];
  assign p[1] = d_in[2] ^ d_in[1] ^ d_in[0];
  // p0 là parity tổng (even parity)
  assign p[0] = d_in[3] ^ d_in[2] ^ d_in[1] ^ d_in[0] ^ p[3] ^ p[2] ^ p[1];

  assign d_out = {d_in, p};
endmodule