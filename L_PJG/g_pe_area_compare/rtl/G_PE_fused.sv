`include "common.svh"

/*
Module: G_PE_fused

A full-library (arithmetic_unit_full) variant of G_PE, used to quantify the
synthesis impact of replacing L_PJG's compact per-stage-truncation arithmetic
with the fused complete modules.

Ports, control semantics and register structure are identical to
rtl/G_systolic_array/G_PE.sv. The only difference is the arithmetic core:

  * G_PE       : SYSTOLIC_PARALLEL x compact complex_multiplier
                 (H_QTZ x H_QTZ -> G_MAC_QTZ, per-product truncation)
                 + compact complex_adder accumulate tree feeding G_reg
  * G_PE_fused : one arithmetic_unit_full complex_mac_w_bias computing
                     mac_out = G_reg + sum_i (H_conj_out[i] * H_out[i])
                 with full-width products/accumulator and a single output
                 truncation to G_MAC_QTZ.

To adopt this file in L_PJG, rename the module to G_PE and replace
rtl/G_systolic_array/G_PE.sv (add arithmetic_unit_full/*.sv to the synthesis
filelist instead of the compact arithmetic_unit files), then re-verify the
whole systolic array / detector.

Note: not guaranteed bit-exact vs the compact G_PE because product/adder
widths and truncation points differ; both keep identical sequential state
(register count) so area/timing comparison is apples-to-apples.
*/
module G_PE_fused(H_in, H_conj_in, H_out, H_conj_out, clk, rst_n, G_reg_rst, G_out, G_in, G_out_EN, G_store_EN, G_clk_En);

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


	// ---- fused multiply-accumulate core (arithmetic_unit_full) ----
	wire [G_MAC_QTZ.width-1:0] G_reg;
	wire [G_MAC_QTZ.width-1:0] mac_out;   // = G_reg + sum_i H_conj[i]*H[i]

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
		.INPUT_C_QTZ (G_MAC_QTZ),
		.OUTPUT_QTZ  (G_MAC_QTZ),
		.MUL_IN_PAIR_NUM(SYSTOLIC_PARALLEL),
		.FAST_MODE_EN(0)         // Gauss 3-mult, same algorithm as compact G_PE
	) u_mac (
		.InputA(mac_a),
		.InputB(mac_b),
		.InputC(G_reg),
		.OutputC(mac_out)
	);

	// ---- data reg (identical to G_PE) ----
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

	// ---- accumulator (identical to G_PE) ----
	logic [G_MAC_QTZ.width-1:0] G_reg_new;
	assign G_reg_new = G_reg_rst ? 'b0 : mac_out;
	dffl #(G_MAC_QTZ.width) u_G_reg (
		.data_in(G_reg_new),
		.data_out(G_reg),
		.load_EN(G_reg_rst | G_clk_En),
		.*
	);

	// ---- G_out store/output (identical to G_PE) ----
	wire [1:0][G_QTZ.width-1:0] G_out_new;
	assign G_out_new[0] = G_out_EN ? G_in[0] : `COMPLEX_VALUE_TRANSFER(mac_out, G_MAC_QTZ, G_QTZ);

	dffl #(G_QTZ.width) u_G_out_0_reg (
		.data_in(G_out_new[0]),
		.load_EN(G_out_EN | G_store_EN),
		.data_out(G_out[0]),
		.*
	);

	assign G_out_new[1] = G_out_EN ? G_in[1] :
					      G_store_EN ? `COMPLEX_VALUE_TRANSFER(mac_out, G_MAC_QTZ, G_QTZ) : 'b0;

	dffl #(G_QTZ.width) u_G_out_1_reg (
		.data_in(G_out_new[1]),
		.load_EN(G_out_EN | G_store_EN),
		.data_out(G_out[1]),
		.*
	);

endmodule
