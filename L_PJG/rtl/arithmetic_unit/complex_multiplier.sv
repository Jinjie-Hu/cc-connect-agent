`include "qtz_def.svh"

module complex_multiplier_fast #(
	parameter qtz_t INPUT_A_QTZ = 'b0,
	parameter qtz_t INPUT_B_QTZ = 'b0,
	parameter qtz_t OUTPUT_QTZ  = 'b0
) (
	input  [INPUT_A_QTZ.width-1:0] InputA,
	input  [INPUT_B_QTZ.width-1:0] InputB,
	output [ OUTPUT_QTZ.width-1:0] OutputC
);

	localparam INPUT_A_BIT_WIDTH = INPUT_A_QTZ.width, INPUT_A_FP_WIDTH = INPUT_A_QTZ.fp_w;
	localparam INPUT_B_BIT_WIDTH = INPUT_B_QTZ.width, INPUT_B_FP_WIDTH = INPUT_B_QTZ.fp_w;
	localparam OUTPUT_BIT_WIDTH  = OUTPUT_QTZ.width, OUTPUT_FP_WIDTH  = OUTPUT_QTZ.fp_w;

	localparam INPUT_FULL_BIT_WIDTH = INPUT_A_BIT_WIDTH + INPUT_B_BIT_WIDTH;
	localparam OUTPUT_OFFSET = INPUT_A_FP_WIDTH + INPUT_B_FP_WIDTH - OUTPUT_FP_WIDTH;
	localparam OUTPUT_ZERO_EXPAND = OUTPUT_OFFSET > 0 ? 0: (-OUTPUT_OFFSET);
	localparam OUTPUT_OFFSET_REAL = OUTPUT_OFFSET > 0 ? OUTPUT_OFFSET : 0;
	localparam OUTPUT_BOUND = (OUTPUT_OFFSET+OUTPUT_BIT_WIDTH/2) > (INPUT_FULL_BIT_WIDTH/2) ? (INPUT_FULL_BIT_WIDTH/2) : (OUTPUT_OFFSET+OUTPUT_BIT_WIDTH/2);
	localparam OUTPUT_SGN_EXPAND = OUTPUT_BOUND - OUTPUT_OFFSET != OUTPUT_BIT_WIDTH/2 ? OUTPUT_BIT_WIDTH/2 - (OUTPUT_BOUND - OUTPUT_OFFSET) : 0;

	wire signed [INPUT_A_BIT_WIDTH/2-1:0] InputA_r;
	wire signed [INPUT_A_BIT_WIDTH/2-1:0] InputA_i;
	wire signed [INPUT_B_BIT_WIDTH/2-1:0] InputB_r;
	wire signed [INPUT_B_BIT_WIDTH/2-1:0] InputB_i;
	wire signed [INPUT_FULL_BIT_WIDTH/2-1:0] OutputC_r_full;
	wire signed [INPUT_FULL_BIT_WIDTH/2-1:0] OutputC_i_full;
	wire signed [OUTPUT_BIT_WIDTH/2-1:0] OutputC_r;
	wire signed [OUTPUT_BIT_WIDTH/2-1:0] OutputC_i;

	// get real part and image part
	assign InputA_r = InputA[INPUT_A_BIT_WIDTH-1:INPUT_A_BIT_WIDTH/2];
	assign InputA_i = InputA[INPUT_A_BIT_WIDTH/2-1:0];
	assign InputB_r = InputB[INPUT_B_BIT_WIDTH-1:INPUT_B_BIT_WIDTH/2];
	assign InputB_i = InputB[INPUT_B_BIT_WIDTH/2-1:0];
	// multiplier
	assign OutputC_r_full = InputA_r*InputB_r - InputA_i*InputB_i;
	assign OutputC_i_full = InputA_i*InputB_r + InputA_r*InputB_i;
	// output truncate
	assign OutputC_r = {{OUTPUT_SGN_EXPAND{OutputC_r_full[OUTPUT_BOUND-1]}}, OutputC_r_full[OUTPUT_BOUND-1:OUTPUT_OFFSET_REAL], {OUTPUT_ZERO_EXPAND{1'b0}}};
	assign OutputC_i = {{OUTPUT_SGN_EXPAND{OutputC_i_full[OUTPUT_BOUND-1]}}, OutputC_i_full[OUTPUT_BOUND-1:OUTPUT_OFFSET_REAL], {OUTPUT_ZERO_EXPAND{1'b0}}};
	// output
	assign OutputC = {OutputC_r, OutputC_i};
endmodule

// Caution: if OutputC has precision loss (i.e., OUTPUT_QTZ.width < A.width + B.width),
//			switch InputA and InputB will cause different OutputC (usually differ by 1).
//			So please care about the InputA-InputB sequence.
module complex_multiplier #(
	parameter qtz_t INPUT_A_QTZ = 'b0,
	parameter qtz_t INPUT_B_QTZ = 'b0,
	parameter qtz_t OUTPUT_QTZ  = 'b0
) (
	input  [INPUT_A_QTZ.width-1:0] InputA,
	input  [INPUT_B_QTZ.width-1:0] InputB,
	output [ OUTPUT_QTZ.width-1:0] OutputC
);
	localparam qtz_t IN_A_REALPLUS_QTZ = get_qtz(INPUT_A_QTZ.sgn_w, INPUT_A_QTZ.int_w + 1, INPUT_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_REALPLUS_QTZ = get_qtz(INPUT_B_QTZ.sgn_w, INPUT_B_QTZ.int_w + 1, INPUT_B_QTZ.fp_w, REAL);
	localparam qtz_t IN_A_REAL_QTZ = get_qtz(INPUT_A_QTZ.sgn_w, INPUT_A_QTZ.int_w, INPUT_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_REAL_QTZ = get_qtz(INPUT_B_QTZ.sgn_w, INPUT_B_QTZ.int_w, INPUT_B_QTZ.fp_w, REAL);
	localparam qtz_t OUT_REAL_QTZ  = get_qtz(OUTPUT_QTZ.sgn_w, OUTPUT_QTZ.int_w, OUTPUT_QTZ.fp_w, REAL);

	wire signed [INPUT_A_QTZ.width/2-1:0] InputA_r, InputA_i;
	wire signed [IN_A_REALPLUS_QTZ.width-1:0] A_r_sub_i, A_r_add_i;
	wire signed [INPUT_B_QTZ.width/2-1:0] InputB_r, InputB_i;
	wire signed [IN_B_REALPLUS_QTZ.width-1:0] B_r_add_i;

	wire signed [OUT_REAL_QTZ.width-1:0] x;
	wire signed [OUT_REAL_QTZ.width-1:0] y;
	wire signed [OUT_REAL_QTZ.width-1:0] z;
	wire signed [OUT_REAL_QTZ.width-1:0] OutputC_r;
	wire signed [OUT_REAL_QTZ.width-1:0] OutputC_i;

	// get real part and image part
	assign InputA_r = InputA[INPUT_A_QTZ.width-1 -: IN_A_REAL_QTZ.width];
	assign InputA_i = InputA[0 +: IN_A_REAL_QTZ.width];
	assign InputB_r = InputB[INPUT_B_QTZ.width-1 -: IN_B_REAL_QTZ.width];
	assign InputB_i = InputB[0 +: IN_B_REAL_QTZ.width];
	// multiplier
	assign A_r_sub_i = InputA_r - InputA_i;
	assign B_r_add_i = InputB_r + InputB_i;
	assign A_r_add_i = InputA_r + InputA_i;

	real_multiplier #(
		.INPUT_A_QTZ(IN_A_REAL_QTZ),
		.INPUT_B_QTZ(IN_B_REALPLUS_QTZ),
		.OUTPUT_QTZ (OUT_REAL_QTZ)
	) u_real_mul_x(
		.InputA(InputA_r),
		.InputB(B_r_add_i),
		.OutputC(x)
	);

	real_multiplier #(
		.INPUT_A_QTZ(IN_A_REALPLUS_QTZ),
		.INPUT_B_QTZ(IN_B_REAL_QTZ),
		.OUTPUT_QTZ (OUT_REAL_QTZ)
	) u_real_mul_y(
		.InputA(A_r_add_i),
		.InputB(InputB_i),
		.OutputC(y)
	);

	real_multiplier #(
		.INPUT_A_QTZ(IN_A_REALPLUS_QTZ),
		.INPUT_B_QTZ(IN_B_REAL_QTZ),
		.OUTPUT_QTZ (OUT_REAL_QTZ)
	) u_real_mul_z(
		.InputA(A_r_sub_i),
		.InputB(InputB_r),
		.OutputC(z)
	);

	assign OutputC_r = x - y;
	assign OutputC_i = x - z;
	// output
	assign OutputC = {OutputC_r, OutputC_i};
endmodule

module complex_multiplier_using_fp(InputA, InputB, OutputC);
	parameter qtz_t INPUT_A_QTZ = 'b0;
	parameter qtz_t INPUT_B_QTZ = 'b0;
	parameter qtz_t OUTPUT_QTZ  = 'b0;
	parameter SIG_WIDTH = 10;
	parameter EXP_WIDTH = 5;

	localparam qtz_t A_REAL_QTZ = get_qtz(INPUT_A_QTZ.sgn_w, INPUT_A_QTZ.int_w, INPUT_A_QTZ.fp_w, REAL);
	localparam qtz_t B_REAL_QTZ = get_qtz(INPUT_B_QTZ.sgn_w, INPUT_B_QTZ.int_w, INPUT_B_QTZ.fp_w, REAL);
	localparam qtz_t OUT_REAL_QTZ = get_qtz(OUTPUT_QTZ.sgn_w, OUTPUT_QTZ.int_w, OUTPUT_QTZ.fp_w, REAL);

	localparam INPUT_A_BIT_WIDTH = INPUT_A_QTZ.width, INPUT_A_FP_WIDTH = INPUT_A_QTZ.fp_w;
	localparam INPUT_B_BIT_WIDTH = INPUT_B_QTZ.width, INPUT_B_FP_WIDTH = INPUT_B_QTZ.fp_w;
	localparam OUTPUT_BIT_WIDTH  = OUTPUT_QTZ.width, OUTPUT_FP_WIDTH  = OUTPUT_QTZ.fp_w;

	localparam INPUT_FULL_BIT_WIDTH = INPUT_A_BIT_WIDTH + INPUT_B_BIT_WIDTH;
	localparam OUTPUT_OFFSET = INPUT_A_FP_WIDTH + INPUT_B_FP_WIDTH - OUTPUT_FP_WIDTH;
	localparam OUTPUT_ZERO_EXPAND = OUTPUT_OFFSET > 0 ? 0: (-OUTPUT_OFFSET);
	localparam OUTPUT_OFFSET_REAL = OUTPUT_OFFSET > 0 ? OUTPUT_OFFSET : 0;
	localparam OUTPUT_BOUND = (OUTPUT_OFFSET+OUTPUT_BIT_WIDTH/2) > (INPUT_FULL_BIT_WIDTH/2) ? (INPUT_FULL_BIT_WIDTH/2) : (OUTPUT_OFFSET+OUTPUT_BIT_WIDTH/2);
	localparam OUTPUT_SGN_EXPAND = OUTPUT_BOUND - OUTPUT_OFFSET != OUTPUT_BIT_WIDTH/2 ? OUTPUT_BIT_WIDTH/2 - (OUTPUT_BOUND - OUTPUT_OFFSET) : 0;

	input  wire [INPUT_A_BIT_WIDTH-1:0] InputA;
	input  wire [INPUT_B_BIT_WIDTH-1:0] InputB;
	output wire [OUTPUT_BIT_WIDTH-1:0] OutputC;

	wire signed [INPUT_A_BIT_WIDTH/2-1:0] InputA_r, A_r_sub_i, A_r_add_i;
	wire signed [INPUT_A_BIT_WIDTH/2-1:0] InputA_i;
	wire signed [INPUT_B_BIT_WIDTH/2-1:0] InputB_r, B_r_add_i;
	wire signed [INPUT_B_BIT_WIDTH/2-1:0] InputB_i;
	wire signed [OUT_REAL_QTZ.width-1:0] x;
	wire signed [OUT_REAL_QTZ.width-1:0] y;
	wire signed [OUT_REAL_QTZ.width-1:0] z;
	wire signed [OUTPUT_BIT_WIDTH/2-1:0] OutputC_r;
	wire signed [OUTPUT_BIT_WIDTH/2-1:0] OutputC_i;

	// get real part and image part
	assign InputA_r = InputA[INPUT_A_BIT_WIDTH-1:INPUT_A_BIT_WIDTH/2];
	assign InputA_i = InputA[INPUT_A_BIT_WIDTH/2-1:0];
	assign InputB_r = InputB[INPUT_B_BIT_WIDTH-1:INPUT_B_BIT_WIDTH/2];
	assign InputB_i = InputB[INPUT_B_BIT_WIDTH/2-1:0];
	// multiplier
	assign A_r_sub_i = InputA_r - InputA_i;
	assign B_r_add_i = InputB_r + InputB_i;
	assign A_r_add_i = InputA_r + InputA_i;

	real_multiplier_using_fp #(
		.INPUT_A_QTZ(A_REAL_QTZ),
		.INPUT_B_QTZ(B_REAL_QTZ),
		.OUTPUT_QTZ(OUT_REAL_QTZ),
		.SIG_WIDTH(SIG_WIDTH),
		.EXP_WIDTH(EXP_WIDTH)
	) x_multiplier (
		.InputA(InputA_r),
		.InputB(B_r_add_i),
		.OutputC(x)
	);

	real_multiplier_using_fp #(
		.INPUT_A_QTZ(B_REAL_QTZ),
		.INPUT_B_QTZ(A_REAL_QTZ),
		.OUTPUT_QTZ(OUT_REAL_QTZ),
		.SIG_WIDTH(SIG_WIDTH),
		.EXP_WIDTH(EXP_WIDTH)
	) y_multiplier (
		.InputA(InputB_i),
		.InputB(A_r_add_i),
		.OutputC(y)
	);

	real_multiplier_using_fp #(
		.INPUT_A_QTZ(B_REAL_QTZ),
		.INPUT_B_QTZ(A_REAL_QTZ),
		.OUTPUT_QTZ(OUT_REAL_QTZ),
		.SIG_WIDTH(SIG_WIDTH),
		.EXP_WIDTH(EXP_WIDTH)
	) z_multiplier (
		.InputA(InputB_r),
		.InputB(A_r_sub_i),
		.OutputC(z)
	);

	// output truncate
	assign OutputC_r = x - y;
	assign OutputC_i = x - z;
	// output
	assign OutputC = {OutputC_r, OutputC_i};
endmodule

// two port reused
// (1) OutputC1 = InputA1 * InputB1
// (2) OutputC2 = InputA2 * InputB2
// sw_i == 1'b0, choose (1)
// sw_i == 1'b1, choose (2)
// Caution: if OutputC has precision loss (i.e., OUTPUT_QTZ.width < A.width + B.width),
//			switch InputA and InputB will cause different OutputC (usually differ by 1).
//			So please care about the InputA-InputB sequence.
/*
module complex_multiplier_DP_reused #(
	parameter qtz_t INPUT_A1_QTZ = 'b0,
	parameter qtz_t INPUT_B1_QTZ = 'b0,
	parameter qtz_t OUTPUT1_QTZ  = 'b0,
	parameter qtz_t INPUT_A2_QTZ = 'b0,
	parameter qtz_t INPUT_B2_QTZ = 'b0,
	parameter qtz_t OUTPUT2_QTZ  = 'b0
) (
	// SW
	input 						   sw_i,
	
	// data
	input  [INPUT_A1_QTZ.width-1:0] InputA1,
	input  [INPUT_B1_QTZ.width-1:0] InputB1,
	output [OUTPUT1_QTZ.width -1:0] OutputC1,
	input  [INPUT_A2_QTZ.width-1:0] InputA2,
	input  [INPUT_B2_QTZ.width-1:0] InputB2,
	output [OUTPUT2_QTZ.width -1:0] OutputC2
);
	localparam qtz_t IN_A_REALPLUS_QTZ = get_qtz(INPUT_A_QTZ.sgn_w, INPUT_A_QTZ.int_w + 1, INPUT_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_REALPLUS_QTZ = get_qtz(INPUT_B_QTZ.sgn_w, INPUT_B_QTZ.int_w + 1, INPUT_B_QTZ.fp_w, REAL);
	localparam qtz_t IN_A_REAL_QTZ = get_qtz(INPUT_A_QTZ.sgn_w, INPUT_A_QTZ.int_w, INPUT_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_REAL_QTZ = get_qtz(INPUT_B_QTZ.sgn_w, INPUT_B_QTZ.int_w, INPUT_B_QTZ.fp_w, REAL);
	localparam qtz_t OUT_REAL_QTZ  = get_qtz(OUTPUT_QTZ.sgn_w, OUTPUT_QTZ.int_w, OUTPUT_QTZ.fp_w, REAL);

	wire signed [INPUT_A_QTZ.width/2-1:0] InputA_r, InputA_i;
	wire signed [IN_A_REALPLUS_QTZ.width-1:0] A_r_sub_i, A_r_add_i;
	wire signed [INPUT_B_QTZ.width/2-1:0] InputB_r, InputB_i;
	wire signed [IN_B_REALPLUS_QTZ.width-1:0] B_r_add_i;

	wire signed [OUT_REAL_QTZ.width-1:0] x;
	wire signed [OUT_REAL_QTZ.width-1:0] y;
	wire signed [OUT_REAL_QTZ.width-1:0] z;
	wire signed [OUT_REAL_QTZ.width-1:0] OutputC_r;
	wire signed [OUT_REAL_QTZ.width-1:0] OutputC_i;

	// get real part and image part
	assign InputA_r = InputA[INPUT_A_QTZ.width-1 -: IN_A_REAL_QTZ.width];
	assign InputA_i = InputA[0 +: IN_A_REAL_QTZ.width];
	assign InputB_r = InputB[INPUT_B_QTZ.width-1 -: IN_B_REAL_QTZ.width];
	assign InputB_i = InputB[0 +: IN_B_REAL_QTZ.width];
	// multiplier
	assign A_r_sub_i = InputA_r - InputA_i;
	assign B_r_add_i = InputB_r + InputB_i;
	assign A_r_add_i = InputA_r + InputA_i;

	real_multiplier #(
		.INPUT_A_QTZ(IN_A_REAL_QTZ),
		.INPUT_B_QTZ(IN_B_REALPLUS_QTZ),
		.OUTPUT_QTZ (OUT_REAL_QTZ)
	) u_real_mul_x(
		.InputA(InputA_r),
		.InputB(B_r_add_i),
		.OutputC(x)
	);

	real_multiplier #(
		.INPUT_A_QTZ(IN_A_REALPLUS_QTZ),
		.INPUT_B_QTZ(IN_B_REAL_QTZ),
		.OUTPUT_QTZ (OUT_REAL_QTZ)
	) u_real_mul_y(
		.InputA(A_r_add_i),
		.InputB(InputB_i),
		.OutputC(y)
	);

	real_multiplier #(
		.INPUT_A_QTZ(IN_A_REALPLUS_QTZ),
		.INPUT_B_QTZ(IN_B_REAL_QTZ),
		.OUTPUT_QTZ (OUT_REAL_QTZ)
	) u_real_mul_z(
		.InputA(A_r_sub_i),
		.InputB(InputB_r),
		.OutputC(z)
	);

	assign OutputC_r = x - y;
	assign OutputC_i = x - z;
	// output
	assign OutputC = {OutputC_r, OutputC_i};
endmodule
*/