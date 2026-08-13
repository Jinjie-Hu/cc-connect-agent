#!/bin/bash
# gather_final_log.sh — compile the comprehensive final run log for the 16-TB
# L_PJG arithmetic_unit VCS regression and print per-TB sim details.
# Run on eda_wsl:  bash /mnt/d/cc-connect-agent/L_PJG/arithmetic_unit/gather_final_log.sh
set -u
VC=~/projects/Template/vcs
FINAL=/mnt/d/cc-connect-agent/L_PJG/arithmetic_unit/run_all_tb.TEMPLATE.final.log

{
echo "================================================================================"
echo " run_all_tb.TEMPLATE.final.log - L_PJG arithmetic_unit 16-TB VCS regression"
echo " Generated: $(date)"
echo " Machine  : $(hostname)"
echo " License  : lmgrd/snpslmd on port 27000 (active)"
echo "================================================================================"
echo
echo "### run_all_tb.sh summary (16 TBs)"
cat /tmp/run_all_tb.full.log
echo
echo "### Per-TB detail (compile tail + sim tail)"
for tb in real_multiplier real_adder real_addsub real_negative real_adder_tree \
          real_mac real_mac_w_bias complex_multiplier complex_adder complex_addsub \
          complex_conj complex_negative complex_adder_tree complex_real_multiplier \
          complex_mac complex_mac_w_bias; do
  OUT=$VC/vcs_tb_$tb
  echo "==================== $tb ===================="
  echo "-- compile (make.log tail 4) --"
  tail -n 4 "$OUT/make.log" 2>/dev/null
  echo "-- sim (sim.log tail 14) --"
  tail -n 14 "$OUT/sim.log" 2>/dev/null
  echo
done
} > "$FINAL"

echo "final log written: $FINAL"
wc -l "$FINAL"

echo
echo "### 3 previously-failed TBs — sim.log key lines"
for tb in complex_adder_tree complex_mac complex_mac_w_bias; do
  echo "==================== $tb ===================="
  grep -e TEST -e PASS -e FAIL -e Expected -e DUT -e Mismatch "$VC/vcs_tb_$tb/sim.log" | tail -n 14
  echo "-- compile summary --"
  grep -e Error -e error -e Warning "$VC/vcs_tb_$tb/make.log" | tail -n 5
done
