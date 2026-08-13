`include "qtz_def.svh"

module complex_addsub #(
	parameter qtz_t INPUT_A_QTZ = DEFAULT_QTZ,
	parameter qtz_t INPUT_B_QTZ = DEFAULT_QTZ,
	parameter qtz_t OUTPUT_QTZ  = DEFAULT_QTZ
) (
	input   [INPUT_A_QTZ.width-1:0]  InputA,
	input   [INPUT_B_QTZ.width-1:0]  InputB,
	input   					     sub,
	output  [ OUTPUT_QTZ.width-1:0]  OutputC
);

	localparam qtz_t IN_A_REAL_QTZ = get_qtz(INPUT_A_QTZ.sgn_w, INPUT_A_QTZ.int_w, INPUT_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_REAL_QTZ = get_qtz(INPUT_B_QTZ.sgn_w, INPUT_B_QTZ.int_w, INPUT_B_QTZ.fp_w, REAL);
	localparam qtz_t OUT_REAL_QTZ  = get_qtz(OUTPUT_QTZ.sgn_w, OUTPUT_QTZ.int_w, OUTPUT_QTZ.fp_w, REAL);

	real_addsub #(
		.INPUT_A_QTZ(IN_A_REAL_QTZ),
		.INPUT_B_QTZ(IN_B_REAL_QTZ),
		.OUTPUT_QTZ (OUT_REAL_QTZ)
	) addsub_real(
		.InputA (InputA[INPUT_A_QTZ.width-1 -: IN_A_REAL_QTZ.width]),
		.InputB (InputB[INPUT_B_QTZ.width-1 -: IN_B_REAL_QTZ.width]),
		.OutputC(OutputC[OUTPUT_QTZ.width-1 -: OUT_REAL_QTZ.width]),
		.sub(sub)
	);

	real_addsub #(
		.INPUT_A_QTZ(IN_A_REAL_QTZ),
		.INPUT_B_QTZ(IN_B_REAL_QTZ),
		.OUTPUT_QTZ (OUT_REAL_QTZ)
	) addsub_imag(
		.InputA (InputA[0 +: IN_A_REAL_QTZ.width]),
		.InputB (InputB[0 +: IN_B_REAL_QTZ.width]),
		.OutputC(OutputC[0 +: OUT_REAL_QTZ.width]),
		.sub(sub)
	);

endmodule