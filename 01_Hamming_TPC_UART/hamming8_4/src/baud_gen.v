
module baud_rate_gen(input wire clk,
		     output reg rxclk_en,
		     output reg txclk_en);

parameter BAUDRATE = 115200;
parameter RX_MAX_TICK = 27000000 / (BAUDRATE * 16);
parameter TX_MAX_TICK= 27000000 / BAUDRATE;
reg [31:0] rx_acc = 0;
reg [31:0] tx_acc = 0;

always @(posedge clk) begin
    rxclk_en <= 1'b0;
	if (rx_acc >= RX_MAX_TICK) begin
		rx_acc <= 0;
        rxclk_en <= 1'b1;
    end
	else
		rx_acc <= rx_acc + 1;
end

always @(posedge clk) begin
    txclk_en <= 1'b0;
	if (tx_acc >= TX_MAX_TICK) begin
		tx_acc <= 0;
        txclk_en <= 1'b1;
    end
	else
		tx_acc <= tx_acc + 1;
end

endmodule
