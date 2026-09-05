#!/bin/bash
# Differential VCS functional check: compact G_PE vs fused G_PE_fused
export VCS_HOME=/eda/synopsys/vcs/VCS/VCS2014
export NOVAS_HOME=/eda/synopsys/verdi/vJ-2014.12-SP2
export LD_LIBRARY_PATH="$VCS_HOME/amd64/lib:$NOVAS_HOME/share/PLI/VCS/LINUX64"
export PATH="$VCS_HOME/bin:$PATH"
export SNPSLMD_LICENSE_FILE=27000@icaislab

cd /home/asic03/graduate/proj_hujinjie/g_pe_area_test/sim || exit 1

echo "===== [1/2] compile + run compact G_PE ====="
vcs -sverilog +v2k -timescale=1ns/1ns -top tb_gpe_diff -full64 -j8 \
    -o sim_pe_c -l compile_c.log \
    -f ../syn/script/g_pe_struct/G_PE.filelist tb_gpe_diff.sv > build_c.txt 2>&1
rc=$?
echo "compact compile rc=$rc"
if [ $rc -eq 0 ]; then
  ./sim_pe_c +vcs+flush+all +vcs+stop+200000ns -l sim_c.log > trace_c.txt 2>&1
  echo "compact sim rc=$?"
fi

echo "===== [2/2] compile + run fused G_PE_fused ====="
vcs -sverilog +v2k -timescale=1ns/1ns -top tb_gpe_diff -full64 -j8 \
    -o sim_pe_f -l compile_f.log +define+USE_FUSED \
    -f ../syn/script/g_pe_fused/G_PE_fused.filelist tb_gpe_diff.sv > build_f.txt 2>&1
rc=$?
echo "fused compile rc=$rc"
if [ $rc -eq 0 ]; then
  ./sim_pe_f +vcs+flush+all +vcs+stop+200000ns -l sim_f.log > trace_f.txt 2>&1
  echo "fused sim rc=$?"
fi

echo "===== DONE ====="
grep -h "SELF_CHECK\|TB_DONE" trace_c.txt trace_f.txt 2>/dev/null