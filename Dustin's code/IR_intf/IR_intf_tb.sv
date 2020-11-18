module IR_intf_tb();

reg clk, rst_n, MISO, MOSI, SCLK, SS_n, IR_en, IR_vld, line_present;
reg [11:0] IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3;

ADC128S conv(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI));
IR_intf intf(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI), .IR_en(IR_en), .IR_vld(IR_vld), .line_present(line_present), .IR_R0(IR_R0), .IR_R1(IR_R1), .IR_R2(IR_R2), .IR_R3(IR_R3), .IR_L0(IR_L0), .IR_L1(IR_L1), .IR_L2(IR_L2), .IR_L3(IR_L3));


initial begin
	clk = 0;
	rst_n = 0;
	repeat(5)@(negedge clk);
	rst_n = 1;
	
	//test 1 with timeout
	fork
		begin : timeout1
			repeat(30000) @(negedge clk);
			$display("error timed out, did not reach the correct value");
			$stop();

		end
		begin
			@(posedge IR_vld);
			disable timeout1;
			
		end
	
	join
	if((IR_R0 == ~12'hC00) && (IR_R1 == ~12'hBF1) && (IR_R2 == ~12'hBE2) && (IR_R3 == ~12'hBD3) &&(IR_L0 == ~12'hBC4) && (IR_L1 == ~12'hBB5) && (IR_L2 == ~12'hBA6) && (IR_L3 == ~12'hB97))
		$display("congragts, the first test worked");
	else begin
		$display("whoops something went wrong\n your values are IR_R0 = %h\n IR_R1 = %h\n IR_R2 = %h\n IR_R3 = %h\n IR_L0 = %h\n IR_L1 = %h\n IR_L2 = %h\n IR_L3 = %h", IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3);
		$stop();
	end
	
	
	//test 2 with timeout
	fork
		begin : timeout2
			repeat(30000) @(negedge clk);
			$display("error timed out, did not reach the correct value");
			$stop();

		end
		begin
			@(posedge IR_vld);
			disable timeout2;
			
		end
	
	join
	if((IR_R0 == ~12'hB80) && (IR_R1 == ~12'hB71) && (IR_R2 == ~12'hB62) && (IR_R3 == ~12'hB53) &&(IR_L0 == ~12'hB44) && (IR_L1 == ~12'hB35) && (IR_L2 == ~12'hB26) && (IR_L3 == ~12'hB17))
		$display("congragts, the second test worked");
	else begin
		$display("whoops something went wrong\n your values are IR_R0 = %h\n IR_R1 = %h\n IR_R2 = %h\n IR_R3 = %h\n IR_L0 = %h\n IR_L1 = %h\n IR_L2 = %h\n IR_L3 = %h", IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3);
		$stop();
	end
	
	$stop();


end







always
	clk = #1 ~clk;

endmodule