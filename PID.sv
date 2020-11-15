// Aaron Cohen - 11/13/2020
module PID(clk, rst_n, go, err_vld, error, lft_spd, right_spd);

input clk, rst_n;		// clock and asynch reset
input go;				// start signal
input err_vld;			// true when error is meaningful and not bogus
input [15:0] error;		// error reading from IR sensors
output lft_spd;			// speed for left side
output right_spd;		// speed for right side

// 11 bit sautrated error reading - used in all three PID calculations
logic signed [10:0] err_sat;
assign err_sat = 
	error[15]  && ~&error[14:10] ? 11'h400 : // If negative and there is a 0 in upper bits, saturate to 100...0
	!error[15] && |error[14:10]  ? 11'h3FF : // If positive and there is a 1 in upper bits, saturate to 011...1
					{error[15], error[9:0]}; // else, do not saturate: tack sign bit to lower 10 bits.		


// Signals and calculations for P_term
localparam signed [5:0] P_COEFF = 2; 
logic signed [16:0] err_product;
logic signed [14:0] P_term;

assign err_product = err_sat * P_COEFF;
assign P_term = 
	err_product[16] && ~&err_product[15:14] ? 15'h4000 	: // If negative and there is a 0 in upper bits, saturate to 100...0
	!err_product[16] && |err_product[15:14] ? 15'h3FFF 	: // If positive and there is a 1 in upper bits, saturate to 011...1
					{err_product[16], err_product[13:0]}; // else, do not saturate: tack sign bit to lower 14 bits.	

endmodule