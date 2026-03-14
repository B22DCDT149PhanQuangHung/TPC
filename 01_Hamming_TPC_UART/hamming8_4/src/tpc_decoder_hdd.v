`timescale 1ns/1ps
// =============================================================
// TPC Decoder - HDD (Hard-Decision, serial, resource‑light)
// - Uses extended Hamming(8,4) decoder (combinational) as component
// - Iterative row/column hard-decision passes (binary decisions 0/1)
// - Early stop when no corrections in an iteration or after MAX_ITER
// - Input: d_in (64-bit row-major as tpc_encoder_s produces)
// - Outputs:
//    data_out        : 16-bit payload (4x4 row-wise)
//    done            : 1-cycle done pulse
//    iter_used       : number of iterations actually used
//    total_corrections : total number of single-bit corrections applied
//    any_uncorrectable : set if any component decoder reported uncorrectable error
//    last_corr_pos     : linear position (0..63) of last correction (row*8 + col), 6 bits
// =============================================================
module tpc_decoder_hdd #(
  parameter MAX_ITER = 4
)(
  input  wire        clk,
  input  wire        rst_n,
  input  wire [63:0] d_in,   // 8x8 codeword row-major
  input  wire        start,  // start pulse (one cycle)
  output reg  [15:0] data_out,// decoded 16-bit payload (4x4 row-wise)
  output reg         done,    // one-cycle done pulse
  output reg  [3:0]  iter_used,// number of iterations actually used
  output reg  [15:0] total_corrections, // total corrections applied during whole decode
  output reg         any_uncorrectable, // 1 if any ham_uncorr observed
  output reg  [5:0]  last_corr_pos      // last corrected bit pos: row*8 + col (0..63)
);

  // FSM
  localparam S_IDLE   = 3'd0;
  localparam S_LOAD   = 3'd1;
  localparam S_ROW    = 3'd2;
  localparam S_COL    = 3'd3;
  localparam S_CHECK  = 3'd4;
  localparam S_DONE   = 3'd5;

  reg [2:0] state;
  reg [3:0] idx;         // 0..7 index for row/col
  reg [2:0] iter;        // iteration counter

  integer r;

  // row registers: 8 rows x 8 bits
  reg [7:0] row_regs [7:0];

  // combinational column word
  reg [7:0] col_word;

  // hamming decoder interface wires
  wire [7:0] ham_in;
  wire [7:0] ham_out;
  wire [3:0] ham_data;
  wire       ham_corr;
  wire       ham_uncorr;
  wire [2:0] ham_errpos;

  // choose ham input depending on state
  assign ham_in = (state == S_ROW) ? row_regs[idx] : col_word;

  // instantiate hamming decoder (combinational)
  hamming_decoder_8_4 ham (
    .d_in         (ham_in),
    .d_out        (ham_out),
    .data_out     (ham_data),
    .corrected    (ham_corr),
    .uncorrectable(ham_uncorr),
    .err_pos      (ham_errpos)
  );

  // build column word: col_word[7-r] = row_regs[r][7-idx]
  always @(*) begin
    col_word = 8'h00;
    for (r = 0; r < 8; r = r + 1) begin
      col_word[7 - r] = row_regs[r][7 - idx];
    end
  end

  // track whether any correction happened during current full iteration (row+col)
  reg corrections_flag;

  // FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      idx <= 0;
      iter <= 0;
      iter_used <= 0;
      done <= 0;
      corrections_flag <= 1'b0;
      data_out <= 16'h0;
      total_corrections <= 16'h0;
      any_uncorrectable <= 1'b0;
      last_corr_pos <= 6'h3F; // 0x3F = invalid/default
      for (r = 0; r < 8; r = r + 1) row_regs[r] <= 8'h00;
    end else begin
      done <= 1'b0; // default deassert
      case (state)
        S_IDLE: begin
          if (start) begin
            state <= S_LOAD;
          end
          idx <= 0;
          iter <= 0;
          corrections_flag <= 1'b0;
          total_corrections <= 16'h0;
          any_uncorrectable <= 1'b0;
          last_corr_pos <= 6'h3F;
        end

        S_LOAD: begin
          // load rows from input (row-major)
          for (r = 0; r < 8; r = r + 1) row_regs[r] <= d_in[63 - r*8 -: 8];
          idx <= 0;
          iter <= 0;
          corrections_flag <= 1'b0;
          state <= S_ROW;
        end

        S_ROW: begin
          // decode current row; ham_out available combinationally from ham_in
          // write back corrected row and collect correction flag
          row_regs[idx] <= ham_out;

          // update counters/flags based on ham_corr/ham_uncorr (use values from this ham_in)
          if (ham_corr) begin
            total_corrections <= total_corrections + 1;
            // for row pass: corrected bit position -> row = idx, col = 7 - ham_errpos
            last_corr_pos <= (idx << 3) | (6'd0 + (7 - ham_errpos)); // idx*8 + (7 - ham_errpos)
            corrections_flag <= 1'b1;
          end
          if (ham_uncorr) begin
            any_uncorrectable <= 1'b1;
          end

          if (idx == 7) begin
            idx <= 0;
            state <= S_COL;
          end else begin
            idx <= idx + 1;
          end
        end

        S_COL: begin
          // decode current column (col_word), ham_out is corrected column code
          // write corrected bits back into rows
          for (r = 0; r < 8; r = r + 1) begin
            row_regs[r][7 - idx] <= ham_out[7 - r];
          end

          // update counters/flags based on ham_corr/ham_uncorr
          if (ham_corr) begin
            total_corrections <= total_corrections + 1;
            // for col pass: corrected bit position -> row = 7 - ham_errpos, col = idx
            last_corr_pos <= ((7 - ham_errpos) << 3) | idx; // (7-ham_errpos)*8 + idx
            corrections_flag <= 1'b1;
          end
          if (ham_uncorr) begin
            any_uncorrectable <= 1'b1;
          end

          if (idx == 7) begin
            state <= S_CHECK;
            idx <= 0;
          end else begin
            idx <= idx + 1;
          end
        end

        S_CHECK: begin
          // completed one full iteration (row + column passes)
          iter <= iter + 1;
          // if no corrections this iteration or reached MAX_ITER -> done
          if ((corrections_flag == 1'b0) || (iter + 1 >= MAX_ITER)) begin
            // extract payload (top-left 4x4: rows 0..3, bits 7:4)
            data_out <= { row_regs[0][7:4], row_regs[1][7:4], row_regs[2][7:4], row_regs[3][7:4] };
            done <= 1'b1;
            iter_used <= iter + 1;
            state <= S_DONE;
          end else begin
            // start next iteration
            corrections_flag <= 1'b0;
            idx <= 0;
            state <= S_ROW;
          end
        end

        S_DONE: begin
          // wait for start deassert to return to IDLE
          if (!start) begin
            state <= S_IDLE;
            iter <= 0;
            corrections_flag <= 1'b0;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule