`include "common.svh"

/*
Module: G_PE_diag

* Parameter:
	* SW_EN: add SW option.
	G_PE with SW_EN has two modes: systolic array mode and MUL-add mode.

	* DIAGONAL_PE: whether it is a diagonal PE or not.
	Diagonal PE will delete some useless reg.

* Control signals: 
	* G_clk_En: mode sw & reg load enable:
	1. When G_clk_En == 1'b1, run as systolic array mode.
	2. When G_clk_En == 1'b0, run as mul-add mode.

	* G_store_EN:
	1. Move Gram matrix from (G_reg + G_part) to G_out reg.

	* G_out_EN: Output G_out reg one by one.

	* G_reg_rst: syncronous reset for G_reg 
*/

module G_PE_diag(H_in, H_conj_in, H_out, H_conj_out, clk, rst_n, G_reg_rst, G_out, G_in, G_out_EN, G_store_EN, G_clk_En);

	input [SYSTOLIC_PARALLEL-1:0][H_QTZ.width-1:0] H_in;
	input [SYSTOLIC_PARALLEL-1:0][H_QTZ.width-1:0] H_conj_in;
	input clk;
	input rst_n;
	input [1:0][G_QTZ.width-1:0] G_in;

	input G_reg_rst;
	input G_out_EN;
	input G_store_EN;
	input G_clk_En;

	output [SYSTOLIC_PARALLEL-1:0][H_QTZ.width-1:0] H_out;
	output [SYSTOLIC_PARALLEL-1:0][H_QTZ.width-1:0] H_conj_out;
	output [1:0][G_QTZ.width-1:0] G_out;


	// complex multiplier & adder
	wire [G_MAC_QTZ.width-1:0] G_reg;

	wire [SYSTOLIC_PARALLEL-1:0][G_MAC_QTZ.width-1:0] mul_out;
	wire [SYSTOLIC_PARALLEL-1:0][1:0][G_MAC_QTZ.width-1:0] adder_in;
	wire [SYSTOLIC_PARALLEL-1:0] 	 [G_MAC_QTZ.width-1:0] adder_out;

	genvar i;
	generate
		for (i = 0; i < SYSTOLIC_PARALLEL; i = i + 1) begin: MUL_PARALLRL
			complex_multiplier #(
				.INPUT_A_QTZ(H_QTZ),
				.INPUT_B_QTZ(H_QTZ),
				.OUTPUT_QTZ (G_MAC_QTZ)
			) multiplier(.InputA(H_conj_out[i]), .InputB(H_out[i]), .OutputC(mul_out[i]));

			complex_adder #(
				.INPUT_A_QTZ(G_MAC_QTZ),
				.INPUT_B_QTZ(G_MAC_QTZ),
				.OUTPUT_QTZ (G_MAC_QTZ)
			) adder(.InputA(adder_in[i][0]), .InputB(adder_in[i][1]), .OutputC(adder_out[i]));

            assign adder_in[i][0] = i == 0 ? G_reg :
                                    i < SYSTOLIC_PARALLEL/2 ? adder_out[2*i] : 
                                    (i - SYSTOLIC_PARALLEL/2)*2 < SYSTOLIC_PARALLEL ? mul_out[(i - SYSTOLIC_PARALLEL/2)*2] : 'b0;

            assign adder_in[i][1] = i == 0 ? adder_out[1] :
                                    i < SYSTOLIC_PARALLEL/2 ? adder_out[2*i+1] : 
                                    (i - SYSTOLIC_PARALLEL/2)*2 + 1 < SYSTOLIC_PARALLEL ? mul_out[(i - SYSTOLIC_PARALLEL/2)*2 + 1] : 'b0;
		end
	endgenerate

	// data reg
	generate
		for (i = 0; i < SYSTOLIC_PARALLEL; i = i + 1) begin: DATA_REG
			dffl #(H_QTZ.width) u_H_reg (
				.data_in(H_in[i]),
				.data_out(H_out[i]),
				.load_EN(G_clk_En),
				.*
			);
			dffl #(H_QTZ.width) u_H_conj_reg (
				.data_in(H_conj_in[i]),
				.data_out(H_conj_out[i]),
				.load_EN(G_clk_En),
				.*
			);
		end
	endgenerate

	logic [G_MAC_QTZ.width-1:0] G_reg_new;
	assign G_reg_new = G_reg_rst ? 'b0 : adder_out[0];
	dffl #(G_MAC_QTZ.width) u_G_reg (
		.data_in(G_reg_new),
		.data_out(G_reg),
		.load_EN(G_reg_rst | G_clk_En),
		.*
	);

	wire [1:0][G_QTZ.width-1:0] G_out_new;
	assign G_out_new[0] = G_out_EN ? G_in[0] : `COMPLEX_VALUE_TRANSFER(adder_out[0], G_MAC_QTZ, G_QTZ);

	dffl #(G_QTZ.width) u_G_out_0_reg (
		.data_in(G_out_new[0]),
		.load_EN(G_out_EN | G_store_EN),
		.data_out(G_out[0]),
		.*
	);
	
	assign G_out_new[1] = 'b0;
	assign G_out[1] = 'b0;	
endmodule
	