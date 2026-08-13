`include "qtz_def.svh"

module complex_real_multiplier #(
	parameter qtz_t INPUT_COMPLEX_QTZ = 'b0,
	parameter qtz_t INPUT_REAL_QTZ = 'b0,
	parameter qtz_t OUTPUT_COMPLEX_QTZ  = 'b0
) (
	input  [INPUT_COMPLEX_QTZ.width-1:0] complex_in,
	input  [INPUT_REAL_QTZ.width-1:0] real_in,
	output [OUTPUT_COMPLEX_QTZ.width-1:0] complex_out
);

	localparam qtz_t  INPUT_COMPLEX2REAL_QTZ = get_qtz(INPUT_COMPLEX_QTZ.sgn_w , INPUT_COMPLEX_QTZ.int_w , INPUT_COMPLEX_QTZ.fp_w , REAL);
	localparam qtz_t OUTPUT_COMPLEX2REAL_QTZ = get_qtz(OUTPUT_COMPLEX_QTZ.sgn_w, OUTPUT_COMPLEX_QTZ.int_w, OUTPUT_COMPLEX_QTZ.fp_w, REAL);

	logic [OUTPUT_COMPLEX2REAL_QTZ.width-1:0] complex_out_real;
	logic [OUTPUT_COMPLEX2REAL_QTZ.width-1:0] complex_out_imag;

	real_multiplier #(
		.INPUT_A_QTZ(INPUT_COMPLEX2REAL_QTZ),
		.INPUT_B_QTZ(INPUT_REAL_QTZ),
		.OUTPUT_QTZ (OUTPUT_COMPLEX2REAL_QTZ)
	) u_real_mul_0(
		.InputA(complex_in[INPUT_COMPLEX_QTZ.width-1 -: (INPUT_COMPLEX_QTZ.width/2)]),
		.InputB(real_in),
		.OutputC(complex_out_real)
	);

	real_multiplier #(
		.INPUT_A_QTZ(INPUT_COMPLEX2REAL_QTZ),
		.INPUT_B_QTZ(INPUT_REAL_QTZ),
		.OUTPUT_QTZ (OUTPUT_COMPLEX2REAL_QTZ)
	) u_real_mul_1(
		.InputA(complex_in[0 +: (INPUT_COMPLEX_QTZ.width/2)]),
		.InputB(real_in),
		.OutputC(complex_out_imag)
	);

	assign complex_out = {complex_out_real, complex_out_imag};
endmodule