module err_compute(clk, rst_n, IR_vld, IR_R0,IR_R1,IR_R2,IR_R3,
						IR_L0,IR_L1,IR_L2,IR_L3, error, err_vld);
						
						
	input clk, rst_n, IR_vld;
	output reg err_vld;
	output reg [15:0] error;

	input [11:0] IR_R0,IR_R1,IR_R2,IR_R3; // Right IR readings from inside out
	input [11:0] IR_L0,IR_L1,IR_L2,IR_L3; // Left IR reading from inside out

	reg [2:0] sel;
	reg en_accum, clr_acum;
	reg err_vld_old;
	reg [15:0] error_old;

	err_compute_SM SM(.clk(clk), .rst_n(rst_n), .IR_vld(IR_vld), .sel(sel), //Connect up the State machine
		.clr_accum(clr_accum), .en_accum(en_accum), .err_vld(err_vld_old));
		
	err_compute_DP DP(.clk(clk), .en_accum(en_accum), .clr_accum(clr_accum), //Connect up the Data Path
		.sub(sel[0]), .sel(sel), .IR_R0(IR_R0), .IR_R1(IR_R1), .IR_R2(IR_R2), 
		.IR_R3(IR_R3), .IR_L0(IR_L0), .IR_L1(IR_L1), .IR_L2(IR_L2), .IR_L3(IR_L3),
		.error(error_old));
	
	//error block
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n)
			error <= 1'b0;
		else if(err_vld_old)
			error <= error_old;

	//err_vld block - note that err_vld should only be up for 1 cycle, otherwise PID accumulator will get maxed out
	always @(posedge clk)
		 if (err_vld_old) // Preset
			err_vld <= 1'b1;
		else			  // Does not require async reset because value always 0, unless preset.
			err_vld <= 1'b0;


endmodule