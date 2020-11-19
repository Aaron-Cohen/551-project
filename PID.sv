// Aaron Cohen - 11/13/2020
module PID(clk, rst_n, go, err_vld, line_present, error, lft_spd, right_spd);

input clk, rst_n;			// clock and asynch reset
input go;					// start signal
input err_vld;				// true when error is meaningful and not bogus
input line_present;			// mazerunner on line or not
input  [15:0] error;		// error reading from IR sensors
output [11:0] lft_spd;		// speed for left side
output [11:0] right_spd;	// speed for right side

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
logic moving;						// Indicates whether mazerunner should move
logic ov;							// Indicates whether overflow has occured
logic [9:0] I_term;					// I term calculated value
logic [15:0] adder_result;			// Full adder sum
logic [15:0] valid_sum;				// Sum post validation (retains value if invalid sum)
logic [15:0] err_sat_extended;		// Sign extended err_sat value
logic [15:0] accum_val;				// Accumulated value so far
logic line_rise, line_status;		// Status of mazerunner on line

// Flopping line_present into sychronous line_status will indicate whether or not there was a line present previously
always_ff @(posedge clk)
	line_status <= line_present;

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
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		accum_val <= 16'h0000;
	else if (!go || !moving || line_rise) // Any of these signals act as sync resets
		accum_val <= 16'h0000;
	else
		accum_val <= valid_sum;

// Overflow occurs when the accumulator and the saturated error have the same sign AND their sum has the opposing sign
assign ov = ((accum_val[15] == err_sat_extended[15]) && (accum_val[15] != adder_result[15]));

 // Grab upper bits for I term of PID
assign I_term = accum_val[15:6];

////////////////////////////////////////////////
//  Signals, calculations, flops for D_term  //
//////////////////////////////////////////////

localparam signed [6:0] D_COEFF = 7'h38;
logic signed [10:0] err_sat_1x_old, err_sat_2x_old, D_diff;
logic signed [7:0] D_diff_sat;
logic [14:0] D_term;

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

//////////////////////////////////////////////////
//  Circuitry to put P, I and D terms together //
////////////////////////////////////////////////
parameter FAST_SIM = 0;

logic [14:0] I_term_extended;
assign I_term_extended = {{6{I_term[9]}}, I_term[8:0]};

logic [15:0] PID, PID_reading;
assign PID = P_term + I_term + D_term;

// Mux after sigma in diagram
assign PID_reading = go ? PID : 15'h0000;

// Mux on bottom left (not actually synthesized - generated at runtime)
logic [5:0] increment;
generate
	if(FAST_SIM == 1)
		assign increment = 6'h20;
	else 
		assign increment = 6'h04;
endgenerate

// FRWRD register
logic [10:0] FRWRD;
always_ff@(posedge clk, negedge rst_n)
	if (!rst_n) // async reset
		FRWRD <= 0;
	else if (!go) // sync reset
		FRWRD <= 0;
	else if (~&FRWRD[9:8] && err_vld) // enable
		FRWRD <= FRWRD + increment;

// Only move if FRWRD above threshold		
assign moving = FRWRD > 11'h080;

// Speed is function of PID_reading and FRWRD value
logic [11:0] left_adder, right_adder, FRWRD_padded;
assign FRWRD_padded = {1'b0, FRWRD};
assign left_adder   = PID_reading[14:3] + FRWRD_padded;
assign right_adder  = FRWRD_padded - PID_reading[14:3];

// Muxes for speed outputs based on moving signal
assign lft_spd   = moving ? left_adder  : FRWRD_padded;
assign right_spd = moving ? right_adder : FRWRD_padded;

endmodule