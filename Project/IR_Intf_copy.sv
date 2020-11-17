module IR_Intf (clk, rst_n, MISO, MOSI, SCLK, SS_n, IR_en, IR_vld, line_present, IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3);

input clk, rst_n, MISO;
output IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3;
output SS_n, SCLK, MOSI, IR_en, IR_vld, line_present;

reg [18:0] tmr;


parameter FAST_SIM = 0;



generate
	if(FAST_SIM == 1) begin
		localparam nxt_round = 14'h3fff;
		localparam settled = 11'h7ff;
	end
	else begin
		localparam nxt_round = 18'h3ffff;
		localparam settled = 12'hfff;
	end
endgenerate





endmodule