// Aaron Cohen - 10/23/2020
module SPI_mstr16(clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, cmd, done, rd_data);

input clk, rst_n;			// clock and asynch reset
input wrt; 					// High for 1 clock period to initiate SPI transaction
input MISO;					// Feedback from slave to master
input [15:0] cmd;			// Initial command or data sent from master to slave
output SCLK, MOSI; 			// SPI protocol signals
output reg SS_n;
output reg done; 			// Asserted when SPI complete
output [15:0] rd_data;  	// Data from SPI slave



reg [15:0] shift_register;  // As MOSI shifts out, MISO shifts in
reg [4:0] sclk_div;			// Increments on clk, every 64 clk cycles, MSB (i.e. sclk) flips
reg [3:0] sclk_cnt; 		// Keepts track of how many times sclk has been asserted
reg MISO_smpl;				// MISO sample to be shifted in
reg sclk_done;				// True when 16 cycles of sclk have occured
reg smpl, shft, init, rst_cnt; // State machine command signals

// Due to carrying on MSB, these values indicate to SM that SCLK is about to transition
localparam impending_fall  = 5'b11111;
localparam impending_rise  = 5'b01111;

// SCLK generator
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		sclk_div <= 5'b10111;
	else if(init || rst_cnt) // SYNC reset
		sclk_div <= 5'b10111; 
	else
		sclk_div <= sclk_div + 1'b1;
assign SCLK = sclk_div[4]; // MSB flips every 64 cycles as lesser significant bits increment

// SCLK Cycle (bit) counter
always_ff @(posedge clk)
	if(init)
		sclk_cnt <= 0;
	else if(sclk_div == impending_rise)
		sclk_cnt <= sclk_cnt + 1;
assign sclk_done = &sclk_cnt;	// Due to flopping nature here, sclk_cnt lags behind by a value of 1 from where the SM would like to "think" it is.
								// As a result, by saying we are done at 15 (&reduction on 0xF), state machine cuts off at where it thinks it is at 16.


// States and State Flop
typedef enum logic [1:0] {IDLE = 2'b00 , FRONT_PORCH = 2'b01, SHIFT = 2'b10, BACK_PORCH = 2'b11} states;
states state, next_state;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= next_state;
		
// Sample MISO when smpl signal asserted.
always_ff @(posedge clk)
	if(smpl)
		MISO_smpl <= MISO;

// Load/Shift shift register.
always_ff @(posedge clk)
	if(init)
		shift_register <= cmd;
	else if (shft)
		shift_register <= {shift_register[14:0], MISO_smpl};
assign rd_data = shift_register;
assign MOSI = shift_register[15];
	
// Flop output of SS_n signal
always_ff @(posedge clk, negedge rst_n) 
	if (!rst_n) // Preset
		SS_n <= 1'b1;
	else if (init)
		SS_n <= 1'b0;
	else if (rst_cnt) // Lock SS_n high if done or setting done
		SS_n <= 1'b1;
		
// Flop output of done signal
always_ff @(posedge clk, negedge rst_n) 
	if (!rst_n)
		done <= 1'b0;
	else if (init)
		done <= 1'b0;
 	else if (rst_cnt)
		done <= 1'b1;

// State Machine
always_comb begin
	// Default outputs for state machine
	smpl 	   = 1'b0;
	init 	   = 1'b0;
	shft 	   = 1'b0;
	rst_cnt    = 1'b0;
	next_state = state;
	case (state)
	 FRONT_PORCH : begin
		if(sclk_div == impending_fall) // Only move to SHIFT upon SCLK falling
			next_state = SHIFT; 
	 end
	 SHIFT : begin
		if(sclk_div == impending_rise) begin
			smpl = 1'b1;  // Sample MISO on SCLK rise
			if(sclk_done) // After 15 SCLK cycles,
				next_state = BACK_PORCH;
		end
		else if (sclk_div == impending_fall)
			shft = 1'b1; // Shift MOSI and shift register
	 end
	 BACK_PORCH : begin
		if (sclk_div == impending_fall) begin
			shft = 1'b1;      // Final shift
			rst_cnt = 1'b1; // Will cause SS_n to be asserted, also keeps SCLK high. Doubles as a set_done signal
			next_state = IDLE;
		end
	 end
	 default : begin // Default to IDLE state, waits for write signal
		rst_cnt = 1'b1; // Lock SS_n high
		if(wrt) begin
			next_state = FRONT_PORCH;
			init = 1'b1;
		end
	 end
	endcase
  end

endmodule