# File list for the functional (self-checking) L_PJG simulation.
# Same as the RTL file list used by the power/coverage sims (sim_rtl.f) but
# with the golden-checking testbench rtl/testbench_fc.sv in place of
# rtl/testbench.sv. Paths are EDA-absolute (see makefile target "com-fc").
# Usage (from the directory holding the makefile):
#   make com-fc   # compile (top tb_fc_detector, TEST_ITER_NUM=16)
#   make sim-fc   # compile + run -> prints "FC: PASS" / "FC: FAIL"
+incdir+/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/vinc
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/general/one_hot_code.sv
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/general/dfflr.sv
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/reciprocal_lut.v
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/complex_conj.sv
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/real_adder.sv
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/complex_negative.sv
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/real_addsub.sv
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/real_negative.sv
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/complex_real_multiplier.sv
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/real_multiplier.sv
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/complex_adder.sv
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/complex_addsub.sv
// ALL arithmetic units now uniformly resolve to arithmetic_unit_full:
//  - complex_mac.sv (defines complex_mac_w_bias) + complex_multiplier.sv =
//    the only full-vs-compact content differences (fused MAC for
//    G_PE/G_PE_diag/MF_PE; single-truncation complex_multiplier for LPJG_unit);
//  - the other units (complex_adder / complex_addsub / complex_conj /
//    complex_real_multiplier / real_multiplier / real_adder / real_addsub /
//    complex_negative / real_negative / reciprocal_lut.v) are BYTE-IDENTICAL
//    between rtl/arithmetic_unit (compact) and arithmetic_unit_full, so the
//    AFTER build references them from the full library for consistency (bit-
//    safe: same cell bodies, verified by whole-design FC 0/32).
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/complex_mac.sv
/home/asic03/graduate/proj_hujinjie/arithmetic_unit_full/complex_multiplier.sv
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/iter_unit/LPJG_unit.sv
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/iter_unit/PI_buffer.sv
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/detector.sv
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/testbench_fc.sv
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/RAM/SP_Ram.v
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/RAM/SP_Ram_array.sv
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/G_systolic_array/G_PE.sv
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/G_systolic_array/G_PE_diag.sv
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/G_systolic_array/MF_PE.sv
/home/asic03/graduate/proj_hujinjie/L_PJG/rtl/G_systolic_array/A_systolic_array.sv
