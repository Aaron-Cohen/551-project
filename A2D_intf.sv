// Aaron Cohen - 11/11/2020
module A2D_intf(clk, rst_n, strt_cnv, cnv_cmplt, chnnl, res, SS_n, SCLK, MOSI, MISO);

input clk, rst_n;		// clock and asynch reset
input strt_cnv;			// Asserted to start conversion
input [2:0] chnnl;		// Specifies A2D channel to convert
input MISO;				// Serial data from A2D
output MOSI;			// Serial data to A2D
output SS_n;			// Active low slave select to A2D
output reg cnv_cmplt;	// Asserted to indicate conversion complete
output SCLK;			// Serial clock to A2D
output reg [11:0] res;	// lower 12 bits of result from SPI_mstr


reg [15:0] cmd;
assign cmd = {2'b00, chnnl, 11'h000};

reg [15:0] rd_data;

reg wrt, done;
reg set_cmplt;

SPI_mstr16 SPI_mstr16(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .wrt(wrt), .cmd(cmd), .done(done), .rd_data(rd_data));

assign res = ~rd_data[11:0];

// States and State Flop
typedef enum logic [1:0] {IDLE, AWAIT_CONVERSION, PAUSE, READ_CONVERSION} states;
states state, next_state;
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n)
		state <= IDLE;
	else
		state <= next_state;

// Flop for cnv_cmplt output
always_ff @(posedge clk, negedge rst_n)
	if(!rst_n) 
		cnv_cmplt <= 0;
	else if (strt_cnv)
		cnv_cmplt <= 0;
	else if (set_cmplt)
		cnv_cmplt <= 1;

// State Machine
always_comb begin
	// Default outputs for state machine
	wrt = 0;
	next_state = state;
	set_cmplt = 0;
	case (state)
	 AWAIT_CONVERSION : begin
		if(done) begin
			next_state = PAUSE;
		end
	 end
	 PAUSE : begin
		next_state = READ_CONVERSION;
		wrt = 1;
	 end
	 READ_CONVERSION : begin
		if(done) begin
			set_cmplt  = 1;
			next_state = IDLE;
		end
	 end
	 default : begin // Default to IDLE state, waits for strt_cnv
		if(strt_cnv) begin
			next_state = AWAIT_CONVERSION;
			wrt = 1;
		end
	 end
	endcase
  end

endmodule