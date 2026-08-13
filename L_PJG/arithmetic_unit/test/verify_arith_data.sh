#!/bin/bash
# =============================================================================
# verify_arith_data.sh
# --------------------
# Compile + simulate every arithmetic_unit testbench with VCS (in WSL) and
# check that the regenerated golden data (data/*.txt / data/out/*_expected.txt)
# matches the RTL bit-for-bit.
#
#   bash verify_arith_data.sh            # run all 16 testbenches
#   bash verify_arith_data.sh real_mac   # run a single testbench
#
# Uses the canonical qtz header at L_PJG/rtl/vinc/qtz_def.svh via +incdir.
# Builds in a throw-away dir (/tmp/arith_verify), never touches the repo.
# =============================================================================
set -u
VINC=/mnt/d/cc-connect-agent/L_PJG/rtl/vinc
TEST=/mnt/d/cc-connect-agent/L_PJG/arithmetic_unit/test
SRC=/mnt/d/cc-connect-agent/L_PJG/arithmetic_unit

declare -A SRCS=(
 [real_multiplier]="real_multiplier.sv"
 [real_adder]="real_adder.sv"
 [real_addsub]="real_addsub.sv"
 [real_negative]="real_negative.sv"
 [real_adder_tree]="real_adder_tree.sv"
 [real_mac]="real_mac.sv"
 [real_mac_w_bias]="real_mac.sv"
 [complex_multiplier]="complex_multiplier.sv real_multiplier.sv"
 [complex_adder]="complex_adder.sv real_adder.sv"
 [complex_addsub]="complex_addsub.sv real_addsub.sv"
 [complex_conj]="complex_conj.sv"
 [complex_negative]="complex_negative.sv"
 [complex_adder_tree]="complex_adder_tree.sv real_adder_tree.sv"
 [complex_real_multiplier]="complex_real_multiplier.sv real_multiplier.sv"
 [complex_mac]="complex_mac.sv"
 [complex_mac_w_bias]="complex_mac.sv"
)

TBS="real_multiplier real_adder real_addsub real_negative real_adder_tree \
     real_mac real_mac_w_bias complex_multiplier complex_adder complex_addsub \
     complex_conj complex_negative complex_adder_tree complex_real_multiplier \
     complex_mac complex_mac_w_bias"

only=${1:-}
TMP=/tmp/arith_verify
rm -rf "$TMP"; mkdir -p "$TMP"

pass=0; fail=0
for tb in $TBS; do
  [ -n "$only" ] && [ "$only" != "$tb" ] && continue
  cd "$TMP" || exit 1
  mkdir -p "$tb" && cd "$tb" || exit 1
  ln -sf "$TEST/data" data
  srcs=""
  for s in ${SRCS[$tb]}; do srcs="$srcs $SRC/$s"; done
  vcs -sverilog +v2k -timescale=1ns/1ns +notimingcheck -full64 -ignore all \
      +incdir+$VINC -top ${tb}_tb -o simv "$TEST/${tb}_tb.sv" $srcs > compile.log 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "[COMPILE-FAIL] $tb"; tail -n 25 compile.log; fail=$((fail+1)); continue
  fi
  ./simv > sim.log 2>&1
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "[PASS] $tb"; pass=$((pass+1))
  else
    echo "[FAIL] $tb"; grep -E "FAIL|MISMATCH|Expected|DUT|TEST" sim.log | tail -n 8
    fail=$((fail+1))
  fi
done
echo "---------------------------------------------"
echo "TOTAL PASS=$pass FAIL=$fail"
