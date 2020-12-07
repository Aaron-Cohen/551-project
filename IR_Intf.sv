module IR_intf (clk, rst_n, MISO, MOSI, SCLK, SS_n, IR_en, IR_vld, line_present, IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3);

parameter FAST_SIM = 1;


input clk, rst_n, MISO;
output reg [11:0] IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3;
output reg SS_n, SCLK, MOSI, IR_en, IR_vld, line_present;

reg [17:0] tmr;


reg IR_R0_en, IR_R1_en, IR_R2_en, IR_R3_en, IR_L0_en, IR_L1_en, IR_L2_en, IR_L3_en;

reg strt_cnv, cnv_cmplt;
reg set_IR_vld, clr_IR_vld;
reg set_IR_en, clr_IR_en;

reg [2:0] chnnl;
reg chnnl_inc, chnnl_clr;
	
reg [11:0] res, high_val;

reg nxt_round, settled;

typedef enum reg [1:0] {IDLE, SETTLE, TRANS} state_t;
state_t state, nextState;  //create states

localparam LINE_THRES = 12'h040; //full synth
// localparam LINE_THRES = 12'h540; //test




//choose normal or fast
generate
	if(FAST_SIM == 1) begin
		assign nxt_round = (tmr & 14'h3fff);
		assign settled = (tmr & 11'h7ff);
	end
	else begin
		assign nxt_round = (tmr & 18'h3ffff);
		assign settled = (tmr &	12'hfff);
	end
endgenerate




//A2D_intf
A2D_intf a2d(.clk(clk), .rst_n(rst_n), .strt_cnv(strt_cnv), .cnv_cmplt(cnv_cmplt), .chnnl(chnnl), .res(res), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));


//timer
always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		tmr <= 0;					//go to 0 on low rst_n
	else 
		tmr <= tmr + 1;				//increment on clock


end


//IR_R0
always@(posedge clk) begin			//for each of the IR registers only get res when their respective enable is one
	if(IR_R0_en)
		IR_R0 <= res;

end

//IR_R1
always@(posedge clk) begin
	if(IR_R1_en)
		IR_R1 <= res;

end

//IR_R2
always@(posedge clk) begin
	if(IR_R2_en)
		IR_R2 <= res;

end

//IR_R3
always@(posedge clk) begin
	if(IR_R3_en)
		IR_R3 <= res;

end

//IR_L0
always@(posedge clk) begin
	if(IR_L0_en)
		IR_L0 <= res;

end

//IR_L1
always@(posedge clk) begin
	if(IR_L1_en)
		IR_L1 <= res;

end

//IR_L2
always@(posedge clk) begin
	if(IR_L2_en)
		IR_L2 <= res;

end

//IR_L3
always@(posedge clk) begin
	if(IR_L3_en)
		IR_L3 <= res;

end



//get highest val
always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		high_val <= 0;		//asynch reset
	else if(IR_vld)
		high_val <= 0;		//when IR_vld, high_val goes to 0
	else if(cnv_cmplt)
		high_val <= (res > high_val)? res: high_val;	//else when cnv_cmplt we only put res into 
														//high_val if its larger than the current high_val

end

//line_present
always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		line_present <= 0;		//asynch reset
	else if(IR_vld)
		line_present <= high_val>LINE_THRES;
end

//IR_vld
always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		IR_vld <=0;		//asynch reset
	else if(set_IR_vld)
		IR_vld <= 1;		//when set_IR_vld, IR_vld goes to 1
	else if(clr_IR_vld)
		IR_vld <=0;			//when clr_IR_vld, IR_vld goes to 0
end

//IR_en
always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		IR_en <=0;		//asynch reset
	else if(set_IR_en)
		IR_en <= 1;		//when set_IR_en, IR_en goes to 1
	else if(clr_IR_en)
		IR_en <=0;		//when clr_IR_en, IR_en goes to 0
end


//chnnl inc
always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		chnnl <=0;		//asynch reset
	else if(chnnl_inc)		
		chnnl <= chnnl + 1;		//when chnnl_inc, chnnl goes up by one
	else if(chnnl_clr)
		chnnl <= 0;			//when chnnl_clr, chnnl goes to 0
end

//state flops
always @(posedge clk or negedge rst_n)
	if (!rst_n)
		state <= IDLE;		//asynch reset to IDLE state
	else
		state <= nextState; //otherwise get nextState



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
	
	set_IR_vld = 0;
	clr_IR_vld = 0;
	
	set_IR_en = 0;
	clr_IR_en = 0;
	
	chnnl_inc = 0;
	chnnl_clr = 0;
	strt_cnv = 0;
	
	nextState = state; //initialize nextState to state
	
	case (state)
	
	IDLE : begin					
		clr_IR_vld = 1;	//clear IR_vld and IR_en
		clr_IR_en = 1;
		if(nxt_round)begin		//on next round go to SETTLE
			nextState = SETTLE;	//set IR_en to 1
			set_IR_en = 1;
		end
		end
	
	
	SETTLE : if(settled) begin	//when settled go to TRANS and enable start conversion
		nextState = TRANS;
		strt_cnv = 1;
		end
		
	default : if(cnv_cmplt && (chnnl ==0)) begin //enable the IR reciever for the correct channel, increment the channel and go back to IDLE
		IR_R0_en = 1;
		chnnl_inc = 1;
		nextState = IDLE;
		end
		else if(cnv_cmplt && (chnnl ==1)) begin
		IR_R1_en = 1;
		chnnl_inc = 1;
		nextState = IDLE;
		end
		else if(cnv_cmplt && (chnnl ==2)) begin
		IR_R2_en = 1;
		chnnl_inc = 1;
		nextState = IDLE;
		end
		else if(cnv_cmplt && (chnnl ==3)) begin
		IR_R3_en = 1;
		chnnl_inc = 1;
		nextState = IDLE;
		end
		else if(cnv_cmplt && (chnnl ==4)) begin
		IR_L0_en = 1;
		chnnl_inc = 1;
		nextState = IDLE;
		end
		else if(cnv_cmplt && (chnnl ==5)) begin
		IR_L1_en = 1;
		chnnl_inc = 1;
		nextState = IDLE;
		end
		else if(cnv_cmplt && (chnnl ==6)) begin
		IR_L2_en = 1;
		chnnl_inc = 1;
		nextState = IDLE;
		end
		else if(cnv_cmplt && (chnnl ==7)) begin
		IR_L3_en = 1;
		chnnl_clr = 1;
		set_IR_vld = 1;
		nextState = IDLE; 
		end
		
		
		
		
	endcase
	
end
		
	
	
	




endmodule

