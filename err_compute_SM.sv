module err_compute_SM(clk, rst_n, IR_vld, sel, clr_accum, en_accum, err_vld);

	input clk, rst_n, IR_vld;
	output reg [2:0] sel;
	output reg clr_accum, en_accum, err_vld;


	reg [3:0] cnt;
	reg accum;

	typedef enum reg {IDLE, ACCUM} state_t;  //states IDL and ACCUM
	state_t state, nxt_state;

	always_comb begin
	state = nxt_state;  //give state nxt_state
	sel = cnt[2:0];     //sel is lower 3 bits of cnt
	end

	//state machine
	always_ff@(posedge clk, negedge rst_n) begin
	  clr_accum = 0;		//initialize to 0 and IDLE default state
	  en_accum = 0;
	  err_vld  = 0;
	  accum = 0;
	  nxt_state = IDLE;
	  case(state)
		
		ACCUM : if(cnt == 8) begin	//when cnt is 8 all accumulating is done
				  err_vld = 1;		//set err_vld to 1 and IDLE next state
				  nxt_state = IDLE;
				end else begin		//otherwise stay in ACCUM state and accum
				  accum = 1;
				  en_accum = 1;
				  nxt_state = ACCUM;
				end
				
		
		default : if(IR_vld) begin 		//IDLE default state 
				nxt_state = ACCUM;  	//when IR_vld nxt_state is ACCUM and clr_accum
				clr_accum = 1;
				end
	  endcase
	end

	//counter
	always@(posedge clk, negedge rst_n) begin
	  if(!rst_n)  //clear cnt on rst_n - asynch
	  cnt<=0;
	  if(IR_vld)  //clear cnt on IR_vld - synch
	  cnt<=0;
	  else if(accum)	//on accum we count up
	  cnt <= cnt +1;
	end
endmodule