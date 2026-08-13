`include "common.svh"

module MF_PE(y_in, y_out, H_conj_in, clk, y_mf_rst, y_mf_out, y_mf_out_EN, y_mf_store_EN, y_mf_in, y_mf_clk_En);

	input [SYSTOLIC_PARALLEL-1:0][H_QTZ.width-1:0] H_conj_in;
	input wire clk;
	input [YMF_QTZ.width-1:0] y_mf_in;
	input [SYSTOLIC_PARALLEL-1:0][Y_QTZ.width-1:0] y_in;
	input y_mf_rst;
	input y_mf_out_EN; 
	input y_mf_store_EN;
	input y_mf_clk_En;

	output logic [YMF_QTZ.width-1:0] y_mf_out;
	output logic [SYSTOLIC_PARALLEL-1:0][Y_QTZ.width-1:0] y_out;

	logic [YMF_ACC_QTZ.width-1:0] y_mf;
	logic [SYSTOLIC_PARALLEL-1:0][H_QTZ.width-1:0] H_conj;

	wire [SYSTOLIC_PARALLEL-1:0][YMF_MUL_QTZ.width-1:0] y_mf_part;
	wire [SYSTOLIC_PARALLEL-1:0][YMF_ACC_QTZ.width-1:0] y_mf_part_acc;
	wire [YMF_ACC_QTZ.width-1:0] y_mf_new;
	wire [SYSTOLIC_PARALLEL-1:0][1:0][YMF_ACC_QTZ.width-1:0] adder_in;
	wire [SYSTOLIC_PARALLEL-1:0][YMF_ACC_QTZ.width-1:0] adder_out;

	genvar i;
	generate
		for (i = 0; i < SYSTOLIC_PARALLEL; i = i + 1) begin: MF_PE_PARALLEL
			// Complex_multiplier_using_fp	#(
			// 	.INPUT_A_QTZ (Y_QTZ),
			// 	.INPUT_B_QTZ(H_QTZ),
			// 	.OUTPUT_QTZ (YMF_ACC_QTZ),
			// 	.SIG_WIDTH(SYSTOLIC_SIG_WIDTH),
			// 	.EXP_WIDTH(SYSTOLIC_EXP_WIDTH)
			// ) multiplier(.InputA(y_out[i]), .InputB(H_conj[i]), .OutputC(y_mf_part[i]));

			complex_multiplier	#(
				.INPUT_A_QTZ(H_QTZ),
				.INPUT_B_QTZ(Y_QTZ),
				.OUTPUT_QTZ (YMF_MUL_QTZ)
			) multiplier(.InputA(H_conj[i]), .InputB(y_out[i]), .OutputC(y_mf_part[i]));
			assign y_mf_part_acc[i] = `COMPLEX_VALUE_TRANSFER(y_mf_part[i], YMF_MUL_QTZ, YMF_ACC_QTZ);

			complex_adder #(
				.INPUT_A_QTZ(YMF_ACC_QTZ),
				.INPUT_B_QTZ(YMF_ACC_QTZ),
				.OUTPUT_QTZ(YMF_ACC_QTZ) 
			) adder(.InputA(adder_in[i][0]), .InputB(adder_in[i][1]), .OutputC(adder_out[i]));

            assign adder_in[i][0] = i == 0 ? y_mf :
                                    i < SYSTOLIC_PARALLEL/2 ? adder_out[2*i] : 
                                    (i - SYSTOLIC_PARALLEL/2)*2 < SYSTOLIC_PARALLEL ? (y_mf_part_acc[(i - SYSTOLIC_PARALLEL/2)*2]) : 'b0;

            assign adder_in[i][1] = i == 0 ? adder_out[1] :
                                    i < SYSTOLIC_PARALLEL/2 ? adder_out[2*i+1] : 
                                    (i - SYSTOLIC_PARALLEL/2)*2 + 1 < SYSTOLIC_PARALLEL ? (y_mf_part_acc[(i - SYSTOLIC_PARALLEL/2)*2+1]) : 'b0;

		end
	endgenerate

	generate
		for (i = 0; i < SYSTOLIC_PARALLEL; i = i + 1) begin: DATA_REG
			dffl #(H_QTZ.width) u_H_conj_reg (
				.data_in(H_conj_in[i]),
				.data_out(H_conj[i]),
				.load_EN(y_mf_clk_En),
				.*
			);

			dffl #(Y_QTZ.width) u_y_reg (
				.data_in(y_in[i]),
				.data_out(y_out[i]),
				.load_EN(y_mf_clk_En),
				.*
			);

		end
	endgenerate

	logic [YMF_ACC_QTZ.width-1:0] y_mf_reg_new;
	assign y_mf_new = adder_out[0];
	assign y_mf_reg_new = y_mf_rst ? 'b0 : y_mf_new;
	dffl #(YMF_ACC_QTZ.width) u_y_mf_reg (
		.data_in(y_mf_reg_new),
		.data_out(y_mf), 
		.load_EN(y_mf_rst | y_mf_clk_En),
		.*
	);

	logic [YMF_QTZ.width-1:0] y_mf_out_reg_new;
	assign y_mf_out_reg_new = y_mf_out_EN ? y_mf_in :
							  y_mf_store_EN ? `COMPLEX_VALUE_TRANSFER(y_mf_new, YMF_ACC_QTZ, YMF_QTZ) : 'b0;

	dffl #(YMF_QTZ.width) u_y_mf_out_reg (
		.data_in(y_mf_out_reg_new),
		.load_EN(y_mf_out_EN | y_mf_store_EN),
		.data_out(y_mf_out),
		.*
	);
endmodule