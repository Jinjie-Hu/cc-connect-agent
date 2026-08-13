`include "qtz_def.svh"

module complex_real_multiplier_tb;

	localparam qtz_t DUT_C_QTZ = get_qtz(1, 9, 6, COMPLEX);
	localparam qtz_t DUT_R_QTZ = get_qtz(1, 4, 5, REAL);
	localparam qtz_t DUT_O_QTZ = get_qtz(1, 10, 10, COMPLEX);

	reg  [DUT_C_QTZ.width-1:0] stim_c;
	reg  [DUT_R_QTZ.width-1:0] stim_r;
	wire [DUT_O_QTZ.width-1:0] dut_out;
	reg  [DUT_O_QTZ.width-1:0] expected;

	integer pass, fd, scan_ok;

	complex_real_multiplier #(
		.INPUT_COMPLEX_QTZ(DUT_C_QTZ),
		.INPUT_REAL_QTZ   (DUT_R_QTZ),
		.OUTPUT_COMPLEX_QTZ(DUT_O_QTZ)
	) dut (
		.complex_in(stim_c),
		.real_in(stim_r),
		.complex_out(dut_out)
	);

	initial begin
		pass = 1;

		fd = $fopen("data/complex_input.txt", "r");
		if (fd == 0) $fatal(1, "[FATAL] Cannot open data/complex_input.txt");

		$display("[INFO] Loading complex_in ...");
		scan_ok = $fscanf(fd, "%x\n", stim_c);
		$display("  complex_in = 0x%0x", stim_c);

		$display("[INFO] Loading real_in ...");
		scan_ok = $fscanf(fd, "%x\n", stim_r);
		$display("  real_in    = 0x%0x", stim_r);
		$fclose(fd);

		#5;

		fd = $fopen("data/out/complex_real_multiplier_expected.txt", "r");
		if (fd == 0) $fatal(1, "[FATAL] Cannot open complex_real_multiplier_expected.txt");
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
