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
	
	//0 error test
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h300 | right_spd!=12'h300) begin  //check values after settling down
		$display("There was a calculation error in 1.1");
		$stop();
	end
	
	
	//10 hex error test
	error = 15'h010;
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h343 | right_spd!=12'h2bd) begin	//check values after settling down
		$display("There was a calculation error in 1.2");
		$stop();
	end
	$display("test 1 passed");
	
	//reset
	go = 0;	
	rst_n = 0;	//stop
	error = 15'h000;	//change to 0 error
	repeat(5)@(negedge clk);
	rst_n = 1;
	go = 1;				//go
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h300 | right_spd!=12'h300) begin	//check values after settling down 
		$display("There was a calculation error in 2.1");
		$stop();
	end
	
	//~10 hex error test
	error = ~15'h010 + 1;
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h2bc | right_spd!=12'h344) begin	//check values after settling down should be similar to 10 hex error but switch the left and right
		$display("There was a calculation error in 2.2");
		$stop();
	end
	$display("test 2 passed");
	
	
	//reset
	go = 0;	
	rst_n = 0;	//stop
	error = 15'h000;	//change to 0 error
	repeat(5)@(negedge clk);
	rst_n = 1;
	go = 1;				//go
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h300 | right_spd!=12'h300) begin	//check values after settling down 
		$display("There was a calculation error in 3.1");
		$stop();
	end
	
	//20 hex error test
	error = 15'h020;
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h347 | right_spd!=12'h2b9) begin	//check values after settling down, left should be more than 10 hex error and right should be less
		$display("There was a calculation error in 3.2");
		$stop();
	end
	$display("test 3 passed");
	
	
	//reset
	go = 0;	
	rst_n = 0;	//stop
	error = 15'h000;	//change to 0 error
	repeat(5)@(negedge clk);
	rst_n = 1;
	go = 1;				//go
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h300 | right_spd!=12'h300) begin	//check values after settling down 
		$display("There was a calculation error in 4.1");
		$stop();
	end
	
	//300 hex error test
	error = 15'h300;
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h3ff | right_spd!=12'h201) begin	//check values after settling down, left should be much more than 20 hex error and right should be much less
		$display("There was a calculation error in 4.2");
		$stop();
	end
	
	//reset
	go = 0;	
	rst_n = 0;	//stop
	error = 15'h000;	//change to 0 error
	repeat(5)@(negedge clk);
	rst_n = 1;
	go = 1;				//go
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h300 | right_spd!=12'h300) begin	//check values after settling down 
		$display("There was a calculation error in 5.1");
		$stop();
	end
	
	//A hex error test
	error = 15'h00A;
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h342 | right_spd!=12'h2be) begin	//check values after settling down
		$display("There was a calculation error in 5.2");
		$stop();
	end
	
	//-A hex error test after A 
	error = ~15'h00A + 1;
	repeat (4096) @(posedge clk);
	if(lft_spd != 12'h2ed | right_spd!=12'h313) begin	//check values after settling down, left should be much more than 20 hex error and right should be much less
		$display("There was a calculation error in 5.3");
		$stop();
	end
	
	
	$display("test 4 passed");
	$display("All tests passed");
	
	
	
	$stop();
	
  end
  
  always
    #5 clk = ~clk;
	
endmodule