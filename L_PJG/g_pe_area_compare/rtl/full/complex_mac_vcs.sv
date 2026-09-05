`include "qtz_def.svh"

// ============================================================================
// Complex Multiply-Accumulate (MAC) module with bias
// Computes:
//   OutputC = InputC + sum_{i=0}^{MUL_IN_PAIR_NUM-1} (InputA[i] * InputB[i])
//
// where InputA[i], InputB[i], InputC, OutputC are all COMPLEX type.
// Multiplications are performed inline using direct * operator
// (no external multiplier instantiation).
//
// FAST_MODE_EN controls the complex multiplication algorithm:
//   0 -> 3-multiplication algorithm (Gauss method, saves 1 multiplier)
//   1 -> Direct 4-multiplication algorithm (faster critical path)
//
// Each input's extension mode is determined by its quantization sgn_w:
//   sgn_w == 1 -> sign-extension (signed input)
//   sgn_w == 0 -> zero-extension (unsigned input)
// ============================================================================
module complex_mac_w_bias #(
	parameter qtz_t MUL_IN_A_QTZ   = DEFAULT_QTZ,
	parameter qtz_t MUL_IN_B_QTZ   = DEFAULT_QTZ,
	parameter qtz_t INPUT_C_QTZ    = DEFAULT_QTZ,
	parameter qtz_t OUTPUT_QTZ     = DEFAULT_QTZ,
	parameter       MUL_IN_PAIR_NUM = 2,
	parameter       FAST_MODE_EN    = 0
) (
	input  [MUL_IN_A_QTZ.width-1:0] InputA [MUL_IN_PAIR_NUM-1:0],
	input  [MUL_IN_B_QTZ.width-1:0] InputB [MUL_IN_PAIR_NUM-1:0],
	input  [INPUT_C_QTZ.width-1:0]  InputC,
	output [OUTPUT_QTZ.width-1:0]   OutputC
);

	// ================================================================
	// Common quantization definitions (REAL = half of COMPLEX)
	// ================================================================
	localparam qtz_t IN_A_REAL_QTZ = get_qtz(MUL_IN_A_QTZ.sgn_w, MUL_IN_A_QTZ.int_w, MUL_IN_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_REAL_QTZ = get_qtz(MUL_IN_B_QTZ.sgn_w, MUL_IN_B_QTZ.int_w, MUL_IN_B_QTZ.fp_w, REAL);
	localparam qtz_t OUT_REAL_QTZ  = get_qtz(OUTPUT_QTZ.sgn_w,  OUTPUT_QTZ.int_w,  OUTPUT_QTZ.fp_w,  REAL);
	localparam qtz_t BIAS_REAL_QTZ = get_qtz(INPUT_C_QTZ.sgn_w,  INPUT_C_QTZ.int_w,  INPUT_C_QTZ.fp_w,  REAL);

	// Full signed extension QTZs (force sgn_w=1, preserve int/fp)
	localparam qtz_t AR_FULL_QTZ = get_qtz(1, IN_A_REAL_QTZ.int_w, IN_A_REAL_QTZ.fp_w, REAL);
	localparam qtz_t BR_FULL_QTZ = get_qtz(1, IN_B_REAL_QTZ.int_w, IN_B_REAL_QTZ.fp_w, REAL);


	localparam qtz_t IN_A_REALPLUS_QTZ = get_qtz(MUL_IN_A_QTZ.sgn_w,
												 MUL_IN_A_QTZ.int_w + 1,
												 MUL_IN_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_REALPLUS_QTZ = get_qtz(MUL_IN_B_QTZ.sgn_w,
												 MUL_IN_B_QTZ.int_w + 1,
												 MUL_IN_B_QTZ.fp_w, REAL);

	// Full signed extension for intermediate operands
	localparam qtz_t ARP_FULL_QTZ = get_qtz(1, IN_A_REALPLUS_QTZ.int_w,
											   IN_A_REALPLUS_QTZ.fp_w, REAL);
	localparam qtz_t BRP_FULL_QTZ = get_qtz(1, IN_B_REALPLUS_QTZ.int_w,
											   IN_B_REALPLUS_QTZ.fp_w, REAL);

	// Accumulator quantization (wide enough for full chain):
	//   pre-add: +1
	//   product: int = a.int + (b.int+1) + 1 = a.int + b.int + 2
	//   x - y / x - z: +1
	//   N-way acc: +$clog2(N)
	localparam ACC3_FP_W  = AR_FULL_QTZ.fp_w + BRP_FULL_QTZ.fp_w;
	localparam ACC3_INT_W = AR_FULL_QTZ.int_w + BRP_FULL_QTZ.int_w + 1 + 1 + $clog2(MUL_IN_PAIR_NUM);
	localparam qtz_t ACC3_QTZ = get_qtz(1, ACC3_INT_W, ACC3_FP_W, REAL);

	// ================================================================
	// Split complex inputs into real/imag parts
	// ================================================================
	wire signed [IN_A_REAL_QTZ.width-1:0] ar [MUL_IN_PAIR_NUM-1:0];
	wire signed [IN_A_REAL_QTZ.width-1:0] ai [MUL_IN_PAIR_NUM-1:0];
	wire signed [IN_B_REAL_QTZ.width-1:0] br [MUL_IN_PAIR_NUM-1:0];
	wire signed [IN_B_REAL_QTZ.width-1:0] bi [MUL_IN_PAIR_NUM-1:0];

	genvar pair;
	generate
		for (pair = 0; pair < MUL_IN_PAIR_NUM; pair++) begin : INPUT_SPLIT
			assign ar[pair] = InputA[pair][MUL_IN_A_QTZ.width-1 -: IN_A_REAL_QTZ.width];
			assign ai[pair] = InputA[pair][0 +: IN_A_REAL_QTZ.width];
			assign br[pair] = InputB[pair][MUL_IN_B_QTZ.width-1 -: IN_B_REAL_QTZ.width];
			assign bi[pair] = InputB[pair][0 +: IN_B_REAL_QTZ.width];
		end
	endgenerate

	// ================================================================
	// Extend inputs to full signed width (based on sgn_w)
	// ================================================================
	wire signed [AR_FULL_QTZ.width-1:0] ar_ext [MUL_IN_PAIR_NUM-1:0];
	wire signed [AR_FULL_QTZ.width-1:0] ai_ext [MUL_IN_PAIR_NUM-1:0];
	wire signed [BR_FULL_QTZ.width-1:0] br_ext [MUL_IN_PAIR_NUM-1:0];
	wire signed [BR_FULL_QTZ.width-1:0] bi_ext [MUL_IN_PAIR_NUM-1:0];

	generate
		for (pair = 0; pair < MUL_IN_PAIR_NUM; pair++) begin : INPUT_EXTEND
			assign ar_ext[pair] = MUL_IN_A_QTZ.sgn_w ?
				{{(AR_FULL_QTZ.width - IN_A_REAL_QTZ.width){ar[pair][IN_A_REAL_QTZ.width-1]}}, ar[pair]} :
				{{(AR_FULL_QTZ.width - IN_A_REAL_QTZ.width){1'b0}}, ar[pair]};
			assign ai_ext[pair] = MUL_IN_A_QTZ.sgn_w ?
				{{(AR_FULL_QTZ.width - IN_A_REAL_QTZ.width){ai[pair][IN_A_REAL_QTZ.width-1]}}, ai[pair]} :
				{{(AR_FULL_QTZ.width - IN_A_REAL_QTZ.width){1'b0}}, ai[pair]};
			assign br_ext[pair] = MUL_IN_B_QTZ.sgn_w ?
				{{(BR_FULL_QTZ.width - IN_B_REAL_QTZ.width){br[pair][IN_B_REAL_QTZ.width-1]}}, br[pair]} :
				{{(BR_FULL_QTZ.width - IN_B_REAL_QTZ.width){1'b0}}, br[pair]};
			assign bi_ext[pair] = MUL_IN_B_QTZ.sgn_w ?
				{{(BR_FULL_QTZ.width - IN_B_REAL_QTZ.width){bi[pair][IN_B_REAL_QTZ.width-1]}}, bi[pair]} :
				{{(BR_FULL_QTZ.width - IN_B_REAL_QTZ.width){1'b0}}, bi[pair]};
		end
	endgenerate

	// ================================================================
	// Per-pair complex products and accumulation (mode-dependent)
	// ================================================================
	generate
		if (FAST_MODE_EN) begin : FAST
			// --------------------------------------------------------
			// 4-multiplication mode:
			//   cr = ar*br - ai*bi
			//   ci = ai*br + ar*bi
			// --------------------------------------------------------
			// Accumulator quantization (wide enough for full chain):
			//   product: int = a.int + b.int + 1  (signed mult)
			//   add/sub: +1
			//   N-way acc: +$clog2(N)
			localparam ACC_FP_W  = AR_FULL_QTZ.fp_w + BR_FULL_QTZ.fp_w;
			localparam ACC_INT_W = AR_FULL_QTZ.int_w + BR_FULL_QTZ.int_w + 1 + 1 + $clog2(MUL_IN_PAIR_NUM);
			localparam qtz_t ACC_QTZ = get_qtz(1, ACC_INT_W, ACC_FP_W, REAL);

			// Product array — same width as accumulator, no truncation anywhere
			wire signed [ACC_QTZ.width-1:0] prod_r [MUL_IN_PAIR_NUM-1:0];
			wire signed [ACC_QTZ.width-1:0] prod_i [MUL_IN_PAIR_NUM-1:0];

			for (pair = 0; pair < MUL_IN_PAIR_NUM; pair++) begin : PAIR
				// Full-precision real products, directly at ACC width (auto sign-extend)
				wire signed [ACC_QTZ.width-1:0] ar_br, ai_bi, ai_br, ar_bi;
				assign ar_br = ar_ext[pair] * br_ext[pair];
				assign ai_bi = ai_ext[pair] * bi_ext[pair];
				assign ai_br = ai_ext[pair] * br_ext[pair];
				assign ar_bi = ar_ext[pair] * bi_ext[pair];

				// Complex product — all at ACC_QTZ.width, no overflow
				assign prod_r[pair] = ar_br - ai_bi;
				assign prod_i[pair] = ai_br + ar_bi;
			end

			// Bias extension (only place with REAL_VALUE_TRANSFER: bias → ACC)
			wire signed [BIAS_REAL_QTZ.width-1:0] bias_c_r, bias_c_i;
			assign bias_c_r = InputC[INPUT_C_QTZ.width-1 -: BIAS_REAL_QTZ.width];
			assign bias_c_i = InputC[0 +: BIAS_REAL_QTZ.width];
			wire signed [ACC_QTZ.width-1:0] bias_r, bias_i;
			assign bias_r = `REAL_VALUE_TRANSFER(bias_c_r, BIAS_REAL_QTZ, ACC_QTZ);
			assign bias_i = `REAL_VALUE_TRANSFER(bias_c_i, BIAS_REAL_QTZ, ACC_QTZ);

			// Accumulate
			logic signed [ACC_QTZ.width-1:0] Acc_r, Acc_i;
			always_comb begin : ACCUM
				Acc_r = bias_r;
				Acc_i = bias_i;
				for (int p = 0; p < MUL_IN_PAIR_NUM; p++) begin
					Acc_r = Acc_r + prod_r[p];
					Acc_i = Acc_i + prod_i[p];
				end
			end

			// Output truncation (the only truncation in the entire chain)
			assign OutputC = {
				`REAL_VALUE_TRANSFER(Acc_r, ACC_QTZ, OUT_REAL_QTZ),
				`REAL_VALUE_TRANSFER(Acc_i, ACC_QTZ, OUT_REAL_QTZ)
			};

		end else begin : NORMAL
			// --------------------------------------------------------
			// 3-multiplication mode (Gauss method):
			//   x = ar * (br + bi)
			//   y = (ar + ai) * bi
			//   z = (ar - ai) * br
			//   cr = x - y
			//   ci = x - z
			// --------------------------------------------------------
			// Pre-add/sub results: 1 extra int bit for carry

			// Product arrays — same width as accumulator
			wire signed [ACC3_QTZ.width-1:0] prod_r [MUL_IN_PAIR_NUM-1:0];
			wire signed [ACC3_QTZ.width-1:0] prod_i [MUL_IN_PAIR_NUM-1:0];

			for (pair = 0; pair < MUL_IN_PAIR_NUM; pair++) begin : PAIR
				// Pre-add/sub (at natural width with 1 extra int bit)
				wire signed [IN_A_REALPLUS_QTZ.width-1:0] ar_add_ai, ar_sub_ai;
				wire signed [IN_B_REALPLUS_QTZ.width-1:0] br_add_bi;

				assign ar_add_ai = ar[pair] + ai[pair];
				assign ar_sub_ai = ar[pair] - ai[pair];
				assign br_add_bi = br[pair] + bi[pair];

				// Extend pre-add results to full signed width (sgn_w-based)
				wire signed [ARP_FULL_QTZ.width-1:0] ar_add_ai_ext, ar_sub_ai_ext;
				wire signed [BRP_FULL_QTZ.width-1:0] br_add_bi_ext;

				assign ar_add_ai_ext = MUL_IN_A_QTZ.sgn_w ?
					{{(ARP_FULL_QTZ.width - IN_A_REALPLUS_QTZ.width){ar_add_ai[IN_A_REALPLUS_QTZ.width-1]}}, ar_add_ai} :
					{{(ARP_FULL_QTZ.width - IN_A_REALPLUS_QTZ.width){1'b0}}, ar_add_ai};
				assign ar_sub_ai_ext = MUL_IN_A_QTZ.sgn_w ?
					{{(ARP_FULL_QTZ.width - IN_A_REALPLUS_QTZ.width){ar_sub_ai[IN_A_REALPLUS_QTZ.width-1]}}, ar_sub_ai} :
					{{(ARP_FULL_QTZ.width - IN_A_REALPLUS_QTZ.width){1'b0}}, ar_sub_ai};
				assign br_add_bi_ext = MUL_IN_B_QTZ.sgn_w ?
					{{(BRP_FULL_QTZ.width - IN_B_REALPLUS_QTZ.width){br_add_bi[IN_B_REALPLUS_QTZ.width-1]}}, br_add_bi} :
					{{(BRP_FULL_QTZ.width - IN_B_REALPLUS_QTZ.width){1'b0}}, br_add_bi};

				// 3 multiplications — result directly at ACC3 width (auto sign-extend)
				wire signed [ACC3_QTZ.width-1:0] x_full, y_full, z_full;
				assign x_full = ar_ext[pair]      * br_add_bi_ext;
				assign y_full = ar_add_ai_ext     * bi_ext[pair];
				assign z_full = ar_sub_ai_ext     * br_ext[pair];

				// Complex product — all at ACC3_QTZ.width, no overflow
				assign prod_r[pair] = x_full - y_full;
				assign prod_i[pair] = x_full - z_full;
			end

			// Bias extension
			wire signed [BIAS_REAL_QTZ.width-1:0] bias_c_r, bias_c_i;
			assign bias_c_r = InputC[INPUT_C_QTZ.width-1 -: BIAS_REAL_QTZ.width];
			assign bias_c_i = InputC[0 +: BIAS_REAL_QTZ.width];
			wire signed [ACC3_QTZ.width-1:0] bias_r, bias_i;
			assign bias_r = `REAL_VALUE_TRANSFER(bias_c_r, BIAS_REAL_QTZ, ACC3_QTZ);
			assign bias_i = `REAL_VALUE_TRANSFER(bias_c_i, BIAS_REAL_QTZ, ACC3_QTZ);

			// Accumulate
			logic signed [ACC3_QTZ.width-1:0] Acc_r, Acc_i;
			always_comb begin : ACCUM
				Acc_r = bias_r;
				Acc_i = bias_i;
				for (int p = 0; p < MUL_IN_PAIR_NUM; p++) begin
					Acc_r = Acc_r + prod_r[p];
					Acc_i = Acc_i + prod_i[p];
				end
			end

			// Output truncation (the only truncation in the entire chain)
			assign OutputC = {
				`REAL_VALUE_TRANSFER(Acc_r, ACC3_QTZ, OUT_REAL_QTZ),
				`REAL_VALUE_TRANSFER(Acc_i, ACC3_QTZ, OUT_REAL_QTZ)
			};
		end
	endgenerate

endmodule


// ============================================================================
// Complex Multiply-Accumulate (MAC) module without bias
// Computes:
//   OutputC = sum_{i=0}^{MUL_IN_PAIR_NUM-1} (InputA[i] * InputB[i])
//
// Same architecture as complex_mac_w_bias, but without the bias input.
// ============================================================================
module complex_mac #(
	parameter qtz_t MUL_IN_A_QTZ   = DEFAULT_QTZ,
	parameter qtz_t MUL_IN_B_QTZ   = DEFAULT_QTZ,
	parameter qtz_t OUTPUT_QTZ     = DEFAULT_QTZ,
	parameter       MUL_IN_PAIR_NUM = 2,
	parameter       FAST_MODE_EN    = 0
) (
	input  [MUL_IN_A_QTZ.width-1:0] InputA [MUL_IN_PAIR_NUM-1:0],
	input  [MUL_IN_B_QTZ.width-1:0] InputB [MUL_IN_PAIR_NUM-1:0],
	output [OUTPUT_QTZ.width-1:0]   OutputC
);

	// ================================================================
	// Common quantization definitions (REAL = half of COMPLEX)
	// ================================================================
	localparam qtz_t IN_A_REAL_QTZ = get_qtz(MUL_IN_A_QTZ.sgn_w, MUL_IN_A_QTZ.int_w, MUL_IN_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_REAL_QTZ = get_qtz(MUL_IN_B_QTZ.sgn_w, MUL_IN_B_QTZ.int_w, MUL_IN_B_QTZ.fp_w, REAL);
	localparam qtz_t OUT_REAL_QTZ  = get_qtz(OUTPUT_QTZ.sgn_w,  OUTPUT_QTZ.int_w,  OUTPUT_QTZ.fp_w,  REAL);

	// Full signed extension QTZs (force sgn_w=1, preserve int/fp)
	localparam qtz_t AR_FULL_QTZ = get_qtz(1, IN_A_REAL_QTZ.int_w, IN_A_REAL_QTZ.fp_w, REAL);
	localparam qtz_t BR_FULL_QTZ = get_qtz(1, IN_B_REAL_QTZ.int_w, IN_B_REAL_QTZ.fp_w, REAL);


	localparam qtz_t IN_A_REALPLUS_QTZ = get_qtz(MUL_IN_A_QTZ.sgn_w,
												 MUL_IN_A_QTZ.int_w + 1,
												 MUL_IN_A_QTZ.fp_w, REAL);
	localparam qtz_t IN_B_REALPLUS_QTZ = get_qtz(MUL_IN_B_QTZ.sgn_w,
												 MUL_IN_B_QTZ.int_w + 1,
												 MUL_IN_B_QTZ.fp_w, REAL);

	localparam qtz_t ARP_FULL_QTZ = get_qtz(1, IN_A_REALPLUS_QTZ.int_w,
											   IN_A_REALPLUS_QTZ.fp_w, REAL);
	localparam qtz_t BRP_FULL_QTZ = get_qtz(1, IN_B_REALPLUS_QTZ.int_w,
											   IN_B_REALPLUS_QTZ.fp_w, REAL);

	localparam ACC3_FP_W  = AR_FULL_QTZ.fp_w + BRP_FULL_QTZ.fp_w;
	localparam ACC3_INT_W = AR_FULL_QTZ.int_w + BRP_FULL_QTZ.int_w + 1 + 1 + $clog2(MUL_IN_PAIR_NUM);
	localparam qtz_t ACC3_QTZ = get_qtz(1, ACC3_INT_W, ACC3_FP_W, REAL);

	// ================================================================
	// Split complex inputs into real/imag parts
	// ================================================================
	wire signed [IN_A_REAL_QTZ.width-1:0] ar [MUL_IN_PAIR_NUM-1:0];
	wire signed [IN_A_REAL_QTZ.width-1:0] ai [MUL_IN_PAIR_NUM-1:0];
	wire signed [IN_B_REAL_QTZ.width-1:0] br [MUL_IN_PAIR_NUM-1:0];
	wire signed [IN_B_REAL_QTZ.width-1:0] bi [MUL_IN_PAIR_NUM-1:0];

	genvar pair;
	generate
		for (pair = 0; pair < MUL_IN_PAIR_NUM; pair++) begin : INPUT_SPLIT
			assign ar[pair] = InputA[pair][MUL_IN_A_QTZ.width-1 -: IN_A_REAL_QTZ.width];
			assign ai[pair] = InputA[pair][0 +: IN_A_REAL_QTZ.width];
			assign br[pair] = InputB[pair][MUL_IN_B_QTZ.width-1 -: IN_B_REAL_QTZ.width];
			assign bi[pair] = InputB[pair][0 +: IN_B_REAL_QTZ.width];
		end
	endgenerate

	// ================================================================
	// Extend inputs to full signed width (based on sgn_w)
	// ================================================================
	wire signed [AR_FULL_QTZ.width-1:0] ar_ext [MUL_IN_PAIR_NUM-1:0];
	wire signed [AR_FULL_QTZ.width-1:0] ai_ext [MUL_IN_PAIR_NUM-1:0];
	wire signed [BR_FULL_QTZ.width-1:0] br_ext [MUL_IN_PAIR_NUM-1:0];
	wire signed [BR_FULL_QTZ.width-1:0] bi_ext [MUL_IN_PAIR_NUM-1:0];

	generate
		for (pair = 0; pair < MUL_IN_PAIR_NUM; pair++) begin : INPUT_EXTEND
			assign ar_ext[pair] = MUL_IN_A_QTZ.sgn_w ?
				{{(AR_FULL_QTZ.width - IN_A_REAL_QTZ.width){ar[pair][IN_A_REAL_QTZ.width-1]}}, ar[pair]} :
				{{(AR_FULL_QTZ.width - IN_A_REAL_QTZ.width){1'b0}}, ar[pair]};
			assign ai_ext[pair] = MUL_IN_A_QTZ.sgn_w ?
				{{(AR_FULL_QTZ.width - IN_A_REAL_QTZ.width){ai[pair][IN_A_REAL_QTZ.width-1]}}, ai[pair]} :
				{{(AR_FULL_QTZ.width - IN_A_REAL_QTZ.width){1'b0}}, ai[pair]};
			assign br_ext[pair] = MUL_IN_B_QTZ.sgn_w ?
				{{(BR_FULL_QTZ.width - IN_B_REAL_QTZ.width){br[pair][IN_B_REAL_QTZ.width-1]}}, br[pair]} :
				{{(BR_FULL_QTZ.width - IN_B_REAL_QTZ.width){1'b0}}, br[pair]};
			assign bi_ext[pair] = MUL_IN_B_QTZ.sgn_w ?
				{{(BR_FULL_QTZ.width - IN_B_REAL_QTZ.width){bi[pair][IN_B_REAL_QTZ.width-1]}}, bi[pair]} :
				{{(BR_FULL_QTZ.width - IN_B_REAL_QTZ.width){1'b0}}, bi[pair]};
		end
	endgenerate

	// ================================================================
	// Per-pair complex products and accumulation (mode-dependent)
	// ================================================================
	generate
		if (FAST_MODE_EN) begin : FAST
			// --------------------------------------------------------
			// 4-multiplication mode:
			//   cr = ar*br - ai*bi
			//   ci = ai*br + ar*bi
			// --------------------------------------------------------
			localparam ACC_FP_W  = AR_FULL_QTZ.fp_w + BR_FULL_QTZ.fp_w;
			localparam ACC_INT_W = AR_FULL_QTZ.int_w + BR_FULL_QTZ.int_w + 1 + 1 + $clog2(MUL_IN_PAIR_NUM);
			localparam qtz_t ACC_QTZ = get_qtz(1, ACC_INT_W, ACC_FP_W, REAL);

			wire signed [ACC_QTZ.width-1:0] prod_r [MUL_IN_PAIR_NUM-1:0];
			wire signed [ACC_QTZ.width-1:0] prod_i [MUL_IN_PAIR_NUM-1:0];

			for (pair = 0; pair < MUL_IN_PAIR_NUM; pair++) begin : PAIR
				wire signed [ACC_QTZ.width-1:0] ar_br, ai_bi, ai_br, ar_bi;
				assign ar_br = ar_ext[pair] * br_ext[pair];
				assign ai_bi = ai_ext[pair] * bi_ext[pair];
				assign ai_br = ai_ext[pair] * br_ext[pair];
				assign ar_bi = ar_ext[pair] * bi_ext[pair];

				assign prod_r[pair] = ar_br - ai_bi;
				assign prod_i[pair] = ai_br + ar_bi;
			end

			logic signed [ACC_QTZ.width-1:0] Acc_r, Acc_i;
			always_comb begin : ACCUM
				Acc_r = 'b0;
				Acc_i = 'b0;
				for (int p = 0; p < MUL_IN_PAIR_NUM; p++) begin
					Acc_r = Acc_r + prod_r[p];
					Acc_i = Acc_i + prod_i[p];
				end
			end

			assign OutputC = {
				`REAL_VALUE_TRANSFER(Acc_r, ACC_QTZ, OUT_REAL_QTZ),
				`REAL_VALUE_TRANSFER(Acc_i, ACC_QTZ, OUT_REAL_QTZ)
			};

		end else begin : NORMAL
			// --------------------------------------------------------
			// 3-multiplication mode (Gauss method):
			//   x = ar * (br + bi)
			//   y = (ar + ai) * bi
			//   z = (ar - ai) * br
			//   cr = x - y
			//   ci = x - z
			// --------------------------------------------------------

			wire signed [ACC3_QTZ.width-1:0] prod_r [MUL_IN_PAIR_NUM-1:0];
			wire signed [ACC3_QTZ.width-1:0] prod_i [MUL_IN_PAIR_NUM-1:0];

			for (pair = 0; pair < MUL_IN_PAIR_NUM; pair++) begin : PAIR
				wire signed [IN_A_REALPLUS_QTZ.width-1:0] ar_add_ai, ar_sub_ai;
				wire signed [IN_B_REALPLUS_QTZ.width-1:0] br_add_bi;

				assign ar_add_ai = ar[pair] + ai[pair];
				assign ar_sub_ai = ar[pair] - ai[pair];
				assign br_add_bi = br[pair] + bi[pair];

				wire signed [ARP_FULL_QTZ.width-1:0] ar_add_ai_ext, ar_sub_ai_ext;
				wire signed [BRP_FULL_QTZ.width-1:0] br_add_bi_ext;

				assign ar_add_ai_ext = MUL_IN_A_QTZ.sgn_w ?
					{{(ARP_FULL_QTZ.width - IN_A_REALPLUS_QTZ.width){ar_add_ai[IN_A_REALPLUS_QTZ.width-1]}}, ar_add_ai} :
					{{(ARP_FULL_QTZ.width - IN_A_REALPLUS_QTZ.width){1'b0}}, ar_add_ai};
				assign ar_sub_ai_ext = MUL_IN_A_QTZ.sgn_w ?
					{{(ARP_FULL_QTZ.width - IN_A_REALPLUS_QTZ.width){ar_sub_ai[IN_A_REALPLUS_QTZ.width-1]}}, ar_sub_ai} :
					{{(ARP_FULL_QTZ.width - IN_A_REALPLUS_QTZ.width){1'b0}}, ar_sub_ai};
				assign br_add_bi_ext = MUL_IN_B_QTZ.sgn_w ?
					{{(BRP_FULL_QTZ.width - IN_B_REALPLUS_QTZ.width){br_add_bi[IN_B_REALPLUS_QTZ.width-1]}}, br_add_bi} :
					{{(BRP_FULL_QTZ.width - IN_B_REALPLUS_QTZ.width){1'b0}}, br_add_bi};

				wire signed [ACC3_QTZ.width-1:0] x_full, y_full, z_full;
				assign x_full = ar_ext[pair]      * br_add_bi_ext;
				assign y_full = ar_add_ai_ext     * bi_ext[pair];
				assign z_full = ar_sub_ai_ext     * br_ext[pair];

				assign prod_r[pair] = x_full - y_full;
				assign prod_i[pair] = x_full - z_full;
			end

			logic signed [ACC3_QTZ.width-1:0] Acc_r, Acc_i;
			always_comb begin : ACCUM
				Acc_r = 'b0;
				Acc_i = 'b0;
				for (int p = 0; p < MUL_IN_PAIR_NUM; p++) begin
					Acc_r = Acc_r + prod_r[p];
					Acc_i = Acc_i + prod_i[p];
				end
			end

			assign OutputC = {
				`REAL_VALUE_TRANSFER(Acc_r, ACC3_QTZ, OUT_REAL_QTZ),
				`REAL_VALUE_TRANSFER(Acc_i, ACC3_QTZ, OUT_REAL_QTZ)
			};
		end
	endgenerate

endmodule
