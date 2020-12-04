module MazeRunner_tb();

	reg clk,RST_n;
	reg send_cmd;					// assert to send travel plan via CommMaster
	reg [15:0] cmd;					// traval plan command word to maze runner
	reg signed [12:0] line_theta;	// angle of line (starts at zero)
	reg line_present;				// is there a line or a gap?
	reg BMPL_n, BMPR_n;				// bump switch inputs

	///////////////////////////////////////////////////////////////
	// Declare internals sigs between DUT and supporting blocks //
	/////////////////////////////////////////////////////////////
	wire SS_n,MOSI,MISO,SCLK;		// SPI bus to A2D
	wire PWMR,PWML,DIRR,DIRL;		// motor controls
	wire IR_EN;						// IR sensor enable
	wire RX_TX;						// comm line between CommMaster and UART_wrapper
	wire cmd_sent;					// probably don't need this
	wire buzz,buzz_n;				// hooked to piezo buzzer outputs
	
	///////////////////////////////////////////////////////////////
	// Declare Testing variables							    //
	/////////////////////////////////////////////////////////////
	//parameter TEST = 1;
	logic TEST;
	reg signed [12:0] theta1, theta2, theta3, theta4, theta5;
	int line_gone_clks, line_gone_clks2, line_gone_clks3, line_gone_clks4;
	
	//get theta_robot from MazePhysics
	assign theta_robot = iPHYS.theta_robot;
	
    //////////////////////
	// Instantiate DUT //
	////////////////////
	MazeRunner iDUT(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.MOSI(MOSI),.MISO(MISO),.SCLK(SCLK),
					.PWMR(PWMR),.PWML(PWML),.DIRR(DIRR),.DIRL(DIRL),.IR_EN(IR_EN),
					.BMPL_n(BMPL_n),.BMPR_n(BMPR_n),.buzz(buzz),.buzz_n(buzz_n),.RX(RX_TX),
					.LED());
					
	////////////////////////////////////////////////
	// Instantiate Physical Model of Maze Runner //
	//////////////////////////////////////////////
	MazePhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.MOSI(MOSI),.MISO(MISO),.SCLK(SCLK),
	                  .PWMR(PWMR),.PWML(PWML),.DIRR(DIRR),.DIRL(DIRL),.IR_EN(IR_EN),
					  .line_theta(line_theta),.line_present(line_present));
					  
	/////////////////////////////
	// Instantiate CommMaster //
	///////////////////////////
	CommMaster iMST(.clk(clk), .rst_n(RST_n), .TX(RX_TX), .send_cmd(send_cmd), .cmd(cmd),
                    .cmd_sent(cmd_sent));					  
		

	initial begin
      clk = 0;
	  RST_n = 0;
	  send_cmd = 0;
	  line_theta = 0; 
	  line_present = 1;
	  BMPL_n = 1;
	  BMPR_n = 1;
	  
	  wait_clk_cycl(5, clk);
	  
	  send_cmd = 1;
	  RST_n = 1;
	  TEST = 1;
	  
	  if(TEST == 1) begin
		
		/**
		*  TEST 1 command is veer right
		*
		*/
		assign cmd = 16'h5555;
		assign theta1 = 150;
		assign theta2 = 500;
		
		assign line_gone_clks = 300000;
		
		
	  
	  end else if(TEST == 2) begin
	    
		/**
		*  TEST 2 command is turn around
		*
		*/
		assign cmd = 16'hFFFF;
		assign theta1 = 150;
		assign theta2 = -1650;
		
		assign line_gone_clks = 1750000;
	  
	  
	  
	  end else if(TEST == 3) begin
	  
		/**
		*  TEST 3 command is veer left
		*
		*/
		assign cmd = 16'hAAAA;
		assign theta1 = -150;
		assign theta2 = -500;
		
		assign line_gone_clks = 300000;
		
	  end else if(TEST == 4) begin
		/**
		*  TEST 4 command is stop
		*
		*/
		assign cmd = 16'h0000;
		assign theta1 = 150;
		assign theta2 = 150;
		
		assign line_gone_clks = 300000;
		
	  end else if(TEST == 5 || TEST == 7) begin
		/**
		*  TEST 5 command is right, turn around, left, stop
		*
		*/
		assign cmd = 16'h002D;
		assign theta1 = 150;
		assign theta2 = 500;	//veer right
		assign theta3 = 2300;	//turn around
		assign theta4 = 1950;	//veer left
		assign theta5 = 1950;	//stop
		
		assign line_gone_clks = 300000;
		assign line_gone_clks2 = 1750000;
		assign line_gone_clks3 = 300000;
		assign line_gone_clks4 = 100000;
		
	  end else if(TEST == 6 || TEST == 8) begin
		/**
		*  TEST 6 command is left, turn around, right, stop
		*
		*/
		assign cmd = 16'h001E;
		assign theta1 = -150;
		assign theta2 = -500;	//veer right
		assign theta3 = -2300;	//turn around
		assign theta4 = -1950;	//veer left
		assign theta5 = -1950;	//stop
		
		assign line_gone_clks = 300000;
		assign line_gone_clks2 = 1750000;
		assign line_gone_clks3 = 300000;
		assign line_gone_clks4 = 100000;
	  end
	  
	  //single command testing
	  for (TEST = 1; TEST < 5; TEST++) begin
	  //wait to get up to speed
	  wait_clk_cycl(1500000, clk);
	  
	  //change line theta
	  line_theta = theta1;
	  
	  //wait for the manuver 
	  wait_clk_cycl(1000000, clk);
	  
	  //line gone
	  remove_line(line_gone_clks, clk, line_present);
	  
	  //new theta
	  line_theta = theta2;
	  
	  //wait to finish manuever
	  wait_clk_cycl(1000000,clk);
	  
	  //verify manuever was done correctly
		if(theta_robot !== line_theta) begin
			$display("ERR: For TEST %d manuever not completed correctly. theta_ robot expected to be 500,
						but was %d" ,TEST, theta_robot);
			$stop();
		end
	  end 
	
	  //multiple commands testing
	  for (TEST = 5; TEST < 7; TEST++) begin
	    //wait to get up to speed
	    wait_clk_cycl(1500000, clk);
	  
	    //change line theta
	    line_theta = theta1;
	  
	    //wait for the manuver 
	    wait_clk_cycl(1000000, clk);
	  
	    //line gone
	    remove_line(line_gone_clks, clk, line_present);
	  
	    //new theta
	    line_theta = theta2;
	  
	    //wait to first finish manuever
	    wait_clk_cycl(1000000,clk);
	  
	    //start second command
	    //wait to get to gap
	    wait_clk_cycl(1000000, clk);
		
	    //line gone
	    remove_line(line_gone_clks2, clk, line_present);
		
	    //new theta
	    line_theta = theta3;
	
	    //start third command
	    //wait to get to gap
	    wait_clk_cycl(1000000, clk);
		
	    //line gone
	    remove_line(line_gone_clks3, clk, line_present);
		
	    //new theta
	    line_theta = theta4;
	  
	    //start fourth command
	    //wait for the maneuver
	    wait_clk_cycl(1000000, clk);
		
	    //line gone
	    remove_line(line_gone_clks4, clk, line_present);
		
	    //new theta
	    line_theta = theta5;
	  
	    //wait to finish last manuever
	    wait_clk_cycl(1000000,clk);
	  
	    //verify manuever was done correctly
		  if(theta_robot !== line_theta) begin
		    $display("ERR: For TEST %d manuever not completed correctly. theta_ robot expected to be 500,
						but was %d" ,TEST, theta_robot);
			$stop();
		end
	  end
	  
	  //obstruction testing
	  for (TEST = 7; TEST < 9; TEST++) begin
	    //wait to get up to speed
	    wait_clk_cycl(1500000, clk);
	  
	    //change line theta
	    line_theta = theta1;
	  
	    //wait for the manuver 
	    wait_clk_cycl(1000000, clk);
	  
	    //line gone
	    remove_line(line_gone_clks, clk, line_present);
	  
	    //new theta
	    line_theta = theta2;
	  
	    //wait to first finish manuever
	    wait_clk_cycl(1000000,clk);
		
	    //start second command
	    //wait to get to gap
	    wait_clk_cycl(1000000, clk);
		
		//obstruction before second maneuver starts
		if(TEST == 7) begin
		  BMPR_n = 0;
		  
		  if(buzz !== 1) begin
			$display("ERR: buzzer did not sound when obstruction was hit");
			$stop();
		  end
		
		  //wait for obstruction to clear and bumper to be pushed
		  BMPR_n = 1;
		end

		if(TEST == 8) begin
		  BMPL_n = 0;
		  
		  if(buzz !== 1) begin
			$display("ERR: buzzer did not sound when obstruction was hit");
			$stop();
		  end
		
		  //wait for obstruction to clear and bumper to be pushed
		  BMPL_n = 1;
		end 
		
	    //line gone
	    remove_line(line_gone_clks2, clk, line_present);
		
	    //new theta
	    line_theta = theta3;
	
	    //start third command
	    //wait to get to gap
	    wait_clk_cycl(1000000, clk);
		
	    //line gone
	    remove_line(line_gone_clks3, clk, line_present);
		
	    //new theta
	    line_theta = theta4;
	  
	    //start fourth command
	    //wait for the maneuver
	    wait_clk_cycl(1000000, clk);
		
	    //line gone
	    remove_line(line_gone_clks4, clk, line_present);
		
	    //new theta
	    line_theta = theta5;
	  
	    //wait to finish last manuever
	    wait_clk_cycl(1000000,clk);
	  
	    //verify manuever was done correctly
		  if(theta_robot !== line_theta) begin
		    $display("ERR: For TEST %d manuever not completed correctly. theta_ robot expected to be 500,
						but was %d" ,TEST, theta_robot);
			$stop();
		end
	  end
	end
	
	always
	  #5 clk = ~clk;
				  
endmodule


//task that waits a given amount of clock cycles
task wait_clk_cycl;
  input int clk_cycl;
  input clk;
  
  repeat(clk_cycl)@(negedge clk);
  
endtask

//task that removes the line for a given amount of clk cycles
task remove_line;
  input int cycl_gone;
  input clk;
  input line_present;
  
  line_present = 0;
  
  wait_clk_cycl(cycl_gone, clk);
  
  line_present = 1;
  
endtask
	