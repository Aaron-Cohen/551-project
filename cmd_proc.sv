module cmd_proc(clk, rst_n, BMP_n, go, err_opn_lp, line_present, buzz, RX);

input clk;				// Operational Clock
input rst_n;			// Async active low reset
input BMP_n;			// Active low bumpers signal
input RX;				// Cmd transmission from BLE (?) module
input line_present;		// Line present from IR_intf
output reg go;			// Allows FRWRD register to ramp up, is active low reset for I_term
output reg [15:0] err_opn_lp;		// Error magic number to override IR_intf, induces turn
output reg buzz;		// Trigger piezo buzzer timer

parameter FAST_SIM = 1;

reg cmd_rdy; // State machine input from UART
reg cap_cmd; // State machine output for shift register to capture value of cmd
reg [15:0] cmd; // cmd vector from UART before heasing to cmd register
UART_wrapper UART(.clk(clk), .rst_n(rst_n), .RX(RX), .clr_cmd_rdy(cap_cmd), .cmd(cmd), .cmd_rdy(cmd_rdy));


// Shift register on cmd
reg nxt_cmd; // State machine output to get next command from c vector
reg [15:0] cmd_reg;
always_ff @(posedge clk) // Probably should gate this clock b/c enable requires a massive mux with multiple 16-bit wide inputs? Maybe will do later 
	if(cap_cmd)
		cmd_reg <= cmd;
	else if (nxt_cmd)
		cmd_reg <= {2'h0, cmd_reg[15:2]}; // shift register behavior

// Flop to keep track of last veer direction
reg last_veer_rght;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		last_veer_rght <= 0;
	else if (nxt_cmd)
		last_veer_rght <= cmd_reg[0]; 	// cmd_reg[1:0] == 01 is right, 10 is left. LSB can be stored on shift
										// to next command to record whether past command had veered right. 

// Timer register for state machine operations
reg clr_tmr;
reg [25:0] tmr;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		tmr <= 0;
	else if (clr_tmr)
		tmr <= 0;
	else 
		tmr <= tmr + 1;
		

// Determine timing parameters for turning, collision debounce, based on FAST_SIM parameter
logic REV_tmr1, REV_tmr2, BMP_DBNC_tmr;
generate
	if (FAST_SIM) begin
		assign REV_tmr1 = (tmr[20:16] == 5'h0A);
		assign REV_tmr2 = (tmr[20:16] == 5'h10);
		assign BMP_DBNC_tmr = &tmr[16:0];
	end
	else begin
		assign REV_tmr1 = (tmr[25:21] == 5'h16);
		assign REV_tmr2 = (tmr[25:21] == 5'h1F);
		assign BMP_DBNC_tmr = &tmr[21:0];
	end
endgenerate

// States and State Flop
typedef enum logic [2:0] {IDLE, MOVE, TURN_90, TURN_270, VEER, COLLISION, AWAIT_LINE, COLLISION_DEBOUNCE} states;
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
	buzz = 0;
	clr_tmr = 0;
	case (state)
		COLLISION_DEBOUNCE : begin // State will ignore any changes on bumpers
			buzz = 1;
			if (BMP_DBNC_tmr)
				next_state = COLLISION;
		end
		COLLISION : begin
			// Returns to move state if active low collision signal is not asserted, otherwise will toggle
			// buzz every 100 miliseconds
			if(!BMP_n)
				buzz = 1;
			else 
				next_state = MOVE;
		end
		VEER : begin
			go = 1;
			err_opn_lp = last_veer_rght ? 16'h340 : -16'h340;
			if(line_present) begin // VEER state only get moved into when line_present is low, so a high line_present indicates a rise
				nxt_cmd = 1;
				next_state = MOVE;
			end
		end
		TURN_270: begin
			go = 1;
			if (!REV_tmr2)
				err_opn_lp = last_veer_rght ? 16'h380 : -16'h380;
			else
				next_state = AWAIT_LINE;
		end
		AWAIT_LINE: begin
			go = 1;
			if(line_present) begin  // AWAIT_LINE only gets moved into when line_present is low, so a high line_present indicates a rise
				nxt_cmd = 1;		// err_opn_lp is zeroed out from state machine defaults
				next_state = MOVE;
			end
		end
		TURN_90 : begin
			go = 1;
			if(!REV_tmr1)
				err_opn_lp = last_veer_rght ? -16'h1E0 : 16'h1E0;
			else begin
				go = 0;
				clr_tmr = 1;
				next_state = TURN_270;
			end
		end
		MOVE : begin
			go = 1;
			// Presence of a line must be exclusively detected first as subsequent logic must
			// only occur if there is not a line present
			if(line_present) begin
				// If active low bumpers asserted, kickoff collision sequence
				if(!BMP_n) begin
					go = 0;
					clr_tmr = 1;
					next_state = COLLISION_DEBOUNCE;	
				end
				// Otherwise, if line present but no collision, remain in move state.
			end
			// Turn left/right command when cmd[1:0] == 11
			else if (&cmd_reg[1:0]) begin 
				go = 0; // go is cleared for one clk cycle (go will be high again in next state). Allows for I_term in PID to be cleared.
				clr_tmr = 1;
				next_state = TURN_90;
			end
			
			// Veer left/right command when |cmd[1:0]
			else if (|cmd_reg[1:0]) begin
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