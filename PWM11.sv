// Aaron Cohen - 9/28/2020
module PWM11(
  input clk,
  input rst_n,
  input [10:0] duty,
  output reg PWM_sig
);

reg [10:0] cnt;
logic PWM_pre_flop;

// Flop the output
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		PWM_sig <= 0;
	else
		PWM_sig <= PWM_pre_flop;

// While count is less than or equal to duty, assert it on. While count is greater than that of duty, deassert.
always_comb
	if(cnt <= duty)
		PWM_pre_flop = 1;
	else
		PWM_pre_flop = 0;

// Increment count with rollover
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		cnt <= 10'h000;
	else
		cnt <= cnt + 1;


endmodule
