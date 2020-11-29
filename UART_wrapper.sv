// Aaron Cohen - 10/30/2020
module UART_wrapper(clk,rst_n,RX,clr_cmd_rdy,cmd,cmd_rdy);

input clk, rst_n;		// clock and active low reset
input RX;				// transmission receiving line
input clr_cmd_rdy;		// clear old command, begin receiving new command
output reg [15:0] cmd;	// 16 bit command assembled from RX
output reg cmd_rdy;		// cmd output is finalized

// Internal signals between components and states
reg rdy, clr_rdy, init, shft, done;
reg [7:0] rx_data;
typedef enum reg [1:0] {IDLE, BYTE1, BYTE2} states;
states state, next_state;

// Instantiate UART receiver
UART_rcv UART_rcv(.clk(clk),.rst_n(rst_n),.RX(RX),.rdy(rdy),.rx_data(rx_data),.clr_rdy(clr_rdy));

// Command flop
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		cmd <= 0;
	else if (init) // Sync reset from state machine after clr_cmd_rdy
		cmd <= 0;
	else if (shft)
		cmd <= {cmd[7:0], rx_data}; // Shifting bytes in one at a time

// State flop
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= next_state;
		
// cmd_rdy flop. Combinational logic can glitch- do not want a glitched result resulting in a bad cmd being read
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		cmd_rdy <= 0;
	else if (init)
		cmd_rdy <= 0;
	else if (done)
		cmd_rdy <= 1;
		
// State machine
always_comb begin
	next_state 	= state;
	clr_rdy		= 0;
	init 		= 0;
	shft		= 0;
	done 		= 0;
	case (state) 
		BYTE1 : begin
			if(rdy) begin
				shft       = 1; // Have cmd absorb rx_data
				clr_rdy    = 1; // Prepare for byte of data
				next_state = BYTE2;
			end
		end
		BYTE2: begin
			if(rdy) begin
				shft 	   = 1;
				done 	   = 1;
				next_state = IDLE;
			end
		end
		default : begin // Default to IDLE state
			if(clr_cmd_rdy) begin
				init	   = 1; // Reset cmd
				clr_rdy    = 1; // Prepare for byte of data
				next_state =  BYTE1;
			end
		end
	endcase
end

endmodule