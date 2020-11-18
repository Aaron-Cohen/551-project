module I_term(clk, rst_n, err_sat, err_vld, go, moving, line_present, I_term);

input clk, rst_n; 			// clock and reset
input line_present;			// Integrator is cleared on rise of line_present
input signed [10:0] err_sat;		// saturated value of error (signed)

input err_vld;				// high when err_sat is valid
input go, moving;			// Integrator is cleared if either is not true
output signed [9:0] I_term;		// I term for PID

logic ov;					// high if there is overflow, low if not
logic signed [15:0] mux1, sum;		// output from first multiplexer, adder
logic signed [15:0] extended_sat;	// sign extended err_sat value
logic signed [15:0] accum_val;		// accumulated value so far

	
// sign extend saturated error to 16 bits
assign extended_sat = {{15{err_sat[10]}}, err_sat[9:0]};

// accumulate and determine if there's overflow
always_comb begin
	ov = 0; // Overflow can only occur if same signs on addition operands
	if (accum_val[15] == extended_sat[15]) begin
		if(accum_val[15] != sum[15])
			ov = 1;
	end
end

// adder block
assign sum = accum_val + extended_sat;

assign mux1 = (err_vld && !ov) ? sum : I_term;

logic line_reaquired;
always @(posedge clk, posedge line_present) begin
	if(!clk) // async detector for rising edge of line_present
		line_reaquired <= 1;
	else // Reset line_reaquired if clock cycle not aligned with rising edge of line_present
		line_reaquired <= 0;
end

// register for storing accumulated result
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		accum_val <= 16'h0000;
	else if (line_reaquired || !moving || !go)
		accum_val <= 16'h0000;
	else
		accum_val <= mux1;
end
assign I_term = accum_val[15:6];

// always (@posedge line_present) begin

	// assign I_term = (!moving || !go || line_present) ? 16'h0000 : 
	
	
// end

endmodule