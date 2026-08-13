`include "qtz_def.svh"

module real_adder_tree_tb;

	localparam qtz_t DUT_I_QTZ  = get_qtz(1, 9, 6, REAL);
	localparam qtz_t DUT_O_QTZ  = get_qtz(1, 10, 10, REAL);
	localparam       DUT_ADD_NUM = 4;

	reg  [DUT_I_QTZ.width-1:0] stim [DUT_ADD_NUM-1:0];
	wire [DUT_O_QTZ.width-1:0] dut_out;
	reg  [DUT_O_QTZ.width-1:0] expected;

	integer pass, fd, i, scan_ok;

	real_adder_tree #(
		.INPUT_QTZ (DUT_I_QTZ),
		.OUTPUT_QTZ(DUT_O_QTZ),
		.ADD_NUM   (DUT_ADD_NUM)
	) dut (
		.Input(stim),
		.Output(dut_out)
	);

	initial begin
		pass = 1;

		fd = $fopen("data/real_adder_tree_input.txt", "r");
		if (fd == 0) $fatal(1, "[FATAL] Cannot open data/real_adder_tree_input.txt");

		for (i = 0; i < DUT_ADD_NUM; i++) begin
			scan_ok = $fscanf(fd, "%x\n", stim[i]);
			$display("  Input[%0d] = 0x%0x", i, stim[i]);
		end
		$fclose(fd);

		#5;

		fd = $fopen("data/out/real_adder_tree_expected.txt", "r");
		if (fd == 0) $fatal(1, "[FATAL] Cannot open real_adder_tree_expected.txt");
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
