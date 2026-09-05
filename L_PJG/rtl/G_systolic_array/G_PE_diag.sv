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


	// ---- fused MAC core (arithmetic_unit_full complex_mac_w_bias) ----
	// mac_out = G_reg + sum_i (H_conj_out[i] * H_out[i]); full-width products.
	// Option B (single-truncation accumulation): G_reg/mac_out are held at
	// G_ACC_FULL_QTZ (fp12 = H.fp+H.fp; int10 = MAC ACC3 full width) so feeding
	// G_reg back as InputC is an identity transfer and the running partial sum is
	// kept exactly every cycle; the only truncation in the whole sweep is the
	// final COMPLEX_VALUE_TRANSFER to the G_QTZ output at G_store_EN. Register
	// structure and control signals (G_clk_En/G_reg_rst/G_store_EN/G_out_EN) are
	// unchanged; only the register/MAC widths are widened.
	wire [G_ACC_FULL_QTZ.width-1:0] G_reg;
	wire [G_ACC_FULL_QTZ.width-1:0] mac_out;   // = G_reg + sum_i H_conj_out[i]*H_out[i]

	wire [H_QTZ.width-1:0] mac_a[SYSTOLIC_PARALLEL-1:0];
	wire [H_QTZ.width-1:0] mac_b[SYSTOLIC_PARALLEL-1:0];

	genvar i;
	generate
		for (i = 0; i < SYSTOLIC_PARALLEL; i = i + 1) begin: MAC_DEINT
			assign mac_a[i] = H_conj_out[i];
			assign mac_b[i] = H_out[i];
		end
	endgenerate

	complex_mac_w_bias #(
		.MUL_IN_A_QTZ(H_QTZ),
		.MUL_IN_B_QTZ(H_QTZ),
		.INPUT_C_QTZ (G_ACC_FULL_QTZ),
		.OUTPUT_QTZ  (G_ACC_FULL_QTZ),
		.MUL_IN_PAIR_NUM(SYSTOLIC_PARALLEL),
		.FAST_MODE_EN(0)         // Gauss 3-mult, same algorithm as compact G_PE
	) u_mac (
		.InputA(mac_a),
		.InputB(mac_b),
		.InputC(G_reg),
		.OutputC(mac_out)
	);


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

	logic [G_ACC_FULL_QTZ.width-1:0] G_reg_new;
	assign G_reg_new = G_reg_rst ? 'b0 : mac_out;
	dffl #(G_ACC_FULL_QTZ.width) u_G_reg (
		.data_in(G_reg_new),
		.data_out(G_reg),
		.load_EN(G_reg_rst | G_clk_En),
		.*
	);

	wire [1:0][G_QTZ.width-1:0] G_out_new;
	assign G_out_new[0] = G_out_EN ? G_in[0] : `COMPLEX_VALUE_TRANSFER(mac_out, G_ACC_FULL_QTZ, G_QTZ);

	dffl #(G_QTZ.width) u_G_out_0_reg (
		.data_in(G_out_new[0]),
		.load_EN(G_out_EN | G_store_EN),
		.data_out(G_out[0]),
		.*
	);
	
	assign G_out_new[1] = 'b0;
	assign G_out[1] = 'b0;	
endmodule
	