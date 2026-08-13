`include "qtz_def.svh"

module real_adder #(
	parameter qtz_t INPUT_A_QTZ = 'b0,
	parameter qtz_t INPUT_B_QTZ = 'b0,
	parameter qtz_t OUTPUT_QTZ  = 'b0,
	parameter 		SUB_EN 		= 'b0
) (
	input  [INPUT_A_QTZ.width-1:0] InputA,
	input  [INPUT_B_QTZ.width-1:0] InputB,
	output [ OUTPUT_QTZ.width-1:0] OutputC
);
	localparam qtz_t IN_ALIGN_QTZ = get_qtz(INPUT_A_QTZ.sgn_w & INPUT_B_QTZ.sgn_w, `MAX(INPUT_A_QTZ.int_w, INPUT_B_QTZ.int_w), `MAX(INPUT_A_QTZ.fp_w, INPUT_B_QTZ.fp_w), REAL);
	localparam qtz_t OUT_FULL_QTZ = get_qtz(IN_ALIGN_QTZ.sgn_w, IN_ALIGN_QTZ.int_w + 1, IN_ALIGN_QTZ.fp_w, REAL);
	
	wire [IN_ALIGN_QTZ.width-1:0] InputA_align;
	wire [IN_ALIGN_QTZ.width-1:0] InputB_align;
	wire [OUT_FULL_QTZ.width-1:0] OutputC_full;

	// input align
	assign InputA_align = `REAL_VALUE_TRANSFER(InputA, INPUT_A_QTZ, IN_ALIGN_QTZ);
	assign InputB_align = `REAL_VALUE_TRANSFER(InputB, INPUT_B_QTZ, IN_ALIGN_QTZ);
	// adder do not care about the unsigned or signed
	assign OutputC_full = SUB_EN ? 
						  InputA_align - InputB_align:
						  InputA_align + InputB_align;
	// output assign
	assign OutputC = `REAL_VALUE_TRANSFER(OutputC_full, OUT_FULL_QTZ, OUTPUT_QTZ);
endmodule

// two port reused
// (1) OutputC1 = InputA1 + InputB1
// (2) OutputC2 = InputA2 + InputB2
// sw_i == 1'b0, choose (1)
// sw_i == 1'b1, choose (2)
/*
module real_adder_DP_reused #(
	parameter qtz_t INPUT_A1_QTZ = 'b0,
	parameter qtz_t INPUT_B1_QTZ = 'b0,
	parameter qtz_t OUTPUT1_QTZ  = 'b0,
	parameter qtz_t INPUT_A2_QTZ = 'b0,
	parameter qtz_t INPUT_B2_QTZ = 'b0,
	parameter qtz_t OUTPUT2_QTZ  = 'b0,
	parameter 		SUB_EN 		 = 'b0
) (
	// SW
	input 						    sw_i,
	
	// data
	input  [INPUT_A1_QTZ.width-1:0] InputA1,
	input  [INPUT_B1_QTZ.width-1:0] InputB1,
	output [OUTPUT1_QTZ.width -1:0] OutputC1,
	input  [INPUT_A2_QTZ.width-1:0] InputA2,
	input  [INPUT_B2_QTZ.width-1:0] InputB2,
	output [OUTPUT2_QTZ.width -1:0] OutputC2
);
	// input align width
	localparam IN1_ALIGH_FP_W  = `MAX(INPUT_A1_QTZ.fp_w , INPUT_B1_QTZ.fp_w);
	localparam IN1_ALIGH_INT_W = `MAX(INPUT_A1_QTZ.int_w, INPUT_B1_QTZ.int_w);
	localparam IN1_ALIGH_SGN_W = `MAX(INPUT_A1_QTZ.sgn_w, INPUT_B1_QTZ.sgn_w);	
	localparam IN1_ALIGH_WIDTH = IN1_ALIGH_SGN_W + IN1_ALIGH_FP_W + IN1_ALIGH_INT_W;
	
	localparam IN2_ALIGH_FP_W  = `MAX(INPUT_A2_QTZ.fp_w , INPUT_B2_QTZ.fp_w);
	localparam IN2_ALIGH_INT_W = `MAX(INPUT_A2_QTZ.int_w, INPUT_B2_QTZ.int_w);
	localparam IN2_ALIGH_SGN_W = `MAX(INPUT_A2_QTZ.sgn_w, INPUT_B2_QTZ.sgn_w);
	localparam IN2_ALIGH_WIDTH = IN2_ALIGH_SGN_W + IN2_ALIGH_FP_W + IN2_ALIGH_INT_W;
	
	localparam IN_ALIGH_WIDTH  = `MAX(IN1_ALIGH_WIDTH, IN2_ALIGH_WIDTH);
	
	// output_full width
	localparam OUT_FULL_WIDTH = IN_ALIGH_WIDTH + 1;
	
	// input align qtz with width IN_ALIGH_WIDTH
	localparam qtz_t IN1_ALIGN_QTZ = get_qtz(IN1_ALIGH_SGN_W, IN_ALIGH_WIDTH - IN1_ALIGH_SGN_W - IN1_ALIGH_FP_W, IN1_ALIGH_FP_W, REAL);
	localparam qtz_t IN2_ALIGN_QTZ = get_qtz(IN2_ALIGH_SGN_W, IN_ALIGH_WIDTH - IN2_ALIGH_SGN_W - IN2_ALIGH_FP_W, IN2_ALIGH_FP_W, REAL);

	// output_full qtz with width OUT_FULL_WIDTH
	localparam qtz_t OUT1_FULL_QTZ = get_qtz(IN1_ALIGH_SGN_W, OUT_FULL_WIDTH - IN1_ALIGH_SGN_W - IN1_ALIGH_FP_W, IN1_ALIGH_FP_W, IN1_ALIGH_FP_W, REAL);
	localparam qtz_t OUT2_FULL_QTZ = get_qtz(IN2_ALIGH_SGN_W, OUT_FULL_WIDTH - IN2_ALIGH_SGN_W - IN2_ALIGH_FP_W, IN2_ALIGH_FP_W, IN2_ALIGH_FP_W, REAL);
	
	// adder
	logic [IN_ALIGH_WIDTH-1:0] InputA_align, InputB_align;
	logic [OUT_FULL_WIDTH-1:0] OutputC_full;
	// adder do not care about the unsigned or signed
	assign OutputC_full = SUB_EN ? 
						  InputA_align - InputB_align:
						  InputA_align + InputB_align;
						  
	// input align
	logic [IN1_ALIGN_QTZ.width-1:0] InputA1_align;
	logic [IN1_ALIGN_QTZ.width-1:0] InputB1_align;
	logic [IN2_ALIGN_QTZ.width-1:0] InputA2_align;
	logic [IN2_ALIGN_QTZ.width-1:0] InputB2_align;
	
	assign InputA1_align = `REAL_VALUE_TRANSFER(InputA1, INPUT_A1_QTZ, IN1_ALIGN_QTZ);
	assign InputB1_align = `REAL_VALUE_TRANSFER(InputB1, INPUT_B1_QTZ, IN1_ALIGN_QTZ);
	assign InputA2_align = `REAL_VALUE_TRANSFER(InputA2, INPUT_A2_QTZ, IN2_ALIGN_QTZ);
	assign InputB2_align = `REAL_VALUE_TRANSFER(InputB2, INPUT_B2_QTZ, IN2_ALIGN_QTZ);
	
	// input switch
	assign InputA_align = sw_i ? InputA2_align : InputA1_align;
	assign InputB_align = sw_i ? InputB2_align : InputB1_align;
	
	// output assign
	assign OutputC1 = `REAL_VALUE_TRANSFER(OutputC_full, OUT1_FULL_QTZ, OUTPUT1_QTZ);
	assign OutputC2 = `REAL_VALUE_TRANSFER(OutputC_full, OUT2_FULL_QTZ, OUTPUT2_QTZ);
endmodule
*/