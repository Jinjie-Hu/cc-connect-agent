`include "qtz_def.svh"

// Multiply-Accumulate (MAC) module with bias
// Computes: OutputC = InputC + sum_{i=0}^{MUL_IN_PAIR_NUM-1} (InputA[i] * InputB[i])
// All operations (multiply & accumulate) are performed directly using
// native * and + operators for synthesis optimization.
// Each input's extension mode is determined by its quantization sgn_w:
//   sgn_w == 1 -> sign-extension (signed input)
//   sgn_w == 0 -> zero-extension (unsigned input)
module real_mac_w_bias #(
	parameter qtz_t MUL_IN_A_QTZ  = DEFAULT_QTZ,
	parameter qtz_t MUL_IN_B_QTZ  = DEFAULT_QTZ,
	parameter qtz_t INPUT_C_QTZ   = DEFAULT_QTZ,
	parameter qtz_t OUTPUT_QTZ    = DEFAULT_QTZ,
    parameter       MUL_IN_PAIR_NUM = 2
) (
	input  [MUL_IN_A_QTZ.width-1:0] InputA [MUL_IN_PAIR_NUM-1:0],
	input  [MUL_IN_B_QTZ.width-1:0] InputB [MUL_IN_PAIR_NUM-1:0],
	input  [INPUT_C_QTZ.width-1:0]  InputC,
	output [OUTPUT_QTZ.width-1:0]   OutputC
);
    // Extend inputs to full signed width for multiplication
    // IN_A_FULL_QTZ always has sgn_w=1; the extension bits are filled
    // according to MUL_IN_A_QTZ.sgn_w.
    localparam qtz_t IN_A_FULL_QTZ = get_qtz(1, MUL_IN_A_QTZ.int_w, MUL_IN_A_QTZ.fp_w, REAL);
    localparam qtz_t IN_B_FULL_QTZ = get_qtz(1, MUL_IN_B_QTZ.int_w, MUL_IN_B_QTZ.fp_w, REAL);

    // Full-precision product quantization (before accumulation)
    localparam PROD_FP_W  = IN_A_FULL_QTZ.fp_w + IN_B_FULL_QTZ.fp_w;
    localparam PROD_INT_W = IN_A_FULL_QTZ.int_w + IN_B_FULL_QTZ.int_w + 1;  // +1 for signed mult sign bit
    localparam qtz_t PROD_FULL_QTZ = get_qtz(1, PROD_INT_W, PROD_FP_W, REAL);

    // Accumulator quantization: extra guard bits for summing MUL_IN_PAIR_NUM products
    localparam ACC_EXTRA_BITS = $clog2(MUL_IN_PAIR_NUM);
    localparam ACC_INT_W = PROD_INT_W + ACC_EXTRA_BITS;
    localparam qtz_t ACC_QTZ = get_qtz(1, ACC_INT_W, PROD_FP_W, REAL);

    // Extended inputs (sign/zero-extended to full width based on sgn_w)
    wire signed [IN_A_FULL_QTZ.width-1:0] InputA_full [MUL_IN_PAIR_NUM-1:0];
    wire signed [IN_B_FULL_QTZ.width-1:0] InputB_full [MUL_IN_PAIR_NUM-1:0];

    genvar i;
    generate
        for (i = 0; i < MUL_IN_PAIR_NUM; i = i + 1) begin : GEN_INPUT_EXTEND
            assign InputA_full[i] = MUL_IN_A_QTZ.sgn_w ?
                {{(IN_A_FULL_QTZ.width - MUL_IN_A_QTZ.width){InputA[i][MUL_IN_A_QTZ.width-1]}}, InputA[i]} :
                {{(IN_A_FULL_QTZ.width - MUL_IN_A_QTZ.width){1'b0}}, InputA[i]};
            assign InputB_full[i] = MUL_IN_B_QTZ.sgn_w ?
                {{(IN_B_FULL_QTZ.width - MUL_IN_B_QTZ.width){InputB[i][MUL_IN_B_QTZ.width-1]}}, InputB[i]} :
                {{(IN_B_FULL_QTZ.width - MUL_IN_B_QTZ.width){1'b0}}, InputB[i]};
        end
    endgenerate

    // Bias input extended to accumulator width (REAL_VALUE_TRANSFER respects sgn_w)
    wire signed [ACC_QTZ.width-1:0] InputC_ext;
    assign InputC_ext = `REAL_VALUE_TRANSFER(InputC, INPUT_C_QTZ, ACC_QTZ);

    // Multiply, add bias, and accumulate
    logic signed [ACC_QTZ.width-1:0] Acc;

    always_comb begin : MAC_CORE
        logic signed [PROD_FULL_QTZ.width-1:0] product;

        // Initialize accumulator with the bias value
        Acc = InputC_ext;

        // Accumulate all products
        for (int j = 0; j < MUL_IN_PAIR_NUM; j++) begin : MAC_ACCUM_LOOP
            product = InputA_full[j] * InputB_full[j];
            Acc = Acc + product;
        end
    end

    // Output truncation to target quantization
    assign OutputC = `REAL_VALUE_TRANSFER(Acc, ACC_QTZ, OUTPUT_QTZ);
endmodule

// Multiply-Accumulate (MAC) module without bias
// Computes: OutputC = sum_{i=0}^{MUL_IN_PAIR_NUM-1} (InputA[i] * InputB[i])
// All operations (multiply & accumulate) are performed directly using
// native * and + operators for synthesis optimization.
// Each input's extension mode is determined by its quantization sgn_w:
//   sgn_w == 1 -> sign-extension (signed input)
//   sgn_w == 0 -> zero-extension (unsigned input)
module real_mac #(
	parameter qtz_t MUL_IN_A_QTZ  = DEFAULT_QTZ,
	parameter qtz_t MUL_IN_B_QTZ  = DEFAULT_QTZ,
	parameter qtz_t OUTPUT_QTZ    = DEFAULT_QTZ,
    parameter       MUL_IN_PAIR_NUM = 2
) (
	input  [MUL_IN_A_QTZ.width-1:0] InputA [MUL_IN_PAIR_NUM-1:0],
	input  [MUL_IN_B_QTZ.width-1:0] InputB [MUL_IN_PAIR_NUM-1:0],
	output [OUTPUT_QTZ.width-1:0]   OutputC
);
    // Extend inputs to full signed width for multiplication
    // IN_A_FULL_QTZ always has sgn_w=1; the extension bits are filled
    // according to MUL_IN_A_QTZ.sgn_w.
    localparam qtz_t IN_A_FULL_QTZ = get_qtz(1, MUL_IN_A_QTZ.int_w, MUL_IN_A_QTZ.fp_w, REAL);
    localparam qtz_t IN_B_FULL_QTZ = get_qtz(1, MUL_IN_B_QTZ.int_w, MUL_IN_B_QTZ.fp_w, REAL);

    // Full-precision product quantization (before accumulation)
    localparam PROD_FP_W  = IN_A_FULL_QTZ.fp_w + IN_B_FULL_QTZ.fp_w;
    localparam PROD_INT_W = IN_A_FULL_QTZ.int_w + IN_B_FULL_QTZ.int_w + 1;  // +1 for signed mult sign bit
    localparam qtz_t PROD_FULL_QTZ = get_qtz(1, PROD_INT_W, PROD_FP_W, REAL);

    // Accumulator quantization: extra guard bits for summing MUL_IN_PAIR_NUM products
    localparam ACC_EXTRA_BITS = $clog2(MUL_IN_PAIR_NUM);
    localparam ACC_INT_W = PROD_INT_W + ACC_EXTRA_BITS;
    localparam qtz_t ACC_QTZ = get_qtz(1, ACC_INT_W, PROD_FP_W, REAL);

    // Extended inputs (sign/zero-extended to full width based on sgn_w)
    wire signed [IN_A_FULL_QTZ.width-1:0] InputA_full [MUL_IN_PAIR_NUM-1:0];
    wire signed [IN_B_FULL_QTZ.width-1:0] InputB_full [MUL_IN_PAIR_NUM-1:0];

    genvar i;
    generate
        for (i = 0; i < MUL_IN_PAIR_NUM; i = i + 1) begin : GEN_INPUT_EXTEND
            assign InputA_full[i] = MUL_IN_A_QTZ.sgn_w ?
                {{(IN_A_FULL_QTZ.width - MUL_IN_A_QTZ.width){InputA[i][MUL_IN_A_QTZ.width-1]}}, InputA[i]} :
                {{(IN_A_FULL_QTZ.width - MUL_IN_A_QTZ.width){1'b0}}, InputA[i]};
            assign InputB_full[i] = MUL_IN_B_QTZ.sgn_w ?
                {{(IN_B_FULL_QTZ.width - MUL_IN_B_QTZ.width){InputB[i][MUL_IN_B_QTZ.width-1]}}, InputB[i]} :
                {{(IN_B_FULL_QTZ.width - MUL_IN_B_QTZ.width){1'b0}}, InputB[i]};
        end
    endgenerate

    // Multiply and accumulate
    logic signed [ACC_QTZ.width-1:0] Acc;

    always_comb begin : MAC_CORE
        logic signed [PROD_FULL_QTZ.width-1:0] product;

        Acc = 'b0;

        for (int j = 0; j < MUL_IN_PAIR_NUM; j++) begin : MAC_ACCUM_LOOP
            product = InputA_full[j] * InputB_full[j];
            Acc = Acc + product;
        end
    end

    // Output truncation to target quantization
    assign OutputC = `REAL_VALUE_TRANSFER(Acc, ACC_QTZ, OUTPUT_QTZ);
endmodule