// Aaron Cohen - 11/16/2020
module D_term(clk, rst_n, err_sat, err_vld, D_term);

input clk, rst_n;
input [10:0] err_sat;
input err_vld;			// true when error is meaningful and not bogus
output [14:0] D_term;

localparam signed [6:0] D_COEFF = 7'h38;
logic signed [10:0] err_sat_1x_old, err_sat_2x_old, D_diff;
logic signed [7:0] D_diff_sat;

// Flop to store error from 1 cycle ago
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		err_sat_1x_old <= 0;
	else if (err_vld)
		err_sat_1x_old <= err_sat;

// Flop to store error from 2 cycles ago
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		err_sat_2x_old <= 0;
	else if (err_vld)
		err_sat_2x_old <= err_sat_1x_old;

// Current - value from 2 errors ago, saturated to 8 bits
assign D_diff = err_sat - err_sat_2x_old;
assign D_diff_sat = 
	D_diff[10] && ~&D_diff[10:7] ? 8'h80 : // If negative and there is a 0 in upper bits, saturate to 100...0
	!D_diff[10] && |D_diff[10:7] ? 8'h7F : // If positive and there is a 1 in upper bits, saturate to 011...1
			{D_diff[10], D_diff[6:0]}; // else, do not saturate: tack sign bit to lower 7 bits.	

assign D_term = D_COEFF * D_diff_sat;

endmodule