module UART_wrapper(clk, rst_n, RX, clr_cmd_rdy, cmd_rdy, cmd);

input clk, rst_n;
input RX;
input clr_cmd_rdy;

output reg cmd_rdy;
output reg [15:0] cmd;

reg [7:0] rx_data;
reg rx_rdy, clr_rdy, smpl;
reg set_rdy, set_cmd;

UART_rcv Rx(.clk(clk), .rst_n(rst_n), .RX(RX), .rdy(rx_rdy), .rx_data(rx_data), .clr_rdy(clr_rdy));

// Ready flop
always@(posedge clk, negedge rst_n)
	if(!rst_n)
		cmd_rdy <= 0;
	else if(clr_cmd_rdy)
		cmd_rdy <= 0;
	else if(set_rdy)
		cmd_rdy <= 1;

// States and State flop	
typedef enum reg [1:0] {FIRST_HALF, SECOND_HALF} state_t;
state_t state, nextState; 
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= FIRST_HALF;
	else
		state <= nextState;

// Register to store byte 1 of command while reading byte 2
reg [7:0] byte_holder;
always_ff@(posedge clk, negedge rst_n)
	if(!rst_n)
		byte_holder <= 0;
	else if(smpl)
		byte_holder <= rx_data;
		
// Assemble cmd when all data necessary has been collected
always @(posedge clk)
	if(set_cmd)
		cmd <= {byte_holder, rx_data};

// State machine
always_comb begin
	clr_rdy = 0;
	smpl = 0;
	set_cmd = 0;
	set_rdy = 0;
	nextState = state;
	
	case(state)
		SECOND_HALF : begin
			if(rx_rdy) begin
				set_cmd = 1;
				set_rdy = 1;
				nextState = FIRST_HALF;
			end
		end
		default : begin // Default to FIRST_HALF
			if(rx_rdy) begin
				smpl = 1;
				clr_rdy = 1;
				nextState = SECOND_HALF;
			end
		end
	endcase
end

endmodule