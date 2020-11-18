module I_term(clk, rst_n, err_sat, err_vld, go, moving, line_present, I_term);

input clk, rst_n; 		// clock and reset
input line_present;		// Integrator is cleared on rise of line_present
input [10:0] err_sat;	// saturated value of error (signed)

output err_vld;			// high when err_sat is valid
output go, moving;		// Integrator is cleared if either is not true
output [10:0] I_term;	// I term for PID

logic ov;							// high if there is overflow, low if not
logic [15:0] mux1;					// output from first multiplexer
// logic [15:0] full_I_term;			// 16 bits of I term
logic [15:0] extended_sat;			// sign extended err_sat value
logic [15:0] accum_val = 16'h0000;	// accumulated value so far

	
// sign extend saturated error to 16 bits
assign extended_sat = {{15{err_sat[10]}}, err_sat[9:0]};

// accumulate and determine if there's overflow
assign ov = (accum_val[15] && extended_sat[15]) ? 1 : 0; // check if overflow occurred
assign accum_val = accum_val + extended_sat;

assign mux1 = (err_vld && !ov) ? accum_val : ??;

// register for storing accumulated result
always_ff @(posedge clk, posedge line_present, negedge rst_n) begin

	if (!rst_n)
		I_term <= 16'h0000;
	else if (line_present || !moving || !go)
		I_term <= 16'h0000;
	else
		I_term <= mux1[15:6];
end

// always (@posedge line_present) begin

	// assign I_term = (!moving || !go || line_present) ? 16'h0000 : 
	
	
// end

endmodule