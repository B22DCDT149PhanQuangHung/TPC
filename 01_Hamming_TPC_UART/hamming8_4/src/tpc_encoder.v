// =============================================================
// Turbo Product Code (TPC) Encoder using Hamming(8,4) - Serial Version
// ESA/CCSDS systematic form: (8,4)x(8,4)
// Input : 16 data bits (4x4 matrix row-wise)
// Output: 64 code bits (8x8 matrix row-wise)
// To save resources, use a single Hamming encoder with multiplexing
// Ports normalized: d_in (was data_in), d_out (was code_out)
// =============================================================
module tpc_encoder_s (
  input  wire        clk,
  input  wire        rst_n,
  input  wire [15:0] d_in,
  input  wire        start,  // Pulse to start encoding
  output reg  [63:0] d_out,
  output reg         done    // Asserted when encoding complete
);

  // States
  localparam IDLE     = 3'd0;
  localparam ROW_ENC  = 3'd1;
  localparam COL_PREP = 3'd2;
  localparam COL_ENC  = 3'd3;
  localparam PACK     = 3'd4;

  reg [2:0] state;
  reg [3:0] cnt;  // Counter for rows/columns

  // Intermediate storage: 4 rows x 8 bits
  reg [7:0] row_code_reg [3:0];

  // Column codes storage: 8 columns x 8 bits
  reg [7:0] col_code_reg [7:0];

  // Column data for encoding
  reg [3:0] col_data_cur;

  // Single Hamming encoder
  wire [3:0] enc_d_in;
  wire [7:0] enc_d_out;
  hamming_encoder_8_4 enc_inst (
    .d_in  (enc_d_in),
    .p (),
    .d_out (enc_d_out)
  );

  // Mux for encoder input
  assign enc_d_in = (state == ROW_ENC) ? d_in[15 - 4*cnt -: 4] : col_data_cur;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cnt <= 0;
      done <= 0;
      d_out <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= ROW_ENC;
            cnt <= 0;
          end
        end
        ROW_ENC: begin
          // Encode row cnt
          row_code_reg[cnt] <= enc_d_out;
          if (cnt == 3) begin
            state <= COL_PREP;
            cnt <= 0;
          end else begin
            cnt <= cnt + 1;
          end
        end
        COL_PREP: begin
          // Prepare col_data_cur for column cnt
          col_data_cur <= {
            row_code_reg[0][7 - cnt],
            row_code_reg[1][7 - cnt],
            row_code_reg[2][7 - cnt],
            row_code_reg[3][7 - cnt]
          };
          state <= COL_ENC;
        end
        COL_ENC: begin
          // Store column code
          col_code_reg[cnt] <= enc_d_out;
          state <= (cnt == 7) ? PACK : COL_PREP;
          cnt <= cnt + 1;
        end
        PACK: begin
          // Pack the 8x8 matrix into d_out row-major
          d_out[63:56] <= {col_code_reg[0][7], col_code_reg[1][7], col_code_reg[2][7], col_code_reg[3][7], col_code_reg[4][7], col_code_reg[5][7], col_code_reg[6][7], col_code_reg[7][7]};
          d_out[55:48] <= {col_code_reg[0][6], col_code_reg[1][6], col_code_reg[2][6], col_code_reg[3][6], col_code_reg[4][6], col_code_reg[5][6], col_code_reg[6][6], col_code_reg[7][6]};
          d_out[47:40] <= {col_code_reg[0][5], col_code_reg[1][5], col_code_reg[2][5], col_code_reg[3][5], col_code_reg[4][5], col_code_reg[5][5], col_code_reg[6][5], col_code_reg[7][5]};
          d_out[39:32] <= {col_code_reg[0][4], col_code_reg[1][4], col_code_reg[2][4], col_code_reg[3][4], col_code_reg[4][4], col_code_reg[5][4], col_code_reg[6][4], col_code_reg[7][4]};
          d_out[31:24] <= {col_code_reg[0][3], col_code_reg[1][3], col_code_reg[2][3], col_code_reg[3][3], col_code_reg[4][3], col_code_reg[5][3], col_code_reg[6][3], col_code_reg[7][3]};
          d_out[23:16] <= {col_code_reg[0][2], col_code_reg[1][2], col_code_reg[2][2], col_code_reg[3][2], col_code_reg[4][2], col_code_reg[5][2], col_code_reg[6][2], col_code_reg[7][2]};
          d_out[15:8]  <= {col_code_reg[0][1], col_code_reg[1][1], col_code_reg[2][1], col_code_reg[3][1], col_code_reg[4][1], col_code_reg[5][1], col_code_reg[6][1], col_code_reg[7][1]};
          d_out[7:0]   <= {col_code_reg[0][0], col_code_reg[1][0], col_code_reg[2][0], col_code_reg[3][0], col_code_reg[4][0], col_code_reg[5][0], col_code_reg[6][0], col_code_reg[7][0]};
          done <= 1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule