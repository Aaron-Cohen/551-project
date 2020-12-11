`timescale 1ns/10ps
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
	
	integer passes, fails, total_passes, total_fails; // Test status integers
	integer retry, i;	// Integers used in testing for retry logic, and misc number holders
	parameter FAST_SIM = 1;
	reg signed [12:0] theta_robot;
	wire [10:0] mtr_rght_spd, mtr_lft_spd;
	wire signed [12:0] alpha_lft,alpha_rght;			// angular acceleration of wheels
	wire signed [15:0] omega_lft,omega_rght;			// angular velocities of wheels
	
	// Get internal signals from MazePhysics and iDUT
	assign theta_robot = iPHYS.theta_robot;
	assign mtr_rght_spd = iPHYS.mtrMagR;
	assign mtr_lft_spd = iPHYS.mtrMagL;
	assign omega_lft = iPHYS.omega_lft;
	assign omega_rght = iPHYS.omega_rght;
	assign alpha_lft = iPHYS.alpha_lft;
	assign alpha_rght = iPHYS.omega_rght;
	
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
	
	
	
	/////////////////////////////////////////
	// Section: Validation tasks to check //
	// common conditions in testbench 	 //
	//////////////////////////////////////
	
	/**
		Task to validate right veer
	*/
	task automatic validate_veer_right;
		// When veering right, left wheel spinning much faster than right wheel
		if (omega_lft - omega_rght > 100)
			passes = passes + 1;
		else
			fails = fails + 1;
	endtask
	
	
	/**
		Task to validate left veer
	*/
	task automatic validate_veer_left;
		// When veering left, left wheel spinning much slower than right wheel
		if (omega_rght - omega_lft > 100)
			passes = passes + 1;
		else
			fails = fails + 1;
	endtask

	/**
		Task to verify 100ms debounce does not react to bumper status changes
	*/
	task automatic validate_debounce;
		logic left_orig  = BMPL_n;
		logic right_orig = BMPR_n;
		
		wait_clks(30000); // Motor drive needs time to get memo to stop
		validate_robot_is_stopped;
		
		// Deassert bump signal for 75000 clk cycles (still shorter than debounce timer)
		// to bait it into restarting if it is not in the debounce wait period
		BMPL_n = 1;
		BMPR_n = 1;
		wait_clks(30000);
		
		// See if robot took the bait after motor has sufficient time to get going.
		validate_robot_is_stopped;
		
		// Set bumpers back to whatever their original values were
		BMPL_n = left_orig;
		BMPR_n = right_orig;		
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
					retry = 0;
				end
		end
		else begin
				passes = passes + 1;
				retry = 0;
		end
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
		if(difference > 25) begin
				$display("ERROR: theta_robot expected to be near %d, but was %d", line_theta, theta_robot);
				fails = fails + 1;
		end
		else
				passes = passes + 1;
	endtask

	/**
		Task to examin robot's angular velocities of each wheel to 
	*/
	task automatic validate_robot_is_stopped;
		if( mtr_lft_spd > 1 || mtr_rght_spd > 1)
			fails = fails + 1;
		else
			passes = passes + 1;
	endtask

	/**
		Task to examine if robot is in MOVE  steady state
	*/
	task automatic valiate_move_state;
		fork : loop
			// When robot is in move state, sum of mtr drives are 1538 in steady state
			begin
				while(mtr_lft_spd + mtr_rght_spd != 1538) begin
					wait_clks(500);
				end
				passes = passes + 1;
				disable loop;
			end
		
			// Timeout loop
			begin 
				wait_clks(2500000);
				fails = fails + 1;
				disable loop;
			end
		join: loop
	endtask
	
	///////////////////////////////////////////////////
	// Section: Helper tasks for commonly occuring	//
	// operations.								   //
	////////////////////////////////////////////////

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
			wait_clks(1750000);
		end
	endtask
	
	/**
		Task to modify and validate theta in one easy step.
	*/
	task automatic modify_and_validate_theta;
		input int theta;
		modify_theta(theta);
		wait_clks(150000);
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
		wait_clks(500);
		RST_n = 1;
		
		// Wait for maze physics to recalibrate after previous test to about 0 before beginning next test
		while(theta_robot < -10 || theta_robot > 10)
			wait_clks(5000);
	endtask
	
	/**
		Task to print out a summary of passed in test number, and amount of succcesfull subtests.
	*/
	task automatic test_results_summary;
		input int test_number;
		
		if(fails == 0 && passes > 0) begin
			$display("GOOD: All %d tests passed for Test: %d\n", passes, test_number);
			total_passes = total_passes + 1;
		end
		else begin
			$display("ERROR: %d tests passed and %d tests failed for Test: %d\n", passes, fails, test_number);
			total_fails = total_fails + 1;
		end
	endtask
	
	/**
		Task to induce a 180 degree turn, takes in input of what theta should be after turn
		(most likely line_theta +/- 1800). Note that sign is very important.
	*/
	task automatic test_roundabout;
		input int new_theta;
		
		line_present = 0;
		line_theta 	 = new_theta; // Should be same angle, opposite direction.
		
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
		valiate_move_state;
		validate_turn_theta;
		wait_clks(1000000); // For easy debugging, lengthens waveform.
	endtask

	///////////////////////////////////////////////////
	// Section: The actual unit tests themselves to	//
	// execute within the initial block			   //
	////////////////////////////////////////////////
	
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
		Task to test basic veer left functionality.
	*/
	task automatic test_two;
	
		$display("Test 2: Testing veer left command when line is lost, with a change in line_theta");
		test_setup;
		set_cmd(16'h0002); // cmd: 10 to veer left when line is removed
		
		modify_theta(-150);
		
		// Remove line to go to veer state
		line_present = 0;
		wait_clks(100000);
		
		// Check that robot is veering
		validate_veer_left;

		wait_clks(100000);
		
		// Restore line, wait, and see if theta is correct after a while
		line_present = 1;
		wait_clks(1500000);
		validate_theta;
		
		test_results_summary(2);
	 endtask 
	 
    /**
		Task to test basic veer right functionality.
	*/
	task automatic test_three;
	
		$display("Test 3: Testing veer right command when line is lost, with a change in line_theta");
		test_setup;
		set_cmd(16'h0001); // cmd: 01 to veer right when line is removed
		
		modify_theta(-150);
		
		// Remove line to go to veer state
		line_present = 0;
		wait_clks(100000);
		
		// Check that robot is veering
		validate_veer_right;
		
		wait_clks(100000);
		
		// Restore line, wait, and see if theta is correct after a while
		line_present = 1;
		wait_clks(1500000);
		validate_theta;
		
		test_results_summary(3);
	 endtask 
	
	/**
		 Task to test basic stop/start functionality
		 due to cmd stimulus
	*/
	task automatic test_four;
		$display("Test 4: Testing robot idles when line is lost and command is 00");
		test_setup;
		set_cmd(16'hFCFC); // Making sure lower two bits and only lower two bits get read (on both bytes)
	  
		// Remove line
		line_present = 0;
		wait_clks(100000);
		
		// Check if robot stops driving PWM speed. Robot from a physics standpoint still in motion
		// but motor not being driven indicates an eventual stop for testing purposes.
		validate_robot_is_stopped;
		
		// Add line to go again
		line_present = 1;
		set_cmd(16'h0000); // Contents not important, just need cmd_rdy to go true in cmd_proc
		wait_clks(100000);
		
		// Check in motion
		//if(lft_spd == 0 || rght_spd == 0)
		//	fails = fails + 1;
	//	else 
		//	passes = passes + 1;
		
		// Remove line
		line_present = 0;
		wait_clks(100000);
		
		// Check if stops again
		validate_robot_is_stopped;
		
		test_results_summary(4);
	endtask
	
	/**
		Rigourous test of turning around functionality, testing the reverse
		maneuver in succession with different states of its last veer.
	*/
	task automatic test_five;
		$display("Test 5: MazeRunner orientation in response to sequence of changes to line_theta");
		test_setup;
		
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
		
		line_present = 0;
		wait_clks(500000); // Be careful not to veer too far otherwise MazePhysics theta_robot can overflow
		validate_veer_right;
			
		line_present = 1;
		wait_clks(1000000);
									
								
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
		
		line_present = 0;
		wait_clks(500000); // Be careful not to veer too far otherwise MazePhysics theta_robot can overflow
		validate_veer_left;
		
		line_present = 1;
		wait_clks(1000000);
		
		/////////////////////////////////////////////////
		// Test 6 Part 3							  //
		// Turning when last_veer_rght set back to 0 //
		//////////////////////////////////////////////
		
		test_roundabout(0);
		
		test_results_summary(5); 
		
	endtask
	
	/**
		Task to test basic obstruction functionality,
		buzzer, and movement
	*/
	task automatic test_six;
		$display("Test 6: MazeRunner motion and buzzer in response to obstructions in path");
		test_setup;
		set_cmd(16'h0000);
		
		//////////////////////////////////////////////
		// Test 7 Part 1: Right Bumper Obstruction //
		////////////////////////////////////////////
		
		BMPR_n = 0;
		wait_clks(5);
		
		// Check debounce state entrance
		validate_debounce;
		
		// Sync up with buzzer, counts how long many clks it is positive
		@(posedge buzz);
		while(buzz) begin
			@(posedge clk); // i + buzz ensures we only increment when buzz = 1. Otherwise there is an off-by-one
			i = i + buzz;   // on the final edge. If statement order swapped, would be off by one from first edge. 			  
		end
		
		// Verify buzzer was up for a total of 2^15 clks (15'h4000 = 2^15)
		if(i == 15'h4000)
			passes = passes + 1;
		else
			fails = fails + 1;
		
		wait_clks(500000);
		
		// Check if robot stops driving PWM speed. Robot from a physics standpoint still in motion
		// but motor not being driven indicates an eventual stop for testing purposes.
		validate_robot_is_stopped;
		
		wait_clks(100000);
		
		// Clear obstruction
		BMPR_n = 1;
		wait_clks(300000);
		
		// Verify robot is moving after obstruction removed
		valiate_move_state;
			
		//////////////////////////////////////////////
		// Test 7 Part 2: Left Bumper Obstruction  //
		////////////////////////////////////////////
		
		i = 0;
		BMPL_n = 0;
		wait_clks(5);
		
		// Check debounce state entrance
		validate_debounce;
		
		// Sync up with buzzer, counts how long many clks it is positive
		@(posedge buzz);
		while(buzz) begin
			@(posedge clk); // i + buzz ensures we only increment when buzz = 1. Otherwise there is an off-by-one
			i = i + buzz;   // on the final edge. If statement order swapped, would be off by one from first edge. 			  
		end
		
		// Verify buzzer was up for a total of 2^15 clks (15'h4000 = 2^15)
		if(i == 15'h4000)
			passes = passes + 1;
		else
			fails = fails + 1;
		
		wait_clks(500000);
		
		// Check if robot stops driving PWM speed. Robot from a physics standpoint still in motion
		// but motor not being driven indicates an eventual stop for testing purposes.
		validate_robot_is_stopped;
		
		wait_clks(100000);
		
		// Clear obstruction
		BMPL_n = 1;
		wait_clks(300000);
		
		// Verify robot is moving after obstruction removed
		valiate_move_state;
			
		////////////////////////////////////////////////
		// Test 7 Part 3: Boths Bumpers Obstructions //
		//////////////////////////////////////////////
		
		i = 0;
		BMPR_n = 0;
		BMPL_n = 0;
		wait_clks(5);
		
		// Check debounce state entrance
		validate_debounce;
		
		// Sync up with buzzer, counts how long many clks it is positive
		@(posedge buzz);
		while(buzz) begin
			@(posedge clk); // i + buzz ensures we only increment when buzz = 1. Otherwise there is an off-by-one
			i = i + buzz;   // on the final edge. If statement order swapped, would be off by one from first edge. 			  
		end
		
		// Verify buzzer was up for a total of 2^15 clks (15'h4000 = 2^15)
		if(i == 15'h4000)
			passes = passes + 1;
		else
			fails = fails + 1;
		
		wait_clks(500000);
		
		// Check if robot stops driving PWM speed. Robot from a physics standpoint still in motion
		// but motor not being driven indicates an eventual stop for testing purposes.
		validate_robot_is_stopped;
		
		wait_clks(100000);
		
		// Clear obstructions
		BMPR_n = 1;
		BMPL_n = 1;
		wait_clks(300000);
		
		// Verify robot is moving after encountering obstruction removed
		valiate_move_state;
		
		test_results_summary(6);
	endtask
	
	initial begin
		total_passes = 0;
		total_fails  = 0;
		
		test_one;	// Test line following as line_theta changes
		test_two;	// Veer left test
		test_three;	// Veer right test
		test_four;	// Halt test
		test_five;	// Turnaround maneuver test
		test_six;	// Bumper collission and buzzer test
		
		// Looks messy, prints nice.
		$display("\n#################################");
		$display("# Overall test results:  	      #");
		$display("# Tests passed: %d	    #", total_passes);
		$display("# Tests failed: %d	    #", total_fails);
		$display("#################################");
		
		$stop();
	  end
	
	always
	  #5 clk = ~clk;
				  
endmodule
	
