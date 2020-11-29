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
			repeat(30000) @(negedge clk);  //timeout after many clock cycles without seeing IR_vld
			$display("error timed out, did not reach the correct value");
			$stop();

		end
		begin
			@(posedge IR_vld);
			disable timeout1;
			
		end
	
	join
	//ensure values continue to decrement by 0x010 and all have the channel number attached and then inverted.
	if((IR_R0 == ~12'hC00) && (IR_R1 == ~12'hBF1) && (IR_R2 == ~12'hBE2) && (IR_R3 == ~12'hBD3) &&(IR_L0 == ~12'hBC4) && (IR_L1 == ~12'hBB5) && (IR_L2 == ~12'hBA6) && (IR_L3 == ~12'hB97))
		$display("congragts, the first test worked");
	else begin
		$display("whoops something went wrong\n your values are IR_R0 = %h\n IR_R1 = %h\n IR_R2 = %h\n IR_R3 = %h\n IR_L0 = %h\n IR_L1 = %h\n IR_L2 = %h\n IR_L3 = %h", IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3);
		$stop();
	end
	
	
	//test 2 with timeout 
	fork
		begin : timeout2
			repeat(30000) @(negedge clk);	//timeout after many clock cycles without seeing IR_vld
			$display("error timed out, did not reach the correct value");
			$stop();

		end
		begin
			@(posedge IR_vld);
			disable timeout2;
			
		end
	
	join
	//ensure values continue to decrement by 0x010 and all have the channel number attached and then inverted.
	if((IR_R0 == ~12'hB80) && (IR_R1 == ~12'hB71) && (IR_R2 == ~12'hB62) && (IR_R3 == ~12'hB53) &&(IR_L0 == ~12'hB44) && (IR_L1 == ~12'hB35) && (IR_L2 == ~12'hB26) && (IR_L3 == ~12'hB17))
		$display("congragts, the second test worked");
	else begin
		$display("whoops something went wrong\n your values are IR_R0 = %h\n IR_R1 = %h\n IR_R2 = %h\n IR_R3 = %h\n IR_L0 = %h\n IR_L1 = %h\n IR_L2 = %h\n IR_L3 = %h", IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3);
		$stop();
	end
	
	
	//test 3 with timeout
	fork
		begin : timeout3
			repeat(30000) @(negedge clk);	//timeout after many clock cycles without seeing IR_vld
			$display("error timed out, did not reach the correct value");
			$stop();

		end
		begin
			@(posedge IR_vld);
			disable timeout3;
			
		end
	
	join
	//ensure values continue to decrement by 0x010 and all have the channel number attached and then inverted.
	if((IR_R0 == ~12'hB00) && (IR_R1 == ~12'hAF1) && (IR_R2 == ~12'hAE2) && (IR_R3 == ~12'hAD3) &&(IR_L0 == ~12'hAC4) && (IR_L1 == ~12'hAB5) && (IR_L2 == ~12'hAA6) && (IR_L3 == ~12'hA97))
		$display("congragts, the third test worked");
	else begin
		$display("whoops something went wrong\n your values are IR_R0 = %h\n IR_R1 = %h\n IR_R2 = %h\n IR_R3 = %h\n IR_L0 = %h\n IR_L1 = %h\n IR_L2 = %h\n IR_L3 = %h", IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3);
		$stop();
	end
	
	
	//test 4 with timeout
	fork
		begin : timeout4
			repeat(30000) @(negedge clk);	//timeout after many clock cycles without seeing IR_vld
			$display("error timed out, did not reach the correct value");
			$stop();

		end
		begin
			@(posedge IR_vld);
			disable timeout4;
			
		end
	
	join
	//ensure values continue to decrement by 0x010 and all have the channel number attached and then inverted.
	if((IR_R0 == ~12'hA80) && (IR_R1 == ~12'hA71) && (IR_R2 == ~12'hA62) && (IR_R3 == ~12'hA53) &&(IR_L0 == ~12'hA44) && (IR_L1 == ~12'hA35) && (IR_L2 == ~12'hA26) && (IR_L3 == ~12'hA17))
		$display("congragts, the forth test worked");
	else begin
		$display("whoops something went wrong\n your values are IR_R0 = %h\n IR_R1 = %h\n IR_R2 = %h\n IR_R3 = %h\n IR_L0 = %h\n IR_L1 = %h\n IR_L2 = %h\n IR_L3 = %h", IR_R0, IR_R1, IR_R2, IR_R3, IR_L0, IR_L1, IR_L2, IR_L3);
		$stop();
	end
	
	//tests that line_present goes down eventually. (need to change the parameter in IR_intf).
	fork
		begin : timeout5
			repeat(3000000) @(negedge clk);	//timeout after many clock cycles without seeing line_present
			$display("error timed out, line_present never went down.");
			$stop();

		end
		begin
			@(negedge line_present);
			disable timeout5;
			$display("line_present went down, good!");
		end
	
	join
	$display("looks like all the tests passed. good job!");
	
	
	$stop();


end







always
	clk = #1 ~clk;

endmodule