`include "qtz_def.svh"

module real_adder_tree #(
	parameter qtz_t INPUT_QTZ  = 'b0,
	parameter qtz_t OUTPUT_QTZ = 'b0,
    parameter       ADD_NUM    = 2
) (
	input  [INPUT_QTZ.width-1:0] Input[ADD_NUM-1:0],
	output [ OUTPUT_QTZ.width-1:0] Output
);
    localparam qtz_t OUT_FULL_QTZ = get_qtz(INPUT_QTZ.sgn_w, INPUT_QTZ.int_w + $clog2(ADD_NUM) + 1, INPUT_QTZ.fp_w, REAL);

    logic [OUT_FULL_QTZ.width-1:0] Output_full; 

    always_comb begin : ADDERS
        Output_full = 'b0;

        for (int i = 0; i < ADD_NUM; i++) begin
            Output_full = Output_full + Input[i];
        end
    end

    assign Output = `REAL_VALUE_TRANSFER(Output_full, OUT_FULL_QTZ, OUTPUT_QTZ);
endmodule