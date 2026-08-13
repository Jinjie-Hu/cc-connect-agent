#!/bin/bash
# =============================================================================
# run_all_tb.sh — run all 16 arithmetic_unit testbenches through Template's
#                 vcs/build.mk (SIM_FILE / TOP_MODULE / OUTPUT overridden).
#
# Must run from ~/projects/Template/vcs
# Optional arg: only=<tb> to run a single testbench (e.g. bash run_all_tb.sh only=real_multiplier)
cd ~/projects/Template/vcs || exit 1
ONLY=""
for a in "$@"; do case "$a" in only=*) ONLY="${a#only=}";; esac; done

export EDA_HOME=/mnt/wsl/eda/Synopsys
export PATH=$EDA_HOME/Vcs2016/linux64/bin:$EDA_HOME/Vcs2016/gui/dve/bin:$EDA_HOME/Verdi2016/bin:$PATH
export VCS_HOME=$EDA_HOME/Vcs2016
export VERDI_HOME=$EDA_HOME/Verdi2016
export LD_LIBRARY_PATH=$VCS_HOME/lib:$VCS_HOME/linux64/lib:$VERDI_HOME/share/PLI/VCS/LINUX64:$LD_LIBRARY_PATH
export SNPSLMD_LICENSE_FILE=27000@DESKTOP-R2D4SNR
# NOTE: do NOT set VCS_ARCH_OVERRIDE (must be unset when using the vcs wrapper)

TBS="real_multiplier real_adder real_addsub real_negative real_adder_tree \
     real_mac real_mac_w_bias complex_multiplier complex_adder complex_addsub \
     complex_conj complex_negative complex_adder_tree complex_real_multiplier \
     complex_mac complex_mac_w_bias"

PASS=0; FAIL=0; FAIL_LIST=""

for tb in $TBS; do
  [ -n "$ONLY" ] && [ "$ONLY" != "$tb" ] && continue
  OUT=vcs_tb_${tb}
  echo "==================== $tb ===================="
  # clean previous run dir
  rm -rf "$OUT"
  mkdir -p "$OUT"
  # testbench reads data/ relative to run dir -> symlink to ../data
  ln -sf ../data "$OUT/data"

  # SIM_FILE must be absolute: build.mk does `cd ${OUTPUT_DIR} && vcs -f ${SIM_FILE}`
  make -f build.mk sim SIM_FILE="$PWD/${tb}_tb.filelist" TOP_MODULE="${tb}_tb" OUTPUT="$OUT" > "${OUT}/make.log" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "[BUILD-FAIL] $tb (make rc=$rc)"
    tail -n 25 "${OUT}/make.log"
    FAIL=$((FAIL+1)); FAIL_LIST="$FAIL_LIST $tb"; continue
  fi

  if [ -f "$OUT/sim.log" ] && grep -q "TEST PASSED" "$OUT/sim.log"; then
    echo "[PASS] $tb"
    PASS=$((PASS+1))
  else
    echo "[FAIL] $tb"
    FAIL=$((FAIL+1)); FAIL_LIST="$FAIL_LIST $tb"
    grep -E "FAIL|MISMATCH|Expected|DUT|FATAL|TEST" "$OUT/sim.log" | tail -n 8
  fi
done

echo "============================================================"
echo "TOTAL PASS=$PASS FAIL=$FAIL"
echo "FAIL_LIST:$FAIL_LIST"
