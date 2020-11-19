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

////////////////////////////////////////////
//  Signals and calculations for P_term  //
//////////////////////////////////////////

localparam signed [5:0] P_COEFF = 2; 
logic signed [16:0] err_product;
logic signed [14:0] P_term;

assign err_product = err_sat * P_COEFF;
assign P_term = 
	err_product[16] && ~&err_product[15:14] ? 15'h4000 	: // If negative and there is a 0 in upper bits, saturate to 100...0
	!err_product[16] && |err_product[15:14] ? 15'h3FFF 	: // If positive and there is a 1 in upper bits, saturate to 011...1
			{err_product[16], err_product[13:0]}; // else, do not saturate: tack sign bit to lower 14 bits.	



////////////////////////////////////////////////
//  Signals, calculations, flops for I_term  //
//////////////////////////////////////////////
logic [9:0] I_term
logic ov;							// Indicates whether overflow has occured
logic [15:0] adder_result;			// Full adder sum
logic [15:0] valid_sum;				// Sum post validation (retains value if invalid sum)
logic [15:0] err_sat_extended;		// Sign extended err_sat value
logic [15:0] accum_val;				// Accumulated value so far
logic line_rise, line_status;		// Status of mazerunner on line

// If there is a line present on the syncronous signal, then it has already risen.
// However, if syncronously there is not a line, but we see one asynchronously, this is a rising edge.
assign line_rise = line_status ? 0 : line_present;
	
// Sign extend saturated error to 16 bits
assign err_sat_extended = {{5{err_sat[10]}}, err_sat};

// Full adder
assign adder_result = accum_val + err_sat_extended;

// Mux determining whether full adder has a valid sum based on overflow flag and err_vld to route full adder's result 
assign valid_sum = (!ov && err_vld) ? adder_result : accum_val;

// Register for storing accumulated results
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		accum_val <= 16'h0000;
	else if (!go || !moving || line_rise) // Any of these signals act as sync resets
		accum_val <= 16'h0000;
	else
		accum_val <= valid_sum;
end

// Overflow occurs when the accumulator and the saturated error have the same sign AND their sum has the opposing sign
assign ov = ((accum_val[15] == err_sat_extended[15]) && (accum_val[15] != adder_result[15]));

assign I_term = accum_val[15:6]; // Grab upper bits for I term of PID

////////////////////////////////////////////////
//  Signals, calculations, flops for D_term  //
//////////////////////////////////////////////

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