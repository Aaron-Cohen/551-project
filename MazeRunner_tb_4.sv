module MazeRunner_tb_4();

	reg clk,RST_n;					// Clk and async reset signal
	reg send_cmd;					// assert to send travel plan via CommMaster
	reg [15:0] cmd;					// traval plan command word to maze runner
	reg signed [12:0] line_theta;	// angle of line (starts at zero)
	reg line_present;				// is there a line or a gap?
	reg BMPL_n, BMPR_n;				// bump switch inputs

	///////////////////////////////////////////////////////////////
	// Declare internals sigs between DUT and supporting blocks //
	/////////////////////////////////////////////////////////////
	wire SS_n, MOSI, MISO, SCLK;	// SPI bus to A2D
	wire PWMR, PWML, DIRR, DIRL;	// motor controls
	wire IR_EN;						// IR sensor enable
	wire RX_TX;						// comm line between CommMaster and UART_wrapper
	wire cmd_sent;					// probably don't need this
	wire buzz, buzz_n;				// buzzer and differential hooked to piezo buzzer outputs
	
	///////////////////////////////////////////////////////////////
	// Declare Testing variables							    //
	/////////////////////////////////////////////////////////////
	
	integer i;
	parameter FAST_SIM = 1;
	reg signed [12:0] theta_robot;
	
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
	CommMaster iMST(.clk(clk), .rst_n(RST_n), .TX(RX_TX), .snd_cmd(send_cmd), .cmd(cmd),
                    .cmd_cmplt(cmd_sent));					  
		

	// Task that waits a given amount of clock cycles
	task automatic wait_clks;
		input int clk_cycl;	// Amount of clock cycles to wait
		repeat (clk_cycl) @(negedge clk);	
	endtask

	// Task that removes the line for a given amount of clk cycles
	task automatic remove_line;
		input int cycl_gone;
		
		line_present = 0;
		wait_clks(cycl_gone);
		line_present = 1;
	endtask
	
	task set_cmd;
		input arg; // 16 bit hex command vector
		cmd = arg;
		wait_clks(2);
		send_cmd = 1;
		wait_clks(2);
		send_cmd = 0;
	endtask
	
	//////////////////////////////////////////////////////////
	// Task to test basic veer functionality.				//
	// Note: it is bad to change veer by more than 250 (25  //
	// degrees), perform changes larger than that in steps. //
	//////////////////////////////////////////////////////////
	task test_one;
		$display("Testing veer right command when line is lost, with a change in line_theta");
		
		set_cmd(16'h0001);
		line_theta = 0;
	  
		// Wait to get up to speed
		$display("Ramping up to speed for %d clk cycles...", 1500000);
		wait_clks(1500000);
	  
		// Change line theta
		line_theta = 150;
		$display("Changing line theta to %d", line_theta);
	  
		// React to change in line theta
		$display("Changing motor speeds to adjust to line theta difference");
		wait_clks(3000000);
	  
		// Remove line
		$display("Removing line for %d clk cycles. Induce VEER", 300000);
		remove_line(300000); 
		$display("Restore line post VEER.");
	  
		// Change line theta
		line_theta = 250;
		$display("Changing line theta to %d", line_theta);
	  
		// Wait to finish manuever
		$display("Adjusting to line theta.");
		wait_clks(4250000);
		
		// Change line theta
		line_theta = 500;
		$display("Changing line theta to %d", line_theta);
		
		// React to change in line theta
		$display("Changing motor speeds to adjust to line theta difference");
		wait_clks(3000000);
		
		// Change line theta
		line_theta = 400;
		$display("Changing line theta to %d", line_theta);
		
		// React to change in line theta
		$display("Changing motor speeds to adjust to line theta difference");
		wait_clks(3000000);
	  
		// Verify manuever was done correctly
		if(theta_robot < (line_theta - 10) || theta_robot > (line_theta + 10)) begin
			$display("ERR: For TEST %d manuever not completed correctly. theta_ robot expected to be near %d, but was %d" , 1, line_theta, theta_robot);
		end 
		$stop();
	endtask
	
	/////////////////////////////////////////////////////////////////
	// Task to test turn around functionality at first gap of line //
	/////////////////////////////////////////////////////////////////
	task test_two; // TODO: line_theta value not right, still working on it, though!
		$display("Testing turn around command at first gap in line");
		
		set_cmd(16'h0003);
		line_theta = 0;
	  
		// Wait to get up to speed
		$display("Ramping up to speed for %d clk cycles...", 1500000);
		wait_clks(1500000);
	  
		// Change line theta
		line_theta = 150;
		$display("Changing line theta to %d", line_theta);
	  
		// React to change in line theta
		$display("Changing motor speeds to adjust to line theta difference");
		wait_clks(3000000);
		
		// 2.5mil clocks, first gap is encountered, robot starts turn around maneuver
		$display("Wait 2.5 mil clocks for first gap, robot then starts turn around maneuver");
		wait_clks(2500000);
		line_present = 0;
		
		// Gradually increase line_theta via loop to begin veer to right
		$display("Gradually change line theta to %d", line_theta);
		for (i = 0; i < 1050; i = i + 1) begin
			line_theta = line_theta + 1;
			wait_clks(10);
		end
		
		// Encounters line again at 1.75mil clocks
		wait_clks(1750000);
		line_present = 1;
		
		// Gradually decrease line_theta via loop to finish turn around
		$display("Gradually change line theta to %d", line_theta);
		for (i = 0; i < 2700; i = i + 1) begin
			line_theta = line_theta - 1;
			wait_clks(10);
		end
		
		// End, line is 180 degrees from 15 degree when it started maneuver
		// line_theta = -1650;
		$display("Changing line theta to %d", line_theta);
		
		// React to change in line theta
		$display("Changing motor speeds to adjust to line theta difference");
		wait_clks(3000000);
	  
		// Verify manuever was done correctly
		if(theta_robot < (line_theta - 10) || theta_robot > (line_theta + 10)) begin
			$display("ERR: For TEST %d manuever not completed correctly. theta_ robot expected to be near %d, but was %d" , 2, line_theta, theta_robot);
		end 
		$stop();
	endtask
	
	/////////////////////////////////////////////////
	// Task to test basic veer left functionality. //
	/////////////////////////////////////////////////
	task test_three;
		$display("Testing veer left command when line is lost, with a change in line_theta");
		
		set_cmd(16'h0002);
		line_theta = 0;
	  
		// Wait to get up to speed
		$display("Ramping up to speed for %d clk cycles...", 1500000);
		wait_clks(1500000);
	  
		// Change line theta
		line_theta = -150;
		$display("Changing line theta to %d", line_theta);
	  
		// React to change in line theta
		$display("Changing motor speeds to adjust to line theta difference");
		wait_clks(3000000);
	  
		// Remove line
		$display("Removing line for %d clk cycles. Induce VEER", 300000);
		remove_line(300000); 
		$display("Restore line post VEER.");
	  
		// Change line theta
		line_theta = -250;
		$display("Changing line theta to %d", line_theta);
	  
		// Wait to finish manuever
		$display("Adjusting to line theta.");
		wait_clks(4250000);
		
		// Change line theta
		line_theta = -500;
		$display("Changing line theta to %d", line_theta);
		
		// React to change in line theta
		$display("Changing motor speeds to adjust to line theta difference");
		wait_clks(3000000);
		
		// Change line theta
		line_theta = -400;
		$display("Changing line theta to %d", line_theta);
		
		// React to change in line theta
		$display("Changing motor speeds to adjust to line theta difference");
		wait_clks(3000000);
	  
		// Verify manuever was done correctly
		if(theta_robot < (line_theta - 10) || theta_robot > (line_theta + 10)) begin
			$display("ERR: For TEST %d manuever not completed correctly. theta_ robot expected to be near %d, but was %d" , 3, line_theta, theta_robot);
		end 
		$stop();
	endtask

	initial begin
		// Set up initial conditions
		clk = 0;
		RST_n = 0;
		send_cmd = 0;
		line_theta = 0; 
		line_present = 1;
		BMPL_n = 1;
		BMPR_n = 1;
		wait_clks(5);
		
		RST_n = 1;
		wait_clks(1);
		
		test_one;
		test_two;
		test_three;
	  end
	
	always
	  #5 clk = ~clk;
				  
endmodule
	
