module I_term_tb();

  reg clk, rst_n;		// define stimulus as type reg
  reg [10:0] err_sat;	// saturated value of error (signed)
  reg err_vld;			// high when err_sat is valid
  reg go,moving;		// Integrator is cleared if either is not true
  reg line_present;		// Integrator is cleared on rise of line_present
  
  wire [9:0] I_term;
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  I_term iDUT(.clk(clk), .rst_n(rst_n), .err_sat(err_sat), .err_vld(err_vld),
              .go(go), .moving(moving), .line_present(line_present), .I_term(I_term));
		
  initial begin
    clk = 0;
	rst_n = 0;
	go = 1;
	moving = 1;
	err_vld = 0;
	err_sat = 11'h200;		// 1/2 scale positive
	line_present = 1;
	@(posedge clk);
	@(negedge clk);
	rst_n = 1;				// deassert reset
	
	/// Reset test & ~err_vld test ///
	repeat(2) @(negedge clk);
	if (I_term!==10'h000) begin
	  $display("ERR: I_term should be zero, it was reset and there are no _err_vld yet");
	  $stop();
	end else $display("GOOD: Test1 passed!");

	/// err_vld for a couple of cycles ///	
	err_vld = 1;
	repeat(2) @(negedge clk);
	if (I_term!==10'h010) begin
	  $display("ERR: I_term should 0x10, two integrations of 0x200/0x40");
	  $stop();
	end else $display("GOOD: Test2 passed!");

	/// knock down moving to see if it resets ///	
	moving = 0;
    @(negedge clk);
	if (I_term!==10'h000) begin
	  $display("ERR: I_term should be zero, it moving was brought low");
	  $stop();
	end else $display("GOOD: Test3 passed!");
	
	/// Let it build up again (negative this time) ///	
	err_sat = 11'h600;			// -0x200
	moving = 1;
    repeat(3) @(negedge clk);
	if (I_term!==10'h3E8) begin
	  $display("ERR: I_term should be 0x3E8, 3-integrations of -0x200/0x40");
	  $stop();
	end else $display("GOOD: Test4 passed!");

	/// knock down go to see if it resets ///	
	go = 0;
    @(negedge clk);
	if (I_term!==10'h000) begin
	  $display("ERR: I_term should be zero, it go was brought low");
	  $stop();
	end else $display("GOOD: Test5 passed!");
   
	/// Now let it build way up + to test saturation ///	
	go = 1;
	err_sat = 11'h3FF;
    repeat(31) @(negedge clk);
	if (I_term!==10'h1EF) begin
	  $display("ERR: I_term should be near saturation");
	  $stop();
	end else $display("GOOD: Test6 passed!");  

	/// Now go a few more and it should be saturated positive ///	
    repeat(3) @(negedge clk);
	if (I_term!==10'h1FF) begin
	  $display("ERR: I_term should be saturated to 0x1FF");
	  $stop();
	end else $display("GOOD: Test7 passed!"); 	
	
	/// Now lets test negative saturation ///	
	go = 0;					// clear it first
	@(negedge clk);
	go = 1;
	err_sat = 11'h400;
    repeat(31) @(negedge clk);
	if (I_term!==10'h210) begin
	  $display("ERR: I_term should be near saturation (negative)");
	  $stop();
	end else $display("GOOD: Test8 passed!"); 
	
	/// Now go a few more and it should be saturated negative ///	
    repeat(3) @(negedge clk);
	if (I_term!==10'h200) begin
	  $display("ERR: I_term should be saturated to 0x200");
	  $stop();
	end else $display("GOOD: Test9 passed!");
	
	/// Now check that is clears on rise of line_present ////
	line_present = 0;
	repeat(10) @(negedge clk);
	if (I_term!==10'h200) begin
	  $display("ERR: I_term should still be saturated to 0x200, we reset on RISE of line_present");
	  $stop();
	end else $display("GOOD: Test10 passed!");
	
	line_present = 1;
	@(negedge clk);
	if (I_term!==10'h000) begin
	  $display("ERR: I_term should still be reset due to line_present rise");
	  $stop();
	end else $display("GOOD: Test11 passed!");	
	
	$display("YAHOO!! all tests passed!");
	$stop();
	
  end
  
  always
    #5 clk = ~clk;
	
endmodule