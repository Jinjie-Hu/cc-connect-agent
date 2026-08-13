`include "qtz_def.svh"

// Complex multiplier with selectable architecture
// FAST_MODE_EN == 0: 3-multiplication algorithm (Gauss method, saves 1 multiplier)
//                    All multiplications are performed inline using direct * operator.
// FAST_MODE_EN == 1: Direct 4-multiplication algorithm (faster critical path)
module complex_multiplier #(
	parameter qtz_t INPUT_A_QTZ  = DEFAULT_QTZ,
	parameter qtz_t INPUT_B_QTZ  = DEFAULT_QTZ,
	parameter qtz_t OUTPUT_QTZ   = DEFAULT_QTZ,
	parameter       FAST_MODE_EN = 0
) (
	input  [INPUT_A_QTZ.width-1:0] InputA,
	input  [INPUT_B_QTZ.width-1:0] InputB,
	output [OUTPUT_QTZ.width-1:0]  OutputC
);

	// ============================================================
	// Common parameter/quantization definitions
	// ============================================================
	localparam qtz_t IN_A_REAL_QTZ = get_qtz(INPUT_A_QTZ.sgn_w, INPUT_A_QTZ.int_w, INPUT_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_REAL_QTZ = get_qtz(INPUT_B_QTZ.sgn_w, INPUT_B_QTZ.int_w, INPUT_B_QTZ.fp_w, REAL);
	localparam qtz_t OUT_REAL_QTZ  = get_qtz(OUTPUT_QTZ.sgn_w, OUTPUT_QTZ.int_w, OUTPUT_QTZ.fp_w, REAL);

	// Common input splitting
	wire signed [IN_A_REAL_QTZ.width-1:0] InputA_r, InputA_i;
	wire signed [IN_B_REAL_QTZ.width-1:0] InputB_r, InputB_i;

	assign InputA_r = InputA[INPUT_A_QTZ.width-1 -: IN_A_REAL_QTZ.width];
	assign InputA_i = InputA[0 +: IN_A_REAL_QTZ.width];
	assign InputB_r = InputB[INPUT_B_QTZ.width-1 -: IN_B_REAL_QTZ.width];
	assign InputB_i = InputB[0 +: IN_B_REAL_QTZ.width];

	// Output real/imag (before recombine)
	wire signed [OUT_REAL_QTZ.width-1:0] OutputC_r;
	wire signed [OUT_REAL_QTZ.width-1:0] OutputC_i;

	// ============================================================
	// Architecture selection
	// ============================================================
	generate
		if (FAST_MODE_EN) begin : FAST_MODE
			// --------------------------------------------------------
			// Fast mode: direct 4-multiplication
			//   OutputC_r = A_r*B_r - A_i*B_i
			//   OutputC_i = A_i*B_r + A_r*B_i
			//
			// All bit widths are derived from the REAL quantization types
			// (IN_A_REAL_QTZ / IN_B_REAL_QTZ / OUT_REAL_QTZ) rather than
			// manually dividing complex widths, ensuring correct handling
			// regardless of dtype.
			// --------------------------------------------------------

			// Full-precision product width for one real multiplication
			localparam FULL_PROD_WIDTH = IN_A_REAL_QTZ.width + IN_B_REAL_QTZ.width;

			// Truncation parameters for output quantization
			localparam OUTPUT_OFFSET     = IN_A_REAL_QTZ.fp_w + IN_B_REAL_QTZ.fp_w - OUT_REAL_QTZ.fp_w;
			localparam OUTPUT_ZERO_EXPAND = OUTPUT_OFFSET > 0 ? 0: (-OUTPUT_OFFSET);
			localparam OUTPUT_OFFSET_REAL = OUTPUT_OFFSET > 0 ? OUTPUT_OFFSET : 0;
			localparam OUTPUT_BOUND = (OUTPUT_OFFSET + OUT_REAL_QTZ.width) > FULL_PROD_WIDTH ?
										FULL_PROD_WIDTH : (OUTPUT_OFFSET + OUT_REAL_QTZ.width);
			localparam OUTPUT_SGN_EXPAND = OUTPUT_BOUND - OUTPUT_OFFSET != OUT_REAL_QTZ.width ?
											OUT_REAL_QTZ.width - (OUTPUT_BOUND - OUTPUT_OFFSET) : 0;

			// Full-precision products before truncation
			wire signed [FULL_PROD_WIDTH-1:0] OutputC_r_full;
			wire signed [FULL_PROD_WIDTH-1:0] OutputC_i_full;

			// 4 multiplications (full precision)
			assign OutputC_r_full = InputA_r*InputB_r - InputA_i*InputB_i;
			assign OutputC_i_full = InputA_i*InputB_r + InputA_r*InputB_i;

			// Output truncate to target quantization
			assign OutputC_r = {{OUTPUT_SGN_EXPAND{OutputC_r_full[OUTPUT_BOUND-1]}},
								OutputC_r_full[OUTPUT_BOUND-1:OUTPUT_OFFSET_REAL],
								{OUTPUT_ZERO_EXPAND{1'b0}}};
			assign OutputC_i = {{OUTPUT_SGN_EXPAND{OutputC_i_full[OUTPUT_BOUND-1]}},
								OutputC_i_full[OUTPUT_BOUND-1:OUTPUT_OFFSET_REAL],
								{OUTPUT_ZERO_EXPAND{1'b0}}};

		end else begin : NORMAL_MODE
			// --------------------------------------------------------
			// Normal mode: 3-multiplication algorithm (Gauss method)
			//   x = A_r * (B_r + B_i)
			//   y = (A_r + A_i) * B_i
			//   z = (A_r - A_i) * B_r
			//   OutputC_r = x - y  (= A_r*B_r - A_i*B_i)
			//   OutputC_i = x - z  (= A_i*B_r + A_r*B_i)
			//
			// All multiplications are performed inline using direct
			// * operator (no external multiplier instantiation).
			// --------------------------------------------------------

			// Quantization for pre-add results (need 1 extra integer bit)
			localparam qtz_t IN_A_REALPLUS_QTZ = get_qtz(INPUT_A_QTZ.sgn_w, INPUT_A_QTZ.int_w + 1, INPUT_A_QTZ.fp_w, REAL);
			localparam qtz_t IN_B_REALPLUS_QTZ = get_qtz(INPUT_B_QTZ.sgn_w, INPUT_B_QTZ.int_w + 1, INPUT_B_QTZ.fp_w, REAL);

			// Full signed quantization for each multiplier operand
			// (following the same pattern as real_multiplier: force sgn_w=1, zero-extend)
			localparam qtz_t AR_FULL_QTZ  = get_qtz(1, IN_A_REAL_QTZ.int_w,      IN_A_REAL_QTZ.fp_w,      REAL);
			localparam qtz_t ARP_FULL_QTZ = get_qtz(1, IN_A_REALPLUS_QTZ.int_w, IN_A_REALPLUS_QTZ.fp_w, REAL);
			localparam qtz_t BR_FULL_QTZ  = get_qtz(1, IN_B_REAL_QTZ.int_w,      IN_B_REAL_QTZ.fp_w,      REAL);
			localparam qtz_t BRP_FULL_QTZ = get_qtz(1, IN_B_REALPLUS_QTZ.int_w, IN_B_REALPLUS_QTZ.fp_w, REAL);

			// Product full quantization: HSB truncated to OUT_REAL_QTZ.int_w
			localparam PROD_FP_W  = AR_FULL_QTZ.fp_w + BRP_FULL_QTZ.fp_w;  // = A.fp + B.fp
			localparam PROD_INT_W = OUT_REAL_QTZ.int_w;
			localparam qtz_t PROD_FULL_QTZ = get_qtz(1, PROD_INT_W, PROD_FP_W, REAL);

			// Pre-add/sub (carry needs 1 extra integer bit)
			wire signed [IN_A_REALPLUS_QTZ.width-1:0] A_r_sub_i, A_r_add_i;
			wire signed [IN_B_REALPLUS_QTZ.width-1:0] B_r_add_i;

			assign A_r_sub_i = InputA_r - InputA_i;
			assign A_r_add_i = InputA_r + InputA_i;
			assign B_r_add_i = InputB_r + InputB_i;

			// Extended operands (zero-extend to full signed width)
			wire signed [AR_FULL_QTZ.width-1:0]  InputA_r_ext;
			wire signed [ARP_FULL_QTZ.width-1:0] A_r_add_i_ext, A_r_sub_i_ext;
			wire signed [BRP_FULL_QTZ.width-1:0] B_r_add_i_ext;
			wire signed [BR_FULL_QTZ.width-1:0]  InputB_r_ext, InputB_i_ext;

			assign InputA_r_ext  = {{(AR_FULL_QTZ.width  - IN_A_REAL_QTZ.width)     {1'b0}}, InputA_r};
			assign InputB_r_ext  = {{(BR_FULL_QTZ.width  - IN_B_REAL_QTZ.width)     {1'b0}}, InputB_r};
			assign InputB_i_ext  = {{(BR_FULL_QTZ.width  - IN_B_REAL_QTZ.width)     {1'b0}}, InputB_i};
			assign A_r_add_i_ext = {{(ARP_FULL_QTZ.width - IN_A_REALPLUS_QTZ.width) {1'b0}}, A_r_add_i};
			assign A_r_sub_i_ext = {{(ARP_FULL_QTZ.width - IN_A_REALPLUS_QTZ.width) {1'b0}}, A_r_sub_i};
			assign B_r_add_i_ext = {{(BRP_FULL_QTZ.width - IN_B_REALPLUS_QTZ.width) {1'b0}}, B_r_add_i};

			// Inline multiplications with HSB-truncated products
			wire signed [PROD_FULL_QTZ.width-1:0] x_full, y_full, z_full;
			wire signed [OUT_REAL_QTZ.width-1:0]  x, y, z;

			assign x_full = InputA_r_ext  * B_r_add_i_ext;
			assign y_full = A_r_add_i_ext * InputB_i_ext;
			assign z_full = A_r_sub_i_ext * InputB_r_ext;

			assign x = `REAL_VALUE_TRANSFER(x_full, PROD_FULL_QTZ, OUT_REAL_QTZ);
			assign y = `REAL_VALUE_TRANSFER(y_full, PROD_FULL_QTZ, OUT_REAL_QTZ);
			assign z = `REAL_VALUE_TRANSFER(z_full, PROD_FULL_QTZ, OUT_REAL_QTZ);

			// Final combine
			assign OutputC_r = x - y;
			assign OutputC_i = x - z;
		end
	endgenerate

	// Recombine real and imag parts
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