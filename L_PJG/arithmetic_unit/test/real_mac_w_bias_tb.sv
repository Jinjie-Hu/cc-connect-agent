`include "qtz_def.svh"

module real_mac_w_bias_tb;

	localparam qtz_t DUT_A_QTZ  = get_qtz(1, 9, 6, REAL);
	localparam qtz_t DUT_B_QTZ  = get_qtz(1, 4, 5, REAL);
	localparam qtz_t DUT_C_QTZ  = get_qtz(1, 6, 7, REAL);
	localparam qtz_t DUT_O_QTZ  = get_qtz(1, 10, 10, REAL);
	localparam       DUT_PAIRS  = 4;

	reg  [DUT_A_QTZ.width-1:0] stim_A [DUT_PAIRS-1:0];
	reg  [DUT_B_QTZ.width-1:0] stim_B [DUT_PAIRS-1:0];
	reg  [DUT_C_QTZ.width-1:0] stim_C;
	wire [DUT_O_QTZ.width-1:0] dut_out;
	reg  [DUT_O_QTZ.width-1:0] expected;

	integer pass, fd, i, scan_ok;

	real_mac_w_bias #(
		.MUL_IN_A_QTZ  (DUT_A_QTZ),
		.MUL_IN_B_QTZ  (DUT_B_QTZ),
		.INPUT_C_QTZ   (DUT_C_QTZ),
		.OUTPUT_QTZ    (DUT_O_QTZ),
		.MUL_IN_PAIR_NUM(DUT_PAIRS)
	) dut (
		.InputA(stim_A),
		.InputB(stim_B),
		.InputC(stim_C),
		.OutputC(dut_out)
	);

	initial begin
		pass = 1;

		fd = $fopen("data/real_input.txt", "r");
		if (fd == 0) $fatal(1, "[FATAL] Cannot open data/real_input.txt");

		$display("[INFO] Loading InputA ...");
		for (i = 0; i < DUT_PAIRS; i++) begin
			scan_ok = $fscanf(fd, "%x\n", stim_A[i]);
			$display("  InputA[%0d] = 0x%0x", i, stim_A[i]);
		end

		$display("[INFO] Loading InputB ...");
		for (i = 0; i < DUT_PAIRS; i++) begin
			scan_ok = $fscanf(fd, "%x\n", stim_B[i]);
			$display("  InputB[%0d] = 0x%0x", i, stim_B[i]);
		end

		$display("[INFO] Loading InputC ...");
		scan_ok = $fscanf(fd, "%x\n", stim_C);
		$display("  InputC  = 0x%0x", stim_C);
		$fclose(fd);

		#5;

		fd = $fopen("data/out/real_mac_w_bias_expected.txt", "r");
		if (fd == 0) $fatal(1, "[FATAL] Cannot open real_mac_w_bias_expected.txt");
		scan_ok = $fscanf(fd, "%x\n", expected);
		$fclose(fd);

		$display("[INFO] DUT   out = 0x%0x (%0d bits)", dut_out, DUT_O_QTZ.width);
		$display("[INFO] Expected = 0x%0x", expected);

		if (dut_out !== expected) begin
			$display("[FAIL] MISMATCH"); pass = 0;
		end else $display("[PASS] Output matches.");

		if (pass) $display("\n===== TEST PASSED =====");
		else      $display("\n===== TEST FAILED =====");
		$finish(pass ? 0 : 1);
	end
endmodule
