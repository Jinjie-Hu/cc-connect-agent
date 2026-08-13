#!/bin/bash
# diag_flags.sh -- try alternate VCS flag combos for the 3 problematic TBs
set -u
VINC=/mnt/d/cc-connect-agent/L_PJG/rtl/vinc
TEST=/mnt/d/cc-connect-agent/L_PJG/arithmetic_unit/test
SRC=/mnt/d/cc-connect-agent/L_PJG/arithmetic_unit
TB=$1
case $TB in
  complex_adder_tree) FILES="$TEST/complex_adder_tree_tb.sv $SRC/complex_adder_tree.sv $SRC/real_adder_tree.sv" ;;
  complex_mac)        FILES="$TEST/complex_mac_tb.sv $SRC/complex_mac.sv" ;;
  complex_mac_w_bias) FILES="$TEST/complex_mac_w_bias_tb.sv $SRC/complex_mac.sv" ;;
esac
cd /tmp && rm -rf diag && mkdir diag && cd diag && ln -sf "$TEST/data" data
combos=(
  "-sverilog +incdir+$VINC"
  "-sverilog +v2k +incdir+$VINC"
  "-sverilog -ntb_cmp +incdir+$VINC"
  "-sverilog -assert enable_diag +incdir+$VINC"
)
for combo in "${combos[@]}"; do
  echo "=== [$TB] flags: $combo ==="
  vcs $combo -timescale=1ns/1ns +notimingcheck -full64 -ignore all -top ${TB}_tb -o simv $FILES > log.txt 2>&1
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "COMPILE OK, running sim..."
    ./simv > sim.txt 2>&1
    echo "SIM RC=$?"
  else
    echo "COMPILE FAIL rc=$rc"
    grep -E "Error-\[" log.txt | head -3
  fi
done
