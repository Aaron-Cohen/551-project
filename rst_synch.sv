module rst_synch(clk, RST_n, rst_n);
	input clk;		// Clock 
	input RST_n;	// Active low raw input from push button
	output reg rst_n;	// Synchronized output that is deasserted on negative edge of clk (Active Low)
	
	reg RST_n_ff1;	// Flopped version of raw RST_n signal
	
	// Flop the raw RST_n into RST_n_ff1
	always_ff @(negedge clk, negedge RST_n)
		if(!RST_n)
			RST_n_ff1 <= 1'b0;
		else
			RST_n_ff1 <= 1'b1; // Tied off to 1
	
	// Use flopped RST_n_ff1 to produce global rst_n that falls on negative edge
	always_ff @(negedge clk, negedge RST_n)
		if(!RST_n)
			rst_n <= 1'b0;
		else
			rst_n <= RST_n_ff1; // Use flopped signal for metastability
		
endmodule