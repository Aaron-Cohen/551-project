module D_term_tb();

  reg clk, rst_n;		// define stimulus as type reg
  reg [10:0] err_sat;	// saturated value of error (signed)
  reg err_vld;			// high when err_sat is valid
  
  wire [14:0] D_term;
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  D_term iDUT(.clk(clk), .rst_n(rst_n), .err_sat(err_sat), .err_vld(err_vld),
              .D_term(D_term));
		
  initial begin
    clk = 0;
	rst_n = 0;
	err_vld = 0;
	err_sat = 11'h000;		// zero
	@(posedge clk);
	@(negedge clk);
	rst_n = 1;				// deassert reset
	
	/// Reset test & ~err_vld test ///
	repeat(4) @(negedge clk);
	if (D_term!==15'h0000) begin
	  $display("ERR: D_term should be zero, it was reset and there are no _err_vld yet");
	  $stop();
	end else $display("GOOD: Test1 passed!");

	/// err_vld still low but err_sat non-zero ///
    /// value that will not cause saturation ///
	err_sat = 11'h030;
	repeat(3) @(negedge clk);
	if (D_term!==15'hA80) begin
	  $display("ERR: D_term should 0xA80, mult of 0x30*0x38");
	  $stop();
	end else $display("GOOD: Test2 passed!");

	/// err_vld still low but err_sat non-zero ///
    /// value that will cause + saturation ///
	err_sat = 11'h0A0;
	repeat(3) @(negedge clk);
	if (D_term!==15'h1BC8) begin
	  $display("ERR: D_term should 0x1BC8, positive saturation of 0x7F*0x38");
	  $stop();
	end else $display("GOOD: Test3 passed!");
	
	/// err_vld still low but err_sat non-zero ///
    /// value that will cause - saturation ///
	err_sat = 11'h700;
	repeat(3) @(negedge clk);
	if (D_term!==15'h6400) begin
	  $display("ERR: D_term should 0x6400, negative saturation 0x80*0x38");
	  $stop();
	end else $display("GOOD: Test4 passed!");
	
	/// err_vld becomes high, err_sat = 14'h080 ///
	err_vld = 1;
	err_sat = 11'h080;
	@(negedge clk);
	if (D_term!==15'h1BC8) begin
	  $display("ERR: D_term should 0x1BC8, positive saturation 0x7F*0x38");
	  $stop();
	end else $display("GOOD: Test5.1 passed!");
	@(negedge clk);
	if (D_term!==15'h000) begin
	  $display("ERR: D_term should 0x000, err_sat held constant for 2 clocks");
	  $stop();
	end else $display("GOOD: Test5.2 passed!");	
	
	$display("YAHOO!! all tests passed!");
	$stop();
	
  end
  
  always
    #5 clk = ~clk;
	
endmodule