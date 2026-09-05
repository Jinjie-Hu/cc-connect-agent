`ifndef __PARAMS_SVH__
`define __PARAMS_SVH__

`include "qtz_def.svh"

parameter TX = 32;
parameter ITER_PARALLEL = 8;  
parameter SYSTOLIC_PARALLEL = 2;
parameter ITER_NUM_WIDTH = 8;

// systolic quantization
parameter qtz_t H_QTZ = get_qtz(1, 3, 6, COMPLEX);
parameter qtz_t N0_QTZ = get_qtz(1, 6, 4, REAL);
parameter qtz_t Y_QTZ = get_qtz(1, 6, 5, COMPLEX);
parameter qtz_t YMF_MUL_QTZ = get_qtz(1, 7, 6, COMPLEX);
parameter qtz_t YMF_ACC_QTZ = get_qtz(1, 10, 8, COMPLEX);
parameter qtz_t YMF_QTZ = get_qtz(1, 10, 8, COMPLEX);
parameter qtz_t GD_QTZ = YMF_QTZ;
parameter qtz_t G_QTZ = get_qtz(1, 9, 5, COMPLEX);
parameter qtz_t G_MAC_QTZ = get_qtz(1, 9, 10, COMPLEX);
// fused G/MF accumulators, Option B: keep the running partial sum at full
// precision (single truncation at the end of the sweep, to G_QTZ/YMF_QTZ).
// G_ACC_FULL_QTZ fp = H_QTZ.fp + H_QTZ.fp = 12; int = complex_mac_w_bias
// internal ACC3 int width (10) so feeding G_reg back as InputC is an identity
// transfer (no per-cycle floor).  Measured |G| <= 155 << 2^10.
parameter qtz_t G_ACC_FULL_QTZ = get_qtz(1, 10, 12, COMPLEX);
// YMF_ACC_FULL_QTZ fp = H_QTZ.fp + Y_QTZ.fp = 11; int = ACC3 int width (13).
// Measured |y_mf| <= 471 << 2^13.
parameter qtz_t YMF_ACC_FULL_QTZ = get_qtz(1, 13, 11, COMPLEX);
parameter qtz_t A_DIAG_INV_QTZ = get_qtz(0, 0, 12, REAL);
parameter qtz_t GD_ACC_QTZ = get_qtz(1, 10, 10, COMPLEX);
parameter qtz_t X_QTZ = get_qtz(1, 3, 7, COMPLEX);

// util
parameter qtz_t G_DIAG_QTZ = get_qtz(G_QTZ.sgn_w, G_QTZ.int_w, G_QTZ.fp_w, REAL);
parameter qtz_t A_DIAG_QTZ = G_DIAG_QTZ;

// vec mul
parameter VEC_MUL_NUM = ITER_PARALLEL;
parameter SA_REUSE_DIAG = ITER_PARALLEL/SYSTOLIC_PARALLEL;
parameter SA_REUSE_NUM = SA_REUSE_DIAG + 1; // mul-add reuse, 8/2 + 1 = 5
parameter qtz_t VECMUL_QTZ = GD_QTZ;


`endif
