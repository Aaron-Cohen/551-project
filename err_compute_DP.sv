module err_compute_DP(clk,en_accum,clr_accum,sub,sel,IR_R0,IR_R1,IR_R2,IR_R3,
                    IR_L0,IR_L1,IR_L2,IR_L3,error);
					
  input clk;							// 50MHz clock
  input en_accum,clr_accum;				// accumulator control signals
  input sub;							// If asserted we subtract IR reading
  input [2:0] sel;						// mux select for operand
  input [11:0] IR_R0,IR_R1,IR_R2,IR_R3; // Right IR readings from inside out
  input [11:0] IR_L0,IR_L1,IR_L2,IR_L3; // Left IR reading from inside out
  
  
  output reg signed [15:0] error;	// Error in line following, goes to PID
  
  reg signed [15:0] next_error;
  reg signed [15:0] next_IR;
  reg signed [15:0] intermediate;
  
  assign intermediate = sel[2]? (sel[1]?(sel[0]? {1'b0, IR_L3, 3'h0}:			//111
												{1'b0, IR_R3, 3'h0}):		//110
									(sel[0]? {2'h0, IR_L2, 2'h0}:			//101
												{2'h0, IR_R2, 2'h0})):	//100
							(sel[1]?(sel[0]? {3'h0, IR_L1, 1'b0}:		//011
												{3'h0, IR_R1, 1'b0}):		//010
									(sel[0]? {4'h0, IR_L0}:			//001
												{4'h0, IR_R0}));	//000
	assign next_IR = sub? -intermediate: intermediate;

	assign next_error = $signed(error) + $signed(next_IR);
  
 //<< You implement functionality specified >>
  
  //////////////////////////////////
  // Implement error accumulator //
  ////////////////////////////////
  always_ff @(posedge clk)
    if (clr_accum)
	  error <= 16'h0000;
	else if (en_accum)
	  error <= next_error; 

endmodule