module IR_intf (clk, rst_n, MISO, MOSI, SCLK, SS_n, IR_en, IR_vld, line_present, IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3);



input clk, rst_n, MISO;
output reg [11:0] IR_R0, IR_R1, IR_R2, IR_R3,	// IR sensor values
				  IR_L0, IR_L1, IR_L2, IR_L3;
output reg SS_n, SCLK, MOSI,					// SPI protocol signals
	IR_en, IR_vld, line_present; 				// IR signals




reg IR_R0_en, IR_R1_en, IR_R2_en, IR_R3_en,	// Enables for IR registers
	IR_L0_en, IR_L1_en, IR_L2_en, IR_L3_en;
reg strt_cnv, cnv_cmplt; 					// State machine commands
reg set_IR_en, clr_IR_en;
reg [2:0] chnnl;							// Channel controls
reg chnnl_inc, chnnl_clr;
reg [11:0] res, high_val;					// Comparators
reg [17:0] tmr;								// Timer

reg nxt_round, settled;

typedef enum reg [1:0] {IDLE, SETTLE, TRANS, CHECK_DONE} state_t;
state_t state, nextState;  //create states

parameter FAST_SIM = 1;
localparam LINE_THRES = 12'h040; //full synth
// localparam LINE_THRES = 12'h540; //test

//choose normal or fast
generate
	if(FAST_SIM == 1) begin
		assign nxt_round = &tmr[13:0];
		assign settled = &tmr[10:0];
	end
	else begin
		assign nxt_round = &tmr[17:0];
		assign settled = &tmr[11:0];
	end
endgenerate

// A2D_intf
A2D_intf a2d(.clk(clk), .rst_n(rst_n), .strt_cnv(strt_cnv), .cnv_cmplt(cnv_cmplt), .chnnl(chnnl), .res(res), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));


// Timer flop
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		tmr <= 0;		// Async Reset
	else 
		tmr <= tmr + 1;	// Counter


// Each of the following always blocks is to only load an output when that sensor is being scanned

//IR_R0
always @(posedge clk) 
	if(IR_R0_en)
		IR_R0 <= res;
// IR_R1
always @(posedge clk)
	if(IR_R1_en)
		IR_R1 <= res;

// IR_R2
always @(posedge clk)
	if(IR_R2_en)
		IR_R2 <= res;

// IR_R3
always @(posedge clk)
	if(IR_R3_en)
		IR_R3 <= res;

// IR_L0
always @(posedge clk)
	if(IR_L0_en)
		IR_L0 <= res;
		
// IR_L1
always @(posedge clk)
	if(IR_L1_en)
		IR_L1 <= res;

// IR_L2
always @(posedge clk)
	if(IR_L2_en)
		IR_L2 <= res;

// IR_L3
always @(posedge clk)
	if(IR_L3_en)
		IR_L3 <= res;

// Get max IR reading
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		high_val <= 0;		// Asynch reset
	else if(IR_vld)
		high_val <= 0;		// Clear high_value after each round of conversions
	else if(cnv_cmplt)
		high_val <= (res > high_val) ? res : high_val;	// Cnv_cmplt indicates the A2D's res value is "valid". Check this against the max.


// Line_present flop
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		line_present <= 0;		// Asynch reset
	else if(IR_vld)
		line_present <= (high_val > LINE_THRES);

// IR_en
always@(posedge clk, negedge rst_n)
	if(!rst_n)
		IR_en <= 0;		// Asynch reset
	else if(set_IR_en)
		IR_en <= 1;		// When set_IR_en, IR_en goes to 1
	else if(clr_IR_en)
		IR_en <= 0;		// When clr_IR_en, IR_en goes to 0


// Channel flop and counter
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		chnnl <= 0;				// Asynch reset
	else if(chnnl_inc)		
		chnnl <= chnnl + 1;		// Incrementer
	else if(chnnl_clr)
		chnnl <= 0;				// Sync clear


// State flop
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= IDLE;		// Asynch reset to IDLE state
	else
		state <= nextState; // otherwise always assume nextState



//state machine
always_comb begin
	IR_R0_en = 0;	//start everything off to 0
	IR_R1_en = 0;
	IR_R2_en = 0;
	IR_R3_en = 0;
	IR_L0_en = 0;
	IR_L1_en = 0;
	IR_L2_en = 0;
	IR_L3_en = 0;
	
	set_IR_en = 1;
	clr_IR_en = 0;
	
	chnnl_inc = 0;
	chnnl_clr = 0;
	strt_cnv = 0;
	
	nextState = state; //initialize nextState to state
	
	case (state)
	// wait for value to settle due to rc time constant
	SETTLE : begin
		if(settled) begin	//when settled go to TRANS and enable start conversion
			strt_cnv = 1;
			nextState = TRANS;
		end
	end
	CHECK_DONE : begin
		// Wrap around once all IR sensors 0 to 7 have been scanned.
		if(chnnl == 0) begin
			IR_vld = 1;
			nextState = IDLE;
		end
		// Kick off A2D
		else begin
			strt_cnv = 1;
			nextState = TRANS;
		end
	end
	// wait for cnv_cmplt, then inc channel counter, then go to a state where it checks "are we done, has channel counter wrapped down to 0". If wrap, IR_vld = 1
	TRANS : begin
		if(cnv_cmplt) begin
			chnnl_inc = 1;
			nextState = CHECK_DONE;
			if(chnnl ==0) //enable the IR reciever for the correct channel, increment the channel and go back to IDLE
				IR_R0_en = 1;
			else if(chnnl ==1)
				IR_R1_en = 1;
			else if(chnnl ==2)
				IR_R2_en = 1;
			else if(chnnl ==3)
				IR_R3_en = 1;
			else if(chnnl ==4)
				IR_L0_en = 1;
			else if(chnnl ==5)
				IR_L1_en = 1;
			else if(chnnl ==6)
				IR_L2_en = 1;
			else if(chnnl ==7)
				IR_L3_en = 1;
		end
	end
	default : begin	// Default to IDLE
		set_IR_en = 0; // Disable and clear IR enable (it is enabled in every other state)
		clr_IR_en = 1;
		IR_vld = 0;	//clear IR_vld directly from SM
		
		if(nxt_round)begin		//on next round go to SETTLE
			nextState = SETTLE;	
			chnnl_clr = 1;
		end
	end
	
	endcase
	
end

endmodule

