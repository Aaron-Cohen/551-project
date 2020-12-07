module UART_wrapper(clk, rst_n, RX, clr_cmd_rdy, cmd_rdy, cmd);

input clk, rst_n;
input RX;
input clr_cmd_rdy;

output reg cmd_rdy;
output reg [15:0] cmd;

reg [7:0] rx_data;
reg rx_rdy, clr_rdy, smpl;
reg [7:0] holder;
reg set_rdy, set_cmd;

typedef enum reg [1:0] {FIRST_HALF, SECOND_HALF} state_t;
	state_t state, nextState;  //create states

UART_rcv Rx(.clk(clk), .rst_n(rst_n), .RX(RX), .rdy(rx_rdy), .rx_data(rx_data), .clr_rdy(clr_rdy));


always@(posedge clk)
	if(set_cmd)
		cmd <= {rx_data, holder};


//ready 
always@(posedge clk, negedge rst_n)
	if(!rst_n)
		cmd_rdy <= 0;
	else if(clr_cmd_rdy)
		cmd_rdy <= 0;
	else if(set_rdy)
		cmd_rdy <= 1;
		
//state flop
always @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= FIRST_HALF;
	else
		state <= nextState;

//hold half of command
always_ff@(posedge clk, negedge rst_n)
	if(!rst_n)
		holder <= 0;
	else if(smpl)
		holder <= rx_data;


always_ff@(posedge clk, negedge rst_n) begin
	clr_rdy = 0;
	smpl = 0;
	set_cmd = 0;
	set_rdy = 0;
	nextState = FIRST_HALF;
	
	case(state)
		SECOND_HALF : 
		if(rx_rdy) begin
		  set_cmd = 1;
		  set_rdy = 1;
		end else 
			nextState = SECOND_HALF;
		  
		  
		default : 
		if(cmd_rdy)begin
		end
		else if(rx_rdy) begin
		  smpl = 1;
		  clr_rdy = 1;
		  nextState = SECOND_HALF;
		end
	endcase
end

endmodule