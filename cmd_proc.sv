module cmd_proc(clk, rst_n, BMPL_n, BMPR_n, go, err_opn_lp, line_present, buzz, RX);

input clk;				// Operational Clock
input rst_n;			// Async active low reset
input BMPL_n;			// Active low bumper left
input BMPR_n;			// Active low bumper right
input RX;				// Cmd transmission from BLE (?) module
input line_present;		// Line present from IR_intf
output go;				// Allows FRWRD register to ramp up
output err_opn_lp;		// Error magic number to override IR_intf, induces turn
output buzz;			// Trigger buzzer

reg cap_cmd; // State machine output
reg cmd_rdy; // State machine input
reg [15:0] cmd;

UART_wrapper UART(.clk(clk), .rst_n(rst_n), .RX(RX), .clr_cmd_rdy(cap_cmd), .cmd(cmd), .cmd_rdy(cmd_rdy));

// Creates tmr vector which other signals can be derived from(?)
reg [25:0] tmr;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		tmr <= 0;
	else if (go)
		tmr <= 0;
	else 
		tmr <= tmr + 1;
		
		
		

// This will be used for bumper debounce conditions
generate
	if (FAST_SIM) begin
	
	end
	else begin
	
	end
endgenerate

// States and State Flop
typedef enum logic [1:0] {IDLE} states;
states state, next_state;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= next_state;

// State machine
always_comb begin
	next_state = state;
	case (state)
		IDLE : begin
		
		end
		default : begin
		
		end
	endcase
end

endmodule