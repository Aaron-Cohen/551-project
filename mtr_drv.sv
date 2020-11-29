module mtr_drv(clk, rst_n, lft_duty, rght_duty, DIRL, DIRR, PWML, PWMR);
	input clk, rst_n;
	input [11:0] lft_duty, rght_duty;
	output DIRL, DIRR;
	output PWML, PWMR;
	logic [10:0] lft_duty_mag, rght_duty_mag;
	
	// Get absolute value before feeding magnitude to PWM
	assign lft_duty_mag  = lft_duty[11]  ? ~lft_duty[10:0]  + 1 : lft_duty[10:0];
	assign rght_duty_mag = rght_duty[11] ? ~rght_duty[10:0] + 1 : rght_duty[10:0];
	
	// Instantiate PWM's with magnitudes determined above
	PWM11 lftPWM( .clk(clk), .rst_n(rst_n), .duty(lft_duty_mag),  .PWM_sig(PWML));
	PWM11 rghtPWM(.clk(clk), .rst_n(rst_n), .duty(rght_duty_mag), .PWM_sig(PWMR));	
	
	//Assign direction output signals
	assign DIRL = lft_duty[11];
	assign DIRR = rght_duty[11];		
	
endmodule
	  
  