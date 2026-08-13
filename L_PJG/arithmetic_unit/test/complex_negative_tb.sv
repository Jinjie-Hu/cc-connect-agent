`include "qtz_def.svh"

module complex_negative_tb;

	localparam qtz_t DUT_QTZ = get_qtz(1, 9, 6, COMPLEX);

	reg  [DUT_QTZ.width-1:0] stim_a;
	wire [DUT_QTZ.width-1:0] dut_out;
	reg  [DUT_QTZ.width-1:0] expected;

	integer pass, fd, scan_ok;

	complex_negative #(
		.INPUT_QTZ(DUT_QTZ)
	) dut (
		.InputA(stim_a),
		.OutputB(dut_out)
	);

	initial begin
		pass = 1;

		fd = $fopen("data/complex_input.txt", "r");
		if (fd == 0) $fatal(1, "[FATAL] Cannot open data/complex_input.txt");

		$display("[INFO] Loading InputA ...");
		scan_ok = $fscanf(fd, "%x\n", stim_a);
		$display("  InputA  = 0x%0x", stim_a);
		$fclose(fd);

		#5;

		fd = $fopen("data/out/complex_negative_expected.txt", "r");
		if (fd == 0) $fatal(1, "[FATAL] Cannot open complex_negative_expected.txt");
		scan_ok = $fscanf(fd, "%x\n", expected);
		$fclose(fd);

		$display("[INFO] DUT   out = 0x%0x (%0d bits)", dut_out, DUT_QTZ.width);
		$display("[INFO] Expected = 0x%0x", expected);

		if (dut_out !== expected) begin
			$display("[FAIL] MISMATCH"); pass = 0;
		end else $display("[PASS] Output matches.");

		if (pass) $display("\n===== TEST PASSED =====");
		else      $display("\n===== TEST FAILED =====");
		$finish(pass ? 0 : 1);
	end
endmodule
