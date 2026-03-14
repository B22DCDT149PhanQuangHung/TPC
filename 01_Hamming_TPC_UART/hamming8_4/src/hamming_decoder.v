// Hamming(8,4) decoder (extended Hamming) matching the encoder ordering:
// Encoder/d_in ordering: [d3 d2 d1 d0 p3 p2 p1 p0] -> d_in[7:0]
// Outputs:
//  - d_out[7:0]    : corrected full codeword (same ordering)
//  - data_out[3:0] : corrected data bits (d3..d0)
//  - corrected     : 1 if a single-bit correction was applied
//  - uncorrectable : 1 if detected uncorrectable error (e.g., double error)
//  - err_pos[2:0]  : bit position (0..7) that was flipped when corrected; 3'b111 = no valid position
module hamming_decoder_8_4 (
  input  wire [7:0] d_in,
  output wire [7:0] d_out,
  output wire [3:0] data_out,
  output wire       corrected,
  output wire       uncorrectable,
  output reg  [2:0] err_pos
);

  wire [2:0] syn;
  // syn[0] = s0, syn[1] = s1, syn[2] = s2
  assign syn[0] = d_in[7] ^ d_in[6] ^ d_in[4] ^ d_in[3];
  assign syn[1] = d_in[7] ^ d_in[5] ^ d_in[4] ^ d_in[2];
  assign syn[2] = d_in[6] ^ d_in[5] ^ d_in[4] ^ d_in[1];

  wire parity = ^d_in; // overall parity (1 => parity error)

  reg [7:0] corr_word;
  reg corr_flag;
  reg uerr_flag;

  always @(*) begin
    corr_word = d_in;
    corr_flag = 1'b0;
    uerr_flag = 1'b0;
    err_pos = 3'b111; // default = invalid / no correction

    if (syn == 3'b000) begin
      if (parity == 1'b1) begin
        // single-bit error on overall parity bit (p0 at bit 0)
        corr_word = d_in ^ 8'b0000_0001; // flip bit 0
        corr_flag = 1'b1;
        err_pos = 3'd0;
      end else begin
        // no error
        corr_word = d_in;
        corr_flag = 1'b0;
        err_pos = 3'b111;
      end
    end else begin
      if (parity == 1'b1) begin
        // single-bit error: syndrome indicates bit position to flip
        case (syn) // syn is {s2,s1,s0} with syn[2]=s2 ... syn[0]=s0
          3'b001: begin corr_word = d_in ^ (8'b1 << 3); err_pos = 3'd3; end // flip bit 3 (p3)
          3'b010: begin corr_word = d_in ^ (8'b1 << 2); err_pos = 3'd2; end // flip bit 2 (p2)
          3'b011: begin corr_word = d_in ^ (8'b1 << 7); err_pos = 3'd7; end // flip bit 7 (d3)
          3'b100: begin corr_word = d_in ^ (8'b1 << 1); err_pos = 3'd1; end // flip bit 1 (p1)
          3'b101: begin corr_word = d_in ^ (8'b1 << 6); err_pos = 3'd6; end // flip bit 6 (d2)
          3'b110: begin corr_word = d_in ^ (8'b1 << 5); err_pos = 3'd5; end // flip bit 5 (d1)
          3'b111: begin corr_word = d_in ^ (8'b1 << 4); err_pos = 3'd4; end // flip bit 4 (d0)
          default: begin corr_word = d_in; err_pos = 3'b111; end
        endcase
        corr_flag = 1'b1;
      end else begin
        // syndrome != 0 but overall parity even -> detected multi-bit error (uncorrectable)
        corr_word = d_in;
        corr_flag = 1'b0;
        uerr_flag = 1'b1;
        err_pos = 3'b111;
      end
    end
  end

  assign d_out = corr_word;
  assign data_out = corr_word[7:4]; // d3..d0
  assign corrected = corr_flag;
  assign uncorrectable = uerr_flag;

endmodule