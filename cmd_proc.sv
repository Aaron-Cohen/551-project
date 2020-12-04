module cmd_proc(clk, rst_n, BMPL_n, BMPR_n, go, err_opn_lp, line_present, buzz, RX);

input clk;				// Operational Clock
input rst_n;			// Async active low reset
input BMPL_n;			// Active low bumper left
input BMPR_n;			// Active low bumper right
input RX;				// Cmd transmission from BLE (?) module
input line_present;		// Line present from IR_intf
output go;				// Allows FRWRD register to ramp up, is active low reset for I_term
output err_opn_lp;		// Error magic number to override IR_intf, induces turn
output buzz;			// Trigger piezo buzzer

parameter FAST_SIM = 1;


UART_wrapper UART(.clk(clk), .rst_n(rst_n), .RX(RX), .clr_cmd_rdy(cap_cmd), .cmd(cmd), .cmd_rdy(cmd_rdy));

reg last_veer_rght;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		last_veer_rght <= 0; // TODO: verify this should be 0, and not some other value
	else if (nxt_cmd)
		last_veer_rght <= cmd_reg[1:0];

// Shift register on cmd
reg cmd_rdy; // State machine input
reg cap_cmd; // State machine output for shift register to capture value of cmd
reg [15:0] cmd;
reg [15:0] cmd_reg;
always_ff @(posedge clk) // Probably should gate this clock cuz enable requires a massive mux with 16-bit wide inputs? Do later cuz I'm lazy
	if(cap_cmd)
		cmd_reg <= cmd;
	else if (nxt_cmd)
		cmd_reg <= {2'h0, cmd_reg[15:2]}; // shift register behavior

// Creates tmr vector which other signals can be derived from(?) idk really
reg clr_tmr;
reg [25:0] tmr;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		tmr <= 0;
	else if (clr_tmr)
		tmr <= 0;
	else 
		tmr <= tmr + 1;
		

// This will be used for bumper debounce conditions but I have no clue what that means ^\_(x_x)_/^
generate
	if (FAST_SIM) begin
	
	end
	else begin
	
	end
endgenerate

reg enable_buzz;
reg toggle_buzz; 
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		buzz <= 0;
	else if (!enable_buzz) // Only allows toggle behavior when enabled, otherwise zeroes buzz
		buzz <= 0;
	else if(toggle_buzz) // Toggle enable signal
		buzz <= !buzz;


// States and State Flop
typedef enum logic [2:0] {IDLE, MOVE, TURN, VEER, COLLISION} states;
states state, next_state;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= next_state;

// State machine 
always_comb begin
	next_state = state;
	cap_cmd = 0;
	go = 0; 
	nxt_cmd = 0;
	err_opn_lp = 0;
	toggle_buzz = 0;
	enable_buzz = 0;
	clr_tmr = 0;
	case (state)
		COLLISION : begin
			enable_buzz = 1;
			// Returns to move state if neither collision signal is asserted, otherwise will toggle
			// buzz every 100 miliseconds
			if(BMPR_n && BMPL_n) begin
				next_state = MOVE;
			end
			else if (tmr >= 0.100 seconds) begin // TODO: determine value at 0.100 seconds
				clr_tmr = 1;
				toggle_buzz = 1;
			end
		end
		VEER : begin
			go = 1;
			err_opn_lp = 16'h340; // TODO: plus or minus logic
			if(line_present) begin // VEER state only get moved into when line_present is low, so a high line_present indicates a rise
				nxt_cmd = 1;
				next_state = MOVE;
			end
		end
		TURN : begin
			go = 1;
			// Cascading if/else statements allow for timer to be reused in same state.
			if(tmr < 0.923 seconds) // TODO: find out the actual value it will be at 0.923 seconds
				err_opn_lp = 16'h1E0; // TODO: Determine plus or minus logic
			else if (tmr == 0.923 seconds)
				go = 0;
			else if (tmr < 0.923 seconds + 1.300 seconds)	// TODO: find out actual value at 1.300 + 0.923 seconds
				err_opn_lp = 16'h380; // TODO: Determine plus or minus logic
			else begin
				err_opn_lp = 0;
				if(line_present) // TURN state only get moved to when line_present us low, so a high line_present indicates a rise
					nxt_cmd = 1;
					next_state = MOVE;
			end
		end
		MOVE : begin
			go = 1;
			// Presence of a line must be exclusively detected first as subsequent logic must
			// only occur if there is not a line present
			if(line_present)
				// If either active low bumper is asserted, kickoff collision sequence
				if(!(BMPR_n && BMPL_n)) begin
					go = 0;
					enable_buzz = 1;
					toggle_buzz = 1;
					clr_tmr = 1;
					next_state = COLLISION;	
				end
				// Otherwise, if line present but no collision, remain in move state.
			
			// Turn left/right command when cmd[1:0] == 11
			else if (&cmd_reg[1:0]) begin 
				go = 0; // go is cleared for one clk cycle b/c go goes high again in next state. Allows for I_term in PID to be cleared.
				clr_tmr = 1;
				next_state = TURN;
			end
			
			// Veer left/right command when |cmd[1:0]
			else if (|cmd_reg[1:0]) begin
				err_opn_lp = 16'h340; // TODO: Add plus-or-minus logic here
				next_state = VEER;
			end
			
			// No veer/turn command w/o a line_present will set device to IDLE, stopping it in its tracks
			else begin
				go = 0;
				next_state = IDLE;
			end
		end
		default : begin // Default to IDLE state
			// Kick off move sequence
			if(cmd_rdy & line_present) begin
				cap_cmd = 1;
				go = 1;
				next_state = MOVE;
			end
		end
	endcase
end

endmodule