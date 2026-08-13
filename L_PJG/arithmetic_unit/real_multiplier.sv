`include "qtz_def.svh"

module real_multiplier #(
	parameter qtz_t INPUT_A_QTZ = 'b0,
	parameter qtz_t INPUT_B_QTZ = 'b0,
	parameter qtz_t OUTPUT_QTZ  = 'b0
) (
	input  [INPUT_A_QTZ.width-1:0] InputA,
	input  [INPUT_B_QTZ.width-1:0] InputB,
	output [OUTPUT_QTZ.width -1:0] OutputC
);

	localparam qtz_t IN_A_FULL_QTZ = get_qtz(1, INPUT_A_QTZ.int_w, INPUT_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_FULL_QTZ = get_qtz(1, INPUT_B_QTZ.int_w, INPUT_B_QTZ.fp_w, REAL);
	
	wire signed [IN_A_FULL_QTZ.width-1:0] InputA_full;
	wire signed [IN_B_FULL_QTZ.width-1:0] InputB_full;

	assign InputA_full = {{(IN_A_FULL_QTZ.width - INPUT_A_QTZ.width){1'b0}}, InputA};
	assign InputB_full = {{(IN_B_FULL_QTZ.width - INPUT_B_QTZ.width){1'b0}}, InputB};

	localparam OUT_FULL_FP_W = IN_A_FULL_QTZ.fp_w + IN_B_FULL_QTZ.fp_w;
	// directly truncate the HSB to speed up the synthesis step
	localparam OUT_FULL_INT_W = OUTPUT_QTZ.int_w;
	localparam qtz_t OUT_FULL_QTZ = get_qtz(1, OUT_FULL_INT_W, OUT_FULL_FP_W, REAL);
	wire signed [OUT_FULL_QTZ.width-1:0] OutputC_full;

	// signed multiplier
	assign OutputC_full = InputA_full * InputB_full;

	// output truncate
	assign OutputC = `REAL_VALUE_TRANSFER(OutputC_full, OUT_FULL_QTZ, OUTPUT_QTZ);
endmodule


module real_multiplier_using_fp(InputA, InputB, OutputC);
	parameter qtz_t INPUT_A_QTZ = get_qtz(1, 9, 13, REAL);
	parameter qtz_t INPUT_B_QTZ = get_qtz(1, 9, 13, REAL);
	parameter qtz_t OUTPUT_QTZ = get_qtz(1, 13, 13, REAL);
	parameter SIG_WIDTH = 10;
	parameter EXP_WIDTH = 5;

	localparam INPUT_A_BIT_WIDTH = INPUT_A_QTZ.width, INPUT_A_FP_WIDTH = INPUT_A_QTZ.fp_w;
	localparam INPUT_B_BIT_WIDTH = INPUT_B_QTZ.width, INPUT_B_FP_WIDTH = INPUT_B_QTZ.fp_w;
	localparam OUTPUT_BIT_WIDTH  = OUTPUT_QTZ.width, OUTPUT_FP_WIDTH  = OUTPUT_QTZ.fp_w;

	localparam INPUT_FULL_BIT_WIDTH = INPUT_A_BIT_WIDTH + INPUT_B_BIT_WIDTH;
	localparam OUTPUT_OFFSET = INPUT_A_FP_WIDTH + INPUT_B_FP_WIDTH - OUTPUT_FP_WIDTH;
	localparam OUTPUT_ZERO_EXPAND = OUTPUT_OFFSET > 0 ? 0: (-OUTPUT_OFFSET);
	localparam OUTPUT_OFFSET_REAL = OUTPUT_OFFSET > 0 ? OUTPUT_OFFSET : 0;
	localparam OUTPUT_BOUND = (OUTPUT_OFFSET+OUTPUT_BIT_WIDTH) > (INPUT_FULL_BIT_WIDTH) ? (INPUT_FULL_BIT_WIDTH) : (OUTPUT_OFFSET+OUTPUT_BIT_WIDTH);
	localparam OUTPUT_SGN_EXPAND = OUTPUT_BOUND - OUTPUT_OFFSET != OUTPUT_BIT_WIDTH ? OUTPUT_BIT_WIDTH - (OUTPUT_BOUND - OUTPUT_OFFSET) : 0;


	input  wire signed [INPUT_A_BIT_WIDTH-1:0] InputA;
	input  wire signed [INPUT_B_BIT_WIDTH-1:0] InputB;
	output wire signed [OUTPUT_BIT_WIDTH-1:0] OutputC;

	wire signed [INPUT_FULL_BIT_WIDTH-1:0] OutputC_full;

	// fixed point to float point
	wire [SIG_WIDTH-1:0] A_sig, B_sig, C_sig;
	wire [EXP_WIDTH-1:0] A_exp, B_exp, C_exp;
	// wire [SIG_WIDTH+EXP_WIDTH:0] A_fp, B_fp, C_fp;
	// assign A_fp = {InputA[INPUT_A_QTZ.width-1], A_exp, A_sig};

	wire [INPUT_A_QTZ.width-SIG_WIDTH-2:0] A_sw;
	wire [INPUT_B_QTZ.width-SIG_WIDTH-2:0] B_sw;
	wire [SIG_WIDTH-1:0] A_sig_mux[INPUT_A_QTZ.width-SIG_WIDTH-2:0];
	wire [EXP_WIDTH-1:0] A_exp_mux[INPUT_A_QTZ.width-SIG_WIDTH-2:0];
	wire [SIG_WIDTH-1:0] B_sig_mux[INPUT_B_QTZ.width-SIG_WIDTH-2:0];
	wire [EXP_WIDTH-1:0] B_exp_mux[INPUT_B_QTZ.width-SIG_WIDTH-2:0];
	
	generate
		for (genvar i = INPUT_A_QTZ.width-SIG_WIDTH-2; i >= 0; i = i - 1) begin : A_FIX2FLOAT
			assign A_sw[i] = InputA[i + SIG_WIDTH + 1] ^ InputA[i + SIG_WIDTH];
			assign A_sig_mux[i] = A_sw[i] ? InputA[i + SIG_WIDTH -: SIG_WIDTH] :
				   (i != 0 ? A_sig_mux[i-1] : InputA[0 +: SIG_WIDTH]);
			assign A_exp_mux[i] = A_sw[i] ? i + 1:
				   (i != 0 ? A_exp_mux[i-1] : 'b0);
		end

		for (genvar i = INPUT_B_QTZ.width-SIG_WIDTH-2; i >= 0; i = i - 1) begin : B_FIX2FLOAT
			assign B_sw[i] = InputB[i + SIG_WIDTH + 1] ^ InputB[i + SIG_WIDTH];
			assign B_sig_mux[i] = B_sw[i] ? InputB[i + SIG_WIDTH -: SIG_WIDTH] :
				   (i != 0 ? B_sig_mux[i-1] : InputB[0 +: SIG_WIDTH]);
			assign B_exp_mux[i] = B_sw[i] ? i + 1:
				   (i != 0 ? B_exp_mux[i-1] : 'b0);
		end
	endgenerate

	assign A_sig = A_sig_mux[INPUT_A_QTZ.width-SIG_WIDTH-2];
	assign A_exp = A_exp_mux[INPUT_A_QTZ.width-SIG_WIDTH-2];
	assign B_sig = B_sig_mux[INPUT_B_QTZ.width-SIG_WIDTH-2];
	assign B_exp = B_exp_mux[INPUT_B_QTZ.width-SIG_WIDTH-2];

	// multiplier
	logic signed [2*SIG_WIDTH+1:0] C_sig_part;
	logic unsigned [EXP_WIDTH-1:0] C_exp_part;
	assign C_sig_part = signed'({InputA[INPUT_A_QTZ.width-1], A_sig}) * signed'({InputB[INPUT_B_QTZ.width-1], B_sig});
	assign C_exp_part = unsigned'(A_exp) + unsigned'(B_exp);

	// DW_fp_mult fp_mult #(
	// 	.sig_width(SIG_WIDTH),
	// 	.exe_width(EXP_WIDTH),
	// 	.ieee_compliance(1)
	// ) (.a(A_fp), .b(B_fp), .rnd(3'b000), .z(C_fp), .status());

	// float point to fixed point
	assign OutputC_full = C_sig_part << C_exp_part;
	// output truncate
	assign OutputC = {{OUTPUT_SGN_EXPAND{OutputC_full[OUTPUT_BOUND-1]}}, OutputC_full[OUTPUT_BOUND-1:OUTPUT_OFFSET_REAL], {OUTPUT_ZERO_EXPAND{1'b0}}};
endmodule

// two port reused
// (1) OutputC1 = InputA1 * InputB1
// (2) OutputC2 = InputA2 * InputB2
// sw_i == 1'b0, choose (1)
// sw_i == 1'b1, choose (2)
/*
module real_multiplier_DP_reused #(
	parameter qtz_t INPUT_A1_QTZ = 'b0,
	parameter qtz_t INPUT_B1_QTZ = 'b0,
	parameter qtz_t INPUT_A2_QTZ = 'b0,
	parameter qtz_t INPUT_B2_QTZ = 'b0,
	parameter qtz_t OUTPUT1_QTZ  = 'b0,
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
	// input width with sgn bit
	localparam IN_A1_SGN_W = 1 + INPUT_A1_QTZ.int_w + INPUT_A1_QTZ.fp_w;
	localparam IN_A2_SGN_W = 1 + INPUT_A2_QTZ.int_w + INPUT_A2_QTZ.fp_w;
	localparam IN_B1_SGN_W = 1 + INPUT_B1_QTZ.int_w + INPUT_B1_QTZ.fp_w;
	localparam IN_B2_SGN_W = 1 + INPUT_B2_QTZ.int_w + INPUT_B2_QTZ.fp_w;
	
	// mul. input width
	localparam IN_A_WIDTH = `MAX(IN_A1_SGN_W, IN_A2_SGN_W);
	localparam IN_B_WIDTH = `MAX(IN_B1_SGN_W, IN_B2_SGN_W);
	
	// input_full QTZ setting
	localparam qtz_t IN_A1_FULL_QTZ = get_qtz(1, IN_A_WIDTH - 1 - INPUT_A1_QTZ.fp_w, INPUT_A1_QTZ.fp_w, REAL);
	localparam qtz_t IN_B1_FULL_QTZ = get_qtz(1, IN_B_WIDTH - 1 - INPUT_B1_QTZ.fp_w, INPUT_B1_QTZ.fp_w, REAL);
	localparam qtz_t IN_A2_FULL_QTZ = get_qtz(1, IN_A_WIDTH - 1 - INPUT_A2_QTZ.fp_w, INPUT_A2_QTZ.fp_w, REAL);
	localparam qtz_t IN_B2_FULL_QTZ = get_qtz(1, IN_B_WIDTH - 1 - INPUT_B2_QTZ.fp_w, INPUT_B2_QTZ.fp_w, REAL);
	
	// mul. output width
	// calculate the truncation of OUT1 and OUT2's HSB width
	// directly truncate the HSB to speed up the synthesis step
	localparam OUT1_TRUNC_WIDTH = IN_A1_FULL_QTZ.int_w + IN_B1_FULL_QTZ.int_w + 2 - ( OUTPUT1_QTZ.sgn_w + OUTPUT1_QTZ.int_w );
	localparam OUT2_TRUNC_WIDTH = IN_A2_FULL_QTZ.int_w + IN_B2_FULL_QTZ.int_w + 2 - ( OUTPUT2_QTZ.sgn_w + OUTPUT2_QTZ.int_w );
	localparam OUT_FULL_WIDTH  = IN_A_WIDTH + IN_B_WIDTH - `MIN(OUT1_TRUNC_WIDTH, OUT2_TRUNC_WIDTH);
	
	// output_full QTZ setting
	localparam OUT1_FULL_FP_W  = IN_A1_FULL_QTZ.fp_w + IN_B1_FULL_QTZ.fp_w;
	localparam OUT1_FULL_INT_W = OUT_FULL_WIDTH - 1 - OUT1_FULL_FP_W;
	localparam qtz_t OUT1_FULL_QTZ = get_qtz(1, OUT_FULL_INT_W, OUT_FULL_FP_W, REAL);
	
	localparam OUT2_FULL_FP_W  = IN_A2_FULL_QTZ.fp_w + IN_B2_FULL_QTZ.fp_w;
	localparam OUT2_FULL_INT_W = OUT_FULL_WIDTH - 1 - OUT2_FULL_FP_W;
	localparam qtz_t OUT2_FULL_QTZ = get_qtz(1, OUT_FULL_INT_W, OUT_FULL_FP_W, REAL);
	
	// signed multiplier
	logic signed [IN_A_WIDTH-1:0] A;
	logic signed [IN_B_WIDTH-1:0] B;
	logic signed [OUT_FULL_WIDTH-1:0] OutputC_full;
	assign OutputC_full = A * B;
		
	// input_full assignment
	wire signed [IN_A1_FULL_QTZ.width-1:0] InputA1_full;
	wire signed [IN_B1_FULL_QTZ.width-1:0] InputB1_full;
	wire signed [IN_A2_FULL_QTZ.width-1:0] InputA2_full;
	wire signed [IN_B2_FULL_QTZ.width-1:0] InputB2_full;
	assign InputA1_full = `REAL_VALUE_TRANSFER(InputA1, INPUT_A1_QTZ, IN_A1_FULL_QTZ);
	assign InputB1_full = `REAL_VALUE_TRANSFER(InputB1, INPUT_B1_QTZ, IN_B1_FULL_QTZ);
	assign InputA2_full = `REAL_VALUE_TRANSFER(InputA2, INPUT_A2_QTZ, IN_A2_FULL_QTZ);
	assign InputB2_full = `REAL_VALUE_TRANSFER(InputB2, INPUT_B2_QTZ, IN_B2_FULL_QTZ);
	
	// input SW
	assign A = sw_i ? InputA2_full : InputA1_full;
	assign B = sw_i ? InputB2_full : InputB1_full;

	// output truncate
	assign OutputC1 = `REAL_VALUE_TRANSFER(OutputC_full, OUT1_FULL_QTZ, OUTPUT1_QTZ);
	assign OutputC2 = `REAL_VALUE_TRANSFER(OutputC_full, OUT2_FULL_QTZ, OUTPUT2_QTZ);
endmodule
*/