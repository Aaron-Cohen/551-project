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
	
	integer passes, fails, retry, i;
	parameter FAST_SIM = 1;
	reg signed [12:0] theta_robot;
	wire signed [11:0] lft_spd,rght_spd;
	reg mtr_rght_pwm;
	reg mtr_lft_pwm;
	
	typedef enum logic [2:0] {IDLE, MOVE, TURN_90, TURN_270, VEER, COLLISION, AWAIT_LINE, COLLISION_DEBOUNCE} states;
	states state;
	assign state = states'(iDUT.cmd_proc.state);
	
	//get theta_robot from MazePhysics
	assign theta_robot = iPHYS.theta_robot;
	assign mtr_rght_pwm = iPHYS.iMTRR.PWM_sig;
	assign mtr_lft_pwm = iPHYS.iMTRL.PWM_sig;
	assign lft_spd = iDUT.lft_spd;
	assign rght_spd = iDUT.rght_spd;
	
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
		

	/**
		Task to wait a certain amount of clock cycles.
	*/
	task automatic wait_clks;
		input int clk_cycl;	// Amount of clock cycles to wait
		repeat (clk_cycl) @(negedge clk);	
	endtask

	/** 
		Task that removes the line for a given amount of clk cycles
	*/
	task automatic remove_line;
		input int cycl_gone;
		line_present = 0;
		wait_clks(cycl_gone);
		line_present = 1;
	endtask
	
	/**
		Task to set the command of MazeRunner
	*/
	task automatic set_cmd;
		input [15:0] arg; // 16 bit hex command vector
		cmd = arg;
		wait_clks(2);
		send_cmd = 1;
		wait_clks(2);
		send_cmd = 0;
		
		// Ramp MazeRunner up to speed b/c this command is used right after setup.
		wait_clks(750000);
	endtask
	
	/**
		Task to change line_theta "smoothly"
	*/
	task automatic modify_theta;
		input int theta;

		// Slowly ramp up line_theta to theta
		while( theta != line_theta ) begin
			// Case: Positive change in theta
			if(theta > line_theta) begin
				// Subcase: large change (greater than 25 degrees)
				if( theta - line_theta > 250) begin
					line_theta = line_theta + 250;
					wait_clks(500000);
				end
				// Subcase: small change (less than 25 degrees)
				else
					line_theta = theta;
			end
			
			// Case: Negative change in theta
			else begin
				// Subcase: large change (greater than 25 degrees)
				if( line_theta - theta > 250) begin
					line_theta = line_theta - 250;
					wait_clks(500000);
				end
				// Subcase: small change (less than 25 degrees)
				else 
					line_theta = theta;
			end
			wait_clks(1500000);
		end
	endtask
	
	/**
		Task to check if theta_robot is similar to line_theta
		If close but not similar enough, task will allot more
		time and check again recursively.
	*/
	task automatic validate_theta;
		integer difference = line_theta - theta_robot;
		if(difference < 0)
			difference = difference * (-1);
		
		if(difference > 10) begin
				// Two possible scenarios if the first validation check fails: the theta was completely off, or perhaps
				// the theta was just outside the barrier and needs more time to get within the acceptable range. For
				// the latter, we give it more time to fall in the acceptable 1 degree range, and then recursively
				// validate it again.
				// 
				// If the test is completely off, we just want to fail, but integral windup in the PID could be responsible
				// if the term is just outside of the acceptable range so we will take that into account.
				if (difference < 20 && retry < 2) begin
					retry = retry + 1;
					wait_clks(3500000);
					validate_theta;
				end
				else begin
					$display("ERROR: theta_robot expected to be near %d, but was %d", line_theta, theta_robot);
					fails = fails + 1;
				end
		end
		else
				passes = passes + 1;
	endtask
	
	/**
		Task to validate theta after a turn with wider bounds than the validate_theta task
	*/
	task automatic validate_turn_theta;
		integer difference = line_theta - theta_robot;
		if(difference < 0)
			difference = difference * (-1);
		
		// Takes two long for turn to get within 1 degree due to PID overshoot, but fortunately
		// it gets within 2 degrees relatively quickly.
		if(difference > 20) begin
				$display("ERROR: theta_robot expected to be near %d, but was %d", line_theta, theta_robot);
				fails = fails + 1;
		end
		else
				passes = passes + 1;
	endtask
	
	/**
		Task to modify and validate theta in one easy step.
	*/
	task automatic modify_and_validate_theta;
		input int theta;
		modify_theta(theta);
		validate_theta;
	endtask
	
	/**
		Task to set up each test fresh. Run before each test task.
	*/
	task automatic test_setup;
		// Initial conditions
		clk = 0;
		RST_n = 0;
		send_cmd = 0;
		line_theta = 0; 
		line_present = 1;
		BMPL_n = 1;
		BMPR_n = 1;
		retry  = 0;
		passes = 0;
		i = 0;
		fails = 0;
		
		// Reset everything
		wait_clks(5);
		RST_n = 1;
		wait_clks(1);
	endtask
	
	/**
		Task to print out a summary of passed in test number, and amount of succcesfull subtests.
	*/
	task automatic test_results_summary;
		input int test_number;
		if(fails == 0 && passes > 0)
			$display("Good: All %d tests passed for Test: %d", passes, test_number);
		else
			$display("ERROR: %d tests passed and %d tests failed for Test: %d", passes, fails, test_number);
	endtask
	
	/**
		Task to induce a 180 degree turn, takes in input of what theta should be after turn
		(most likely line_theta +/- 1800). Note that sign is very important.
	*/
	task automatic test_roundabout;
		input int new_theta;
		// Attempts to remove line and continue if the cmd_proc changes state, or it will time out.
		fork : remove_line_interval
			// Remove line present
			begin
				line_theta 	 = new_theta; // Same angle, opposite direction.
				line_present = 0;
			end
			
			//	Timeout if cmd_roc state not responsive within 1mil clock cycles
			begin
				wait_clks(500000);
				fails = fails + 1;
				disable remove_line_interval;
			end
			
			// Monitor cmd_proc state and continue if it changes from MOVE when line removed
			begin
				while(state == MOVE) begin
					wait_clks(1000);
				end
				passes = passes + 1;
				disable remove_line_interval;
			end
		join : remove_line_interval
		
		fork : spin
			// Timeout
			begin
				wait_clks(50000000);
				fails = fails + 1;
				$display("timeout");
				disable spin;
			end
			
			// Above, line theta was changed to -1800 (same angle, opposite direction). Now, we will be raising line_present
			// to the robot when it reaches theta = -1800 and observing its behavior after that. Do not disable fork/join
			// We are basically restoring the line present after the unit has turned 180 degrees to see how it behaves.
			begin
				wait_clks(10000);
				while(!line_present) begin
					integer difference = line_theta - theta_robot;
					if(difference < 0)
						difference = (-1)*difference;
						
					line_present = (-50 < difference && difference < 50);
					wait_clks(100); // Need a debounce, even if small, or else ModelSim will freeze up
				end
				passes = passes + 1;
				disable spin;
			end
		join : spin
		
		wait_clks(1500000); 
		if(state == MOVE)
			passes = passes + 1;
		validate_turn_theta;
		wait_clks(1000000); // For easy debugging, lengthens waveform.
	endtask
	
	/**
		Task to test basic line following capabilities on a curvy track.
	*/
	task automatic test_one;
	
		$display("Test 1: MazeRunner orientation in response to sequence of changes to line_theta");
		test_setup; // Do this before each test to reset to start conditions
		set_cmd(16'h0000); // Unused, but there must be a 00 command, otherwise MazeRunner remains in IDLE state.
		
		modify_and_validate_theta(150);
		modify_and_validate_theta(250);
		remove_line(250000); // Quick pause to remove integral windup
		set_cmd(16'h0000);
		modify_and_validate_theta(600);
		modify_and_validate_theta(200);
		remove_line(250000); // Quick pause to remove integral windup
		set_cmd(16'h0000);
		modify_and_validate_theta(-260);
		modify_and_validate_theta(0);
		modify_and_validate_theta(-150);
		modify_and_validate_theta(0);
		
		test_results_summary(1); // Do this after each test to get summary.
	endtask
	
	/**
		Task to test turn around functionality at first gap of line
	*/
	task automatic test_two; // TODO: line_theta value not right, still working on it, though!
		
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
	
	/*
		Task to test basic veer left functionality.
	*/
	task automatic test_three;
	
		$display("Test 3: Testing veer left command when line is lost, with a change in line_theta");
		test_setup;
		set_cmd(16'h002);
		
		modify_and_validate_theta(-150);
		
		// Remove line
		$display("Removing line for %d clk cycles. Induce VEER", 300000);
		remove_line(300000);		
		$display("Restore line post VEER.");
		
		modify_and_validate_theta(-500);
		
		test_results_summary(3);
	 endtask 
	 
    /**
		Task to test basic veer right functionality.
	*/
	task automatic test_four;
	
		$display("Test 4: Testing veer right command when line is lost, with a change in line_theta");
		test_setup;
		set_cmd(16'h001);
		
		modify_and_validate_theta(150);
		
		// Remove line
		$display("Removing line for %d clk cycles. Induce VEER", 300000);
		remove_line(300000);		
		$display("Restore line post VEER.");
		
		modify_and_validate_theta(500);
		
		test_results_summary(4);
	endtask 
	
	/**
		 Task to test basic stop functionality
	*/
	task automatic test_five;
		$display("Testing stop command when line is lost");
		test_setup;
		set_cmd(16'h0000);

		modify_and_validate_theta(150);
	  
		// Remove line
		$display("Removing line. Induce STOP");
		line_present = 0;
	  
		// Wait to finish manuever
		$display("Waiting to check that robot stopped.");
		wait_clks(300000);
	  
		// Verify manuever was done correctly - motors will be stopped
		if(mtr_lft_pwm !== 0 || mtr_rght_pwm !== 0) begin
			$display("ERR: For TEST %d manuever not completed correctly. Robot not stopped. " , 4);
		end 
		$display("GOOD: Robot stopped");
		test_results_summary(5);
	endtask
	
	/**
		Rigourous test of turning around functionality.
	*/
	task automatic test_six;
		$display("Test 6: MazeRunner orientation in response to sequence of changes to line_theta");
		test_setup; // Do this before each test to reset to start condition
		
		///////////////////////////////////////////////////////////////////////////
		// Test 6: 																//
		// Sequence of events goes:											   //
		// turn around (last veer defaults to left), veer right,			  //
		// turn around (last veer = right), turn around (last veer = right), //
		// veer left, turn around (last veer = left)						//
		/////////////////////////////////////////////////////////////////////
		
		
		// Order of commands: 11, 01, 11, 11, 10, 11 === 111011110111 = EF7
		
		
		set_cmd(16'h0EF7);
		
		////////////////////////////////////////////////
		// Test 6 Part 1							 //
		// Turning when last_veer_rght is 0 		//
		/////////////////////////////////////////////
		
		test_roundabout(-1800); // Angle is of same magnitude, but opposite direction
		
		///////////////////////////////////////////////////////////////////
		// Test 6 Part 2											    //
		// Veer right to force next turnaround with left 90, right 270 //
		// back the other way										  //
		///////////////////////////////////////////////////////////////
		
		if(iDUT.cmd_proc.last_veer_rght == 0)
			passes = passes + 1;
		else
			fails = fails + 1;
		
		line_present = 0;
		wait_clks(500000); // Be careful not to veer too far otherwise MazePhysics theta_robot can overflow
		if(state != VEER)
			fails = fails + 1;
		else
			passes = passes + 1;
			
		line_present = 1;
		wait_clks(1000000);
		if(iDUT.cmd_proc.last_veer_rght == 1)
			passes = passes + 1;
		else
			fails = fails + 1;
								
								
		////////////////////////////////////////////////
		// Test 6 Part 3							 //
		// Turning when last_veer_rght is 1			//
		/////////////////////////////////////////////

		test_roundabout(0);
		
		/////////////////////////////////////////////////////
		// Test 6 Part 4							      //
		// Turning again, should go same direction		 //
		// without a VEER in between turns 				//
		/////////////////////////////////////////////////

		test_roundabout(1800);
		
		///////////////////////////////////////////////////////////////////
		// Test 6 Part 5											    //
		// Veer left to force next turnaround to go other direction    //
		////////////////////////////////////////////////////////////////
		
		if(iDUT.cmd_proc.last_veer_rght == 1)
			passes = passes + 1;
		else
			fails = fails + 1;
		
		line_present = 0;
		wait_clks(500000); // Be careful not to veer too far otherwise MazePhysics theta_robot can overflow
		if(state != VEER)
			fails = fails + 1;
		else
			passes = passes + 1;
		
		line_present = 1;
		wait_clks(1000000);
		if(iDUT.cmd_proc.last_veer_rght == 0)
			passes = passes + 1;
		else
			fails = fails + 1;
		
		/////////////////////////////////////////////////
		// Test 6 Part 3							  //
		// Turning when last_veer_rght set back to 0 //
		//////////////////////////////////////////////
		
		test_roundabout(0);
		
		test_results_summary(6); 
		
	endtask
	
	/////////////////////////////////////////////////////////////
	// Task to test basic obstruction on right functionality. //
	// Move, hit obstruction, continue to veer right 		 //
	// after obstruction is moved. 						    //
	/////////////////////////////////////////////////////////
	task automatic test_seven;
		$display("Testing response to obstruction in path");
		test_setup;
		set_cmd(16'h0001);

		modify_and_validate_theta(150);
		
		//obstruction in path
		BMPR_n = 0;
		
		// Syncs up with buzzer, counts how long many clks it is positive
		@(posedge buzz);
		while(buzz) begin
			@(posedge clk); // This behavior ensures we only incremenet when buzz is 1. Otherwise we are off-by-one
			i = i + buzz;   // on the final edge. If statement order swapped, would be off by one from first edge. 			  
		end
		
		// Verify buzzer was up for a total of 2^15 clks (15'h4000 = 2^15)
		if(i == 15'h4000)
			passes = passes + 1;
		else
			fails = fails + 1;
			
		//wait for obstruction to be cleared
		BMPR_n = 1;
		wait_clks(300000);
		
		//check if robot stopped
		if(lft_spd > 10 || rght_spd > 10)
			fails = fails + 1;
		else 
			passes = passes + 1;
		
		//obstruction in path
		BMPL_n = 0;
		
		//wait for obstruction to be cleared
		wait_clks(300000);
		
		//check if robot stopped
		if(lft_spd > 10 || rght_spd > 10)
			fails = fails + 1;
		else 
			passes = passes + 1;
			
		
		
		//check if buzzer sounds
		if(buzz !== 1)
			fails = fails + 1;
		else 
			passes = passes + 1;
		/*
		//clear obstruction 
		BMPR_n = 1;
		
		//wait to move after obstruction cleared
		wait_clks(25);
		
		//check if buzzer turns off after obstruction
		if(buzz == 1) begin
			$display("ERR: buzzer sounds when obstruction is cleared");
			fails = fails + 1;
		end
		else 
			$display("GOOD: buzzer doesn't sound after obstruction is cleared.");
			passes = passes + 1;
	  
		// Remove line
		$display("Removing line for %d clk cycles. Induce VEER", 300000);
		remove_line(300000);		
		$display("Restore line post VEER.");
	  modify_and_validate_theta(500);
		*/
		
		test_results_summary(7);
	endtask
	
	/////////////////////////////////////////////////////////////
	// Task to test basic obstruction on left functionality.  //
	// Move, hit obstruction, continue to veer left 		 //
	// after obstruction is moved. 						    //
	/////////////////////////////////////////////////////////
	task automatic test_eight;
		$display("Testing response to obstruction in path");
		test_setup;
		set_cmd(16'h0002);

		modify_and_validate_theta(-150);
		
		//obstruction in path
		BMPL_n = 0;
		
		//wait for obstruction to be cleared
		wait_clks(300000);
		$display("Waiting for obstruction to be cleared.");
		
		//check if robot stopped
		if(mtr_lft_pwm !== 0 || mtr_rght_pwm !== 0) begin
			$display("ERR: For TEST %d manuever not completed correctly. Robot not stopped. " , 4);
			fails = fails + 1;
		end
		else 
			$display("GOOD: robot stopped at obstruction.");
			passes = passes + 1;
		
		//check if buzzer sounds
		if(buzz !== 1) begin
			$display("ERR: buzzer did not sound when obstruction was hit");
			fails = fails + 1;
		end
		else 
			$display("GOOD: buzzer sounds at obstruction.");
			passes = passes + 1;
		
		//clear obstruction 
		BMPL_n = 1;
		
		//wait to move after obstruction cleared
		wait_clks(25);
		
		//check if buzzer turns off after obstruction
		if(buzz == 1) begin
			$display("ERR: buzzer sounds when obstruction is cleared");
			fails = fails + 1;
		end
		else 
			$display("GOOD: buzzer doesn't sound after obstruction is cleared.");
			passes = passes + 1;
	  
		// Remove line
		$display("Removing line for %d clk cycles. Induce VEER", 300000);
		remove_line(300000);		
		$display("Restore line post VEER.");
	  
		
		modify_and_validate_theta(-500);
		
		test_results_summary(8);
	endtask
	

	initial begin
		// Set up initial conditions
		
		//test_one;
		//test_two;
		//test_three;
		//test_four;
		//test_five;
		test_six;
		// test_seven;
		//test_eight;
		$stop();
	  end
	
	always
	  #5 clk = ~clk;
				  
endmodule
	
