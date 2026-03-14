module receiver(
	input wire rx,
	input wire rdy_clr,
	input wire clk,
	input wire clken,
	output reg rdy,
	output reg [7:0] data
);


parameter RX_STATE_START	= 2'b00;
parameter RX_STATE_DATA		= 2'b01;
parameter RX_STATE_STOP		= 2'b10;

reg [1:0] state = RX_STATE_START;
reg [3:0] s_tick = 0;
reg [3:0] bitpos = 0;
reg [7:0] scratch = 8'b0;

always @(posedge clk) begin
	if (rdy_clr)
		rdy <= 0;

	if (clken) begin
		case (state)
		RX_STATE_START: begin

			if (!rx || s_tick != 0)
				s_tick <= s_tick + 4'b1;

			if (s_tick == 15) begin
				state <= RX_STATE_DATA;
				bitpos <= 0;
				s_tick <= 0;
				scratch <= 0;
			end
		end
		RX_STATE_DATA: begin
			s_tick <= s_tick + 4'b1;
			if (s_tick == 4'h8) begin //save data in center
				scratch[bitpos[2:0]] <= rx;
				bitpos <= bitpos + 4'b1;
			end
			if (bitpos == 8 && s_tick == 15)
				state <= RX_STATE_STOP;
		end
		RX_STATE_STOP: begin
			/*
			 * Our baud clock may not be running at exactly the
			 * same rate as the transmitter.  If we thing that
			 * we're at least half way into the stop bit, allow
			 * transition into handling the next start bit.
			 */
			if (s_tick == 15 || (s_tick >= 8 && !rx)) begin
				state <= RX_STATE_START;
				data <= scratch;
				rdy <= 1'b1;
				s_tick <= 0;
			end else begin
				s_tick <= s_tick + 4'b1;
			end
		end
		default: begin
			state <= RX_STATE_START;
		end
		endcase
	end
end

endmodule
