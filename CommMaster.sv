module CommMaster(clk,rst_n,TX,cmd,snd_cmd,cmd_cmplt);

input clk,rst_n;		// clock and active low reset
input snd_cmd;			// tells TX section to transmit tx_data
input [15:0] cmd;		// byte-duple to transmit
output TX;				// Transmission line
output reg cmd_cmplt;	// cmd_cmplt asserted when transmission complete

// UART transmitter and necessary signals
wire [7:0] tx_data;
reg TX, trmt, tx_done;
UART_tx transmitter(.clk(clk),.rst_n(rst_n),.TX(TX),.trmt(trmt),.tx_data(tx_data),.tx_done(tx_done));

// State machine internal signals
reg init, sel, done;

// State definitions
typedef enum reg [1:0] {IDLE, BYTE1, BYTE2} states;
states state, next_state;

// Multiplexer for assigning data packet to transmit
assign tx_data = sel ? cmd[7:0] : cmd[15:8];

// State Flop
always_ff @(posedge clk, negedge rst_n)
	if (!rst_n)
		state <= IDLE;
	else
		state <= next_state;

// cmd_cmplt flop. Combinational logic can glitch- do not want a glitched result resulting in a bad cmd being read
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		cmd_cmplt <= 0;
	else if(init)
		cmd_cmplt <= 0; // Reset for each new transaction
	else if (done)
		cmd_cmplt <= 1;

// State Machine
always_comb begin
    // Set SM default outputs
    next_state = state;
	done = 0;
	init = 0;
	sel  = 0;
	trmt = 0;
    case (state)
      BYTE1 : begin
        if(tx_done) begin
			sel  = 1; // Select upper bits before transmission
			trmt = 1;
			next_state = BYTE2;
		end
      end
	  BYTE2 : begin
		// Note that in CommMaster module, TX_data will actually be selected back to the lower 8 bits as the reg resets.
		// This is not an issue because when the UART_tx receives the transmit signal, it captures the information while
		// it still is the correct upper 8 bits.
		if(tx_done) begin
			done = 1; // Assert completed operation
			next_state = IDLE;
		end
	  end
      default : begin		// Default to IDLE State
			if(snd_cmd) begin
				// Select already set from top of state machine, but has been left commented in as the implication is important.
				// Grab lower byte (8 bits)
				// sel = 0;
				init = 1;
				trmt = 1;
				next_state = BYTE1;
			end
		end
	endcase
end

endmodule

