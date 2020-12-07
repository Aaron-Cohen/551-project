module cmd_proc_old(clk, rst_n, BMPL_n, BMPR_n, go, err_opn_lp, line_present, buzz, RX);

input clk;				// Operational Clock
input rst_n;			// Async active low reset
input BMPL_n;			// Active low bumper left
input BMPR_n;			// Active low bumper right
input RX;				// Cmd transmission from BLE (?) module
input line_present;		// Line present from IR_intf
output go;				// Allows FRWRD register to ramp up, is active low reset for I_term
output err_opn_lp;		// Error magic number to override IR_intf, induces turn
output buzz;			// Trigger buzzer

parameter FAST_SIM = 1;

reg cap_cmd; // State machine output for shift register to capture value of cmd
reg cmd_rdy; // State machine input
reg [15:0] cmd;

UART_wrapper UART(.clk(clk), .rst_n(rst_n), .RX(RX), .clr_cmd_rdy(cap_cmd), .cmd(cmd), .cmd_rdy(cmd_rdy));

reg last_veer_rght;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		last_veer_rght <= 0; // TODO: verify this should be 0, and not some other value
	else if (nxt_cmd)
		last_veer_rght <= cmd_reg[1:0];

// Shift register on cmd
reg [15:0] cmd_reg;
always_ff @(posedge clk) // Probably should gate this clock cuz enable requires a mux with 16-bit wide inputs? Do later cuz I'm lazy
	if(cap_cmd)
		cmd_reg <= cmd;
	else if (nxt_cmd)
		cmd_reg <= {2'h0, cmd_reg[15:2]}; // shift register behavior

// Creates tmr vector which other signals can be derived from(?) idk really
reg [25:0] tmr;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		tmr <= 0;
	else if (!go)
		tmr <= 0;
	else 
		tmr <= tmr + 1;
		

// This will be used for bumper debounce conditions but I have no clue what that means \_(x_x)_/
generate
	if (FAST_SIM) begin
	
	end
	else begin
	
	end
endgenerate

// States and State Flop
typedef enum logic [3:0] {IDLE, DETECT_LINE, TURN_90, TURN_270, ACTIVE, REORIENT} states;
states state, next_state;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= next_state;

// State machine - far from perfect
always_comb begin
	next_state = state;
	cap_cmd = 0;
	go = 1; // Go defaulted to true / asserted
	nxt_cmd = 0;
	err_opn_lp = 0;
	buzz = 0;
	case (state)
		REORIENT : begin
			if( !BMPL_n || !BMPR_n )
				next_state = DETECT_LINE;
			else begin
				go = 0;
				buzz = 1;
			end
		end
		ACTIVE : begin
			if( BMPL_n && BMPR_n ) // Neither (active low) bump swithc enabled
				next_state = DETECT_LINE;
			else begin
				go = 0;
				buzz = 1;
				
				if(tmr >= 0.100 seconds) // TODO: find out actual value at 100 ms
					next_state = REORIENT;
			end
		end
		TURN_270 : begin
			if(tmr < 1.300 seconds) // TODO: find out actual value at 1.300 seconds
				err_opn_lp = 16'h380; // TODO: Determine plus or minus logic
			else begin
				err_opn_lp = 0;
				if(line_present) begin
					nxt_cmd = 1;
					next_state = DETECT_LINE;
				end
			end
		end
		TURN_90 : begin
			if(tmr < 0.923 seconds) // TODO: find out the actual value it will be at 0.923 seconds
				err_opn_lp = 16'h1E0; // TODO: Determine plus or minus logic
			else begin
				go = 0; // clears timer
				next_state = TURN_270;
			end
		end
		DETECT_LINE : begin
			if(line_present)
				next_state = ACTIVE;
			else if (&cmd_reg[1:0]) begin
				go = 0;
				next_state = TURN_90;
			end
			else if (|cmd_reg[1:0]) begin
				err_opn_lp = 16'h340; // TODO: Add plus-or-minus logic here
				if(line_present)
					nxt_cmd = 1;
			end
			else begin
				go = 0;
				next_state = IDLE;
			end
		end
		default : begin // Default to IDLE state
			go = 0;
			if(cmd_rdy & line_present) begin
				cap_cmd = 1;
				go = 1;
				next_state = DETECT_LINE;
			end
		end
	endcase
end

endmodule