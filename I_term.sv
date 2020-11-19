module I_term(clk, rst_n, err_sat, err_vld, go, moving, line_present, I_term);

input logic clk, rst_n; 				// clock and reset
input logic line_present;				// Integrator is cleared on rise of line_present
input logic [10:0] err_sat;			// saturated value of error (signed)
input logic err_vld;					// high when err_sat is valid
input logic go, moving;				// Integrator is cleared if either is not true

output logic [9:0] I_term;			// I term for PID

logic ov;							// high if there is overflow, low if not
logic [15:0] add_vals, full_sum;	// contains value to add?
logic [15:0] mux1, sum, checkSum;	// output from first multiplexer and adder
logic [15:0] extended_sat;			// sign extended err_sat value
logic [15:0] accum_val;				// accumulated value so far
logic line_reacquired, line_rise, cleared;

// always_ff @(posedge clk, posedge line_present) begin
	// if (line_present) // async detector for rising edge of line_present
		// line_reacquired <= 1;
	// else // Reset line_reacquired if clock cycle not aligned with rising edge of line_present
		// line_reacquired <= 0;
// end

always_ff @(posedge clk) begin
	if (line_rise || line_present) // async detector for rising edge of line_present
		cleared <= 1;
	else // Reset line_reacquired if clock cycle not aligned with rising edge of line_present
		cleared <= 0;
end

assign line_rise = cleared ? 0 : line_present;
	
// sign extend saturated error to 16 bits
assign extended_sat = {{5{err_sat[10]}}, err_sat};

// adder block logic
assign full_sum = accum_val + extended_sat;
assign sum = (!ov && err_vld) ? full_sum : accum_val;
assign add_vals = (!go || !moving || line_rise) ? 16'h0000 : sum;

// always_ff @(posedge clk, posedge line_present) begin
	// if (!clk) // async detector for rising edge of line_present
		// line_reacquired <= 1;
	// else // Reset line_reacquired if clock cycle not aligned with rising edge of line_present
		// line_reacquired <= 0;
// end


// register for storing accumulated result
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		accum_val <= 16'h0000;
	else
		accum_val <= add_vals;
end

// determine if there is overflow
assign ov = ((accum_val[15] == extended_sat[15]) && (accum_val[15] != full_sum[15]));

assign I_term = accum_val[15:6]; // get I term for PID

endmodule