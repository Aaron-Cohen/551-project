module PID_tb();

  reg clk, rst_n;		// define stimulus as type reg
  reg err_vld;			// high when err_sat is valid
  reg go;				// Integrator is cleared if either is not true
  reg line_present;		// Integrator is cleared on rise of line_present
  reg [15:0] error;		// Error value read in
  reg [11:0] lft_spd, right_spd; // Speed outputs expected
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  PID DUT(.clk(clk), .rst_n(rst_n), .go(go), .err_vld(err_vld), .error(error), .line_present(line_present), .lft_spd(lft_spd), .right_spd(right_spd));
		
  initial begin
    clk = 0;
	rst_n = 0;
	go = 1;
	err_vld = 0;
	error = 15'h000;
	line_present = 1; // Tied off as this would be an input to PID from outside the scope of this testbench
	@(posedge clk);
	@(negedge clk);
	rst_n = 1;
	err_vld = 1; 
	
	repeat (1024) @(posedge clk);
	$stop();
	
  end
  
  always
    #5 clk = ~clk;
	
endmodule