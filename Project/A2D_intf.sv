module A2D_intf(clk, rst_n, strt_cnv, cnv_cmplt, chnnl, res, SS_n, SCLK, MOSI, MISO);

	input clk, rst_n, strt_cnv;
	input [2:0] chnnl;
	input MISO;

	output reg cnv_cmplt, SS_n, SCLK, MOSI;
	output reg [11:0] res;

	reg [15:0] rd_data;
	reg wrt, set_hold, clr_hold, hold, done;
	reg set_cmplt;
	
	typedef enum reg [1:0] {IDLE, TRANS1, TRANS2, HOLD} state_t;
	state_t state, nextState;  //create states


	SPI_mstr16 spi(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .wrt(wrt), .cmd({2'b00,chnnl,11'h000}), .done(done), .rd_data(rd_data));


	assign res = ~rd_data[11:0];

	//assign state
	always@(posedge clk, negedge rst_n) begin
		if(!rst_n)				//on reset we go back to IDLE otherwise go to whatever state is in nextState
			state <= IDLE;
		else
			state <= nextState;
	end
	
	//assign hold latch infered
	always@(posedge clk, negedge rst_n) begin
		if(!rst_n)			//on reset hold goes to 0
			hold <= 0;
		else if(set_hold)	//on set_hold hold goes to 1
			hold <= 1;
		else if(clr_hold)	//on clr_hold hold goes to 0;
			hold <= 0;
	end
	
	//assign complete latch infered 
	always@(posedge clk, negedge rst_n) begin
		if(!rst_n)				//on reset cnv_cmplt goes to 0
			cnv_cmplt <= 0;
		else if(strt_cnv)		//on strt_cnv cnv_cmplt goes to 0
			cnv_cmplt <= 0;
		else if(set_cmplt)		//on set_cmplt cnv_cmplt goes to 1
			cnv_cmplt <= 1;
			
	end
	
	//state machine
	always_ff@(posedge clk, negedge rst_n) begin
		wrt = 0;			//default values to 0
		clr_hold = 0;
		set_hold = 0;
		set_cmplt = 0;
		
		case(state)
		
		TRANS1 : if(done) begin
								//done means this was only our first time so we go to HOLD state
			nextState = HOLD;
			end
			
		TRANS2 : if(done) begin
			set_cmplt =1;		//done after the second transaction means we are complete and we go back to IDLE
			nextState = IDLE;
			end
			
		
		HOLD : if(!done) begin
			wrt = 1;				//wait until done is deasserted then go back to TRANS (TRANS2)
			nextState = TRANS2;
			end else begin			//assert wrt and set hold otherwise
			wrt = 1;
			end
		
		default : if(strt_cnv) begin	//default is IDLE
			wrt = 1;					//on start conv we assert wrt, clr_hold, and then go to TRANS1.
			nextState = TRANS1;
			end
		
		endcase
	end



endmodule