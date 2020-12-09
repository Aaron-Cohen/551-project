module A2D_intf(clk, rst_n, strt_cnv, cnv_cmplt, chnnl, res, SS_n, SCLK, MOSI, MISO);

input clk, rst_n, strt_cnv, MISO;
input [2:0]chnnl;
output reg cnv_cmplt;
output SS_n, SCLK, MOSI;
output reg [11:0]res;

reg wrt, done;
reg [15:0]cmd;
reg [15:0]rd_data;
reg set_cmplt;

//continuous assignments
assign cmd = {2'b00, chnnl, 11'h000};
assign res = ~rd_data[11:0];

//infer SPI_mstr DUT
SPI_mstr16 spi(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), 
				.wrt(wrt), .cmd(cmd), .done(done), .rd_data(rd_data));

typedef enum reg [2:0]{IDLE, TRAN, HOLD, COMPLETE} state_t;
state_t state, nxt_state;

//infer state machine flip flop
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		state <= IDLE;
	else 
		state <= nxt_state;
end

//conversion complete flip flop
always_ff @(posedge clk, negedge rst_n) begin	
	if(!rst_n)
		cnv_cmplt <= 1'b0;
	else if (strt_cnv) 
		cnv_cmplt <= 1'b0;
	else if (set_cmplt)
		cnv_cmplt <= 1'b1;
end

//state machine logic
always_comb begin
	set_cmplt = 1'b0;
	wrt = 1'b0;
	nxt_state = IDLE;
	
	case(state)
		IDLE: begin
			if(strt_cnv) begin	
				wrt = 1'b1;
				nxt_state = TRAN;
			end
		end
		//transfer 1 - specify chnnl
		TRAN: begin
			if(done)
				nxt_state = HOLD;
			else 
				nxt_state = TRAN;
		end
		//hold one clock cycle - seperate transactions
		HOLD: begin
			if(!done) begin
				wrt = 1'b1;
				nxt_state = COMPLETE;
			end else begin
				wrt = 1'b1;
				nxt_state = HOLD;
			end
		end
		//transfer 2 - reads result of MISO
		COMPLETE: begin
			if(done) begin
				set_cmplt = 1'b1;
				nxt_state = IDLE;
		end else 
			nxt_state = COMPLETE;
		end
		default: begin
			//set_cmplt = 1'b1;
			nxt_state = IDLE;
		end
	endcase
end 

endmodule 