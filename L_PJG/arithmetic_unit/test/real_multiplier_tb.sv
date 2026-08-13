`include "qtz_def.svh"

module real_multiplier_tb;

	localparam qtz_t DUT_A_QTZ = get_qtz(1, 9, 6, REAL);
	localparam qtz_t DUT_B_QTZ = get_qtz(1, 4, 5, REAL);
	localparam qtz_t DUT_O_QTZ = get_qtz(1, 10, 10, REAL);

	reg  [DUT_A_QTZ.width-1:0] stim_a;
	reg  [DUT_B_QTZ.width-1:0] stim_b;
	wire [DUT_O_QTZ.width-1:0] dut_out;
	reg  [DUT_O_QTZ.width-1:0] expected;

	integer pass, fd, scan_ok;

	real_multiplier #(
		.INPUT_A_QTZ(DUT_A_QTZ),
		.INPUT_B_QTZ(DUT_B_QTZ),
		.OUTPUT_QTZ (DUT_O_QTZ)
	) dut (
		.InputA(stim_a),
		.InputB(stim_b),
		.OutputC(dut_out)
	);

	initial begin
		pass = 1;

		fd = $fopen("data/real_input.txt", "r");
		if (fd == 0) $fatal(1, "[FATAL] Cannot open data/real_input.txt");

		$display("[INFO] Loading InputA ...");
		scan_ok = $fscanf(fd, "%x\n", stim_a);
		$display("  InputA  = 0x%0x", stim_a);

		$display("[INFO] Loading InputB ...");
		scan_ok = $fscanf(fd, "%x\n", stim_b);
		$display("  InputB  = 0x%0x", stim_b);
		$fclose(fd);

		#5;

		fd = $fopen("data/out/real_multiplier_expected.txt", "r");
		if (fd == 0) $fatal(1, "[FATAL] Cannot open real_multiplier_expected.txt");
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
