module main_top(
    input  wire clk,        
    input  wire sys_rst_n,   
    output wire TX_PIN,      
    input  wire RX_PIN       
);

wire [7:0] rx_data;
reg  [7:0] tx_data;
wire txBusy, rdy, rxclk_en, txclk_en;
reg  writeEN, rdyClr;

baud_rate_gen uart_baud(.clk(clk), .rxclk_en(rxclk_en), .txclk_en(txclk_en));
transmitter   uart_tx(.tx(TX_PIN), .din(tx_data), .clk(clk), .clken(txclk_en), .wr_en(writeEN), .tx_busy(txBusy));
receiver      uart_rx(.rx(RX_PIN), .data(rx_data), .clk(clk), .clken(rxclk_en), .rdy(rdy), .rdy_clr(rdyClr));

//KẾT NỐI TPC 
reg [63:0] main_buffer;
reg enc_start, dec_start;
wire enc_done, dec_done;
wire [63:0] enc_dout;
wire [15:0] dec_dout;

tpc_encoder_s tpc_enc (.clk(clk), .rst_n(1'b1), .d_in(main_buffer[15:0]), .start(enc_start), .d_out(enc_dout), .done(enc_done));
tpc_decoder_hdd tpc_dec (.clk(clk), .rst_n(1'b1), .d_in(main_buffer), .start(dec_start), .data_out(dec_dout), .done(dec_done));

localparam S_IDLE    = 3'd0;
localparam S_GATHER  = 3'd1;
localparam S_PROC    = 3'd2;
localparam S_SEND    = 3'd3;
localparam S_WAIT_TX = 3'd4;

reg [2:0] state = S_IDLE;
reg [3:0] byte_req = 0; // Số byte cần nhận
reg [3:0] byte_cnt = 0; // Số byte đã nhận/đã gửi
reg is_enc = 0;

always @(posedge clk) begin
    // Mặc định tắt các xung kích
    writeEN <= 0; 
    enc_start <= 0;     
    dec_start <= 0;
    
    // Xử lý hạ cờ Clear UART an toàn
    if (rdyClr) rdyClr <= 0;

    case (state)
        S_IDLE: begin
            if (rdy && !rdyClr) begin
                rdyClr <= 1; // Báo đã đọc xong
                if (rx_data == 8'hEE) begin 
                    is_enc <= 1; byte_req <= 2; byte_cnt <= 0; state <= S_GATHER; 
                end else if (rx_data == 8'hDD) begin 
                    is_enc <= 0; byte_req <= 8; byte_cnt <= 0; state <= S_GATHER; 
                end
            end
        end

        S_GATHER: begin
            if (rdy && !rdyClr) begin
                rdyClr <= 1;
                main_buffer <= {main_buffer[55:0], rx_data}; // Dịch trái, nhét byte mới vào
                byte_cnt <= byte_cnt + 1;
                
                // Đã nhận đủ số byte ?
                if (byte_cnt + 1 == byte_req) begin
                    state <= S_PROC;
                end
            end
        end

        S_PROC: begin
            if (is_enc) begin
                enc_start <= 1;
                if (enc_done) begin 
                    main_buffer <= enc_dout; 
                    byte_cnt <= 8; // Báo cần gửi 8 byte
                    state <= S_SEND; 
                end
            end else begin
                dec_start <= 1;
                if (dec_done) begin 
                    main_buffer <= {dec_dout, 48'h00}; 
                    byte_cnt <= 2; // Báo cần gửi 2 byte
                    state <= S_SEND; 
                end
            end
        end

        S_SEND: begin
            if (!txBusy && !writeEN) begin
                tx_data <= main_buffer[63:56]; // Lấy byte cao nhất gửi đi
                main_buffer <= {main_buffer[55:0], 8'h00}; // Dịch dữ liệu
                writeEN <= 1;
                byte_cnt <= byte_cnt - 1;
                state <= S_WAIT_TX;
            end
        end
        S_WAIT_TX: begin
            if (!txBusy && !writeEN) begin
                if (byte_cnt == 0) state <= S_IDLE; // Đã gửi hết
                else state <= S_SEND;               // Quay lại gửi tiếp
            end
        end
    endcase
end
endmodule