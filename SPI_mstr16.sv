module SPI_mstr16(clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, cmd, done, rd_data);

	input clk, rst_n, wrt, MISO;
	input [15:0] cmd;

	output reg [15:0] rd_data;
	output reg done, SS_n, SCLK, MOSI;

	reg [4:0] bitcnt;
	reg [5:0] sclk_cnt;
	reg [15:0] shft_reg;
	reg init, rst_cnt, shft, smpl, sclk_clr, clr_done, set_done;
	reg MISO_smpl;


	typedef enum reg [1:0] {IDLE, TRANS, FRONT, BACK} state_t;
	state_t state, nextState;  //create states

	
	//continuous assign statements
	assign SCLK = sclk_cnt[5];
	assign MOSI = shft_reg[15];
	assign rd_data = shft_reg;
		
	


	//state machine
	always_ff@(posedge clk, negedge rst_n) begin
		init = 0;			//initialize values all to 0 and start in IDLE
		rst_cnt = 0;
		shft = 0;
		smpl = 0;
		clr_done = 0;
		set_done = 0;
		sclk_clr = 0;
		nextState = IDLE;
		
		case(state)
		
		
				
		FRONT : if(sclk_cnt == 6'b111111) begin //wait in FRONT until SCLK is about to go low
				
				nextState = TRANS;				//then go to TRANS
				end else begin			
				nextState = FRONT;
				end
				
		TRANS : if(bitcnt == 15 && sclk_cnt == 6'b011111) begin		//on the last bit of MISO and rising edge of SCLK
																	//set_done to 1 still enable sclk_cnt and sample the last bit
				sclk_clr = 1;
				smpl = 1;
				nextState = BACK;									//then go to BACK
				
				end else if(sclk_cnt == 6'b011111) begin			//on rising edge of SCLK
				smpl = 1;											//sample the bit and keep sclk_cnt enabled
							
				nextState = TRANS;									//stay in TRANS
				
				end else if(sclk_cnt == 6'b111111) begin			//on falling edge of SCLK
				shft = 1;											//shift the register storing the bits and keep sclk_cnt enabled
							
				nextState = TRANS;									//stay in TRANS
				
				end else begin										//Otherwise stay in TRANS with sclk counting
				
				nextState = TRANS;
				end
		
		BACK : if(sclk_cnt == 6'b111111) begin	//on the falling edge of SCLK
				shft = 1;						//shift the register holding the bits and set_done to 1
				set_done = 1;
				nextState = IDLE;
				sclk_clr = 1;					//then go to IDLE
				end else begin
				nextState = BACK;				//Otherwise stay in BACK
				end
				
		default : if(wrt) begin		//IDLE default
				init = 1;			//on wrt we initialize and rst_cnt and clear done
				rst_cnt = 1;		//then go to FRONT
				nextState = FRONT;
				clr_done = 1;
				end else
				sclk_clr = 1;
							//sitting in IDLE
		
		endcase
	end

	//MOSI
	always@(posedge clk) begin
		if(init)					//on init we put the cmd into the shft_reg
			shft_reg <= cmd;
		else if(shft) 									//on shft we shift in the MISO_smpl
			shft_reg <= {shft_reg[14:0], MISO_smpl};
	end
	//MISO
	always@(posedge clk) begin
		if(smpl)				//on smpl we put the MISO into MISO_smpl
			MISO_smpl <= MISO;

	end

	//done block
	always@(posedge clk, negedge rst_n) begin
		if(!rst_n)			//on !rst_n we set done to 0 - asynch
			done <=0;
		else if(clr_done)	//on clr_done we set done to 0
			done <= 0;
		else if(set_done)	//on set_done we set done to 1
			done<= 1;
	end

	//SS-n block
	always@(posedge clk, negedge rst_n) begin
		if(!rst_n)		 	//on !rst_n we set SS_n to 1 - asynch
			SS_n <= 1;
		else if(set_done)	//on set_done we set SS_n to 0
			SS_n <= 0;
		else if(wrt)
			SS_n <= 0;
		else
			SS_n <= done;	//SS_n gets done 
	end

	//create SCLK
	always @(posedge clk) begin
		if(rst_cnt) 				//on rst_cnt we preset sclk_cnt to given value
			sclk_cnt <= 6'b101111;
		else if(sclk_clr)
			sclk_cnt <= 6'b101111;
		else 						//otherwise we increment
			sclk_cnt <= sclk_cnt + 1;
	end

	//shift counter
	always@(posedge clk) begin	
		 if(rst_cnt)					//when rst_cnt clear bitcnt
			bitcnt <= 0;
		else if(shft)				//when shift bitcnt plus one
			bitcnt <= bitcnt + 1;
	end

	//state flops
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			state <= IDLE;
		else
			state <= nextState;



endmodule