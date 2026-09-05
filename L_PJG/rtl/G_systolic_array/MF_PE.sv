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

	// ---- fused MAC core (arithmetic_unit_full complex_mac_w_bias) ----
	// y_mf_new = y_mf + sum_i (H_conj[i] * y_out[i]); full-width products.
	// Option B (single-truncation accumulation): y_mf is held at YMF_ACC_FULL_QTZ
	// (fp11 = H.fp+Y.fp; int13 = MAC ACC3 full width) so feeding y_mf back as
	// InputC is an identity transfer and the running partial sum is kept exactly
	// every cycle; the only truncation in the whole sweep is the final
	// COMPLEX_VALUE_TRANSFER to the YMF_QTZ output at y_mf_store_EN. Register
	// structure and control signals (y_mf_clk_En/y_mf_rst/y_mf_store_EN/
	// y_mf_out_EN) are unchanged; only the register/MAC widths are widened.
	logic [YMF_ACC_FULL_QTZ.width-1:0] y_mf;
	logic [SYSTOLIC_PARALLEL-1:0][H_QTZ.width-1:0] H_conj;

	wire [YMF_ACC_FULL_QTZ.width-1:0] y_mf_new;   // = y_mf + sum_i H_conj[i]*y_out[i]

	wire [H_QTZ.width-1:0] mac_a[SYSTOLIC_PARALLEL-1:0];
	wire [Y_QTZ.width-1:0] mac_b[SYSTOLIC_PARALLEL-1:0];

	genvar i;
	generate
		for (i = 0; i < SYSTOLIC_PARALLEL; i = i + 1) begin: MAC_DEINT
			assign mac_a[i] = H_conj[i];
			assign mac_b[i] = y_out[i];
		end
	endgenerate

	complex_mac_w_bias #(
		.MUL_IN_A_QTZ(H_QTZ),
		.MUL_IN_B_QTZ(Y_QTZ),
		.INPUT_C_QTZ (YMF_ACC_FULL_QTZ),
		.OUTPUT_QTZ  (YMF_ACC_FULL_QTZ),
		.MUL_IN_PAIR_NUM(SYSTOLIC_PARALLEL),
		.FAST_MODE_EN(0)         // Gauss 3-mult, same algorithm as compact MF_PE
	) u_mac (
		.InputA(mac_a),
		.InputB(mac_b),
		.InputC(y_mf),
		.OutputC(y_mf_new)
	);

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

	logic [YMF_ACC_FULL_QTZ.width-1:0] y_mf_reg_new;
	assign y_mf_reg_new = y_mf_rst ? 'b0 : y_mf_new;
	dffl #(YMF_ACC_FULL_QTZ.width) u_y_mf_reg (
		.data_in(y_mf_reg_new),
		.data_out(y_mf), 
		.load_EN(y_mf_rst | y_mf_clk_En),
		.*
	);

	logic [YMF_QTZ.width-1:0] y_mf_out_reg_new;
	assign y_mf_out_reg_new = y_mf_out_EN ? y_mf_in :
							  y_mf_store_EN ? `COMPLEX_VALUE_TRANSFER(y_mf_new, YMF_ACC_FULL_QTZ, YMF_QTZ) : 'b0;

	dffl #(YMF_QTZ.width) u_y_mf_out_reg (
		.data_in(y_mf_out_reg_new),
		.load_EN(y_mf_out_EN | y_mf_store_EN),
		.data_out(y_mf_out),
		.*
	);
endmodule