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
logic signed [10:0] err_unsat;

// Saturate error to 11 bits
//  * Saturate low  when: MSB = 1 (i.e. negative signed) and any of the bits between MSB and bit 11 are 0
//  * Saturate high when: MSB = 0 (i.e. positive signed) and any of the bits between MSB and bit 11 are 1
// 						neg: If any zeroes in higher bits, saturate to 1000...0 |  pos: If any 1's in higher bits, saturate to 0111...1
assign err_unsat = {error[15], error[9:0]}; 
assign err_sat = error[15] ? ( &error[14:10] ? err_unsat : 11'h400 ) : ( |error[14:10] ? 11'h3FF : err_unsat );

// Signals needed to create P_term
localparam signed [5:0] P_COEFF = 2; 
logic signed [16:0] err_product;
logic signed [14:0] P_term_unsat;
logic signed [14:0] P_term;

// P_term specific calculations
assign err_product = err_sat * P_COEFF;
assign P_term_unsat = {err_product[16], err_product[13:0]};
// Same saturation logic as above:		negative saturation	to 1000...0					positive saturation to 0111...1
assign P_term = err_product[16] ? ( &err_product[15:14] ? P_term_unsat : 15'h4000) : ( |err_product[15:14] ? 15'h3FFF : P_term_unsat  );

endmodule