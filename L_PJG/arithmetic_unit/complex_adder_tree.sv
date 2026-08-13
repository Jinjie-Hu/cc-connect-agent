`include "qtz_def.svh"

module complex_adder_tree #(
	parameter qtz_t INPUT_QTZ  = 'b0,
	parameter qtz_t OUTPUT_QTZ = 'b0,
    parameter       ADD_NUM    = 2
) (
	input  [INPUT_QTZ.width-1:0] Input[ADD_NUM-1:0],
	output [OUTPUT_QTZ.width-1:0] Output
);
    localparam qtz_t INPUT_REAL_QTZ = get_qtz(INPUT_QTZ.sgn_w, INPUT_QTZ.int_w, INPUT_QTZ.fp_w, REAL);
    localparam qtz_t OUT_FULL_REAL_QTZ = get_qtz(INPUT_QTZ.sgn_w, INPUT_QTZ.int_w + $clog2(ADD_NUM) + 1, INPUT_QTZ.fp_w, REAL);
    localparam qtz_t OUT_REAL_QTZ = get_qtz(OUTPUT_QTZ.sgn_w, OUTPUT_QTZ.int_w, OUTPUT_QTZ.fp_w, REAL);

    logic [INPUT_REAL_QTZ.width-1:0] input_r[ADD_NUM-1:0];
    logic [INPUT_REAL_QTZ.width-1:0] input_i[ADD_NUM-1:0];
    logic [OUT_FULL_REAL_QTZ.width-1:0] out_full_r;
    logic [OUT_FULL_REAL_QTZ.width-1:0] out_full_i;

    generate
        for (genvar i = 0; i < ADD_NUM; i++) begin : INPUT_SPLIT
            assign input_r[i] = Input[i][INPUT_QTZ.width-1 -: INPUT_REAL_QTZ.width];
            assign input_i[i] = Input[i][0 +: INPUT_REAL_QTZ.width];
        end
    endgenerate

    real_adder_tree #(
        .INPUT_QTZ(INPUT_REAL_QTZ),
        .OUTPUT_QTZ(OUT_FULL_REAL_QTZ),
        .ADD_NUM(ADD_NUM)
    ) u_real_part_tree (
        .Input(input_r),
        .Output(out_full_r)
    );

    real_adder_tree #(
        .INPUT_QTZ(INPUT_REAL_QTZ),
        .OUTPUT_QTZ(OUT_FULL_REAL_QTZ),
        .ADD_NUM(ADD_NUM)
    ) u_imag_part_tree (
        .Input(input_i),
        .Output(out_full_i)
    );

    assign Output = {
        {`REAL_VALUE_TRANSFER(out_full_r, OUT_FULL_REAL_QTZ, OUT_REAL_QTZ)},
        {`REAL_VALUE_TRANSFER(out_full_i, OUT_FULL_REAL_QTZ, OUT_REAL_QTZ)}
    };

endmodule