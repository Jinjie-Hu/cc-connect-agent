`include "qtz_def.svh"

// ============================================================================
// Testbench for complex_mac  (no bias)
//
// Reads:
//   complex_mac_input.txt    — stimuli (hex, one per line)
//   complex_mac_expected.txt — golden output (hex)
//
// Parameters hardcoded to match Python generator defaults.
// ============================================================================
module complex_mac_tb;

	localparam qtz_t DUT_A_QTZ   = get_qtz(1, 9, 6, COMPLEX);
	localparam qtz_t DUT_B_QTZ   = get_qtz(1, 4, 5, COMPLEX);
	localparam qtz_t DUT_OUT_QTZ = get_qtz(1, 10, 10, COMPLEX);
	localparam DUT_PAIRS          = 4;
	localparam DUT_FAST           = 0;

	reg  [DUT_A_QTZ.width-1:0]  stim_A   [DUT_PAIRS-1:0];
	reg  [DUT_B_QTZ.width-1:0]  stim_B   [DUT_PAIRS-1:0];
	wire [DUT_OUT_QTZ.width-1:0] dut_out;
	reg  [DUT_OUT_QTZ.width-1:0] expected;

	integer pass, fd, i, scan_ok;

	complex_mac #(
		.MUL_IN_A_QTZ  (DUT_A_QTZ),
		.MUL_IN_B_QTZ  (DUT_B_QTZ),
		.OUTPUT_QTZ    (DUT_OUT_QTZ),
		.MUL_IN_PAIR_NUM(DUT_PAIRS),
		.FAST_MODE_EN  (DUT_FAST)
	) dut (
		.InputA(stim_A),
		.InputB(stim_B),
		.OutputC(dut_out)
	);

	initial begin
		pass = 1;

		// --------------------------------------------------------
		// Load input stimuli
		// --------------------------------------------------------
		fd = $fopen("data/complex_mac_input.txt", "r");
		if (fd == 0) begin
			$fatal(1, "[FATAL] Cannot open complex_mac_input.txt");
		end

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
		$fclose(fd);

		// Wait for combinational logic
		#5;

		// --------------------------------------------------------
		// Compare with expected output
		// --------------------------------------------------------
		fd = $fopen("data/out/complex_mac_expected.txt", "r");
		if (fd == 0) begin
			$fatal(1, "[FATAL] Cannot open complex_mac_expected.txt");
		end

		scan_ok = $fscanf(fd, "%x\n", expected);
		$fclose(fd);

		$display("[INFO] DUT output = 0x%0x (%0d bits)", dut_out, DUT_OUT_QTZ.width);
		$display("[INFO] Expected   = 0x%0x", expected);

		if (dut_out !== expected) begin
			$display("[FAIL] MISMATCH  ^^^");
			pass = 0;
		end else begin
			$display("[PASS] Output matches.");
		end

		if (pass)
			$display("\n===== TEST PASSED =====");
		else
			$display("\n===== TEST FAILED =====");

		$finish(pass ? 0 : 1);
	end

endmodule
