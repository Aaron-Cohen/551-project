// Mya Schmitz, Aaron Cohen - 11/18/2020
module I_term(clk, rst_n, err_sat, err_vld, go, moving, line_present, I_term);

input logic clk, rst_n; 			// clock and reset
input logic line_present;			// Integrator is cleared on rise of line_present
input logic [10:0] err_sat;			// saturated value of error (signed)
input logic err_vld;				// high when err_sat is valid
input logic go, moving;				// Integrator is cleared if either is not true
output logic [9:0] I_term;			// I term for PID

logic ov;							// Indicates whether overflow has occured
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

endmodule