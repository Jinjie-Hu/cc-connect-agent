#!/bin/bash
# Final summary: check PASS/FAIL for all 16
cd ~/projects/Template/vcs
TBS="real_multiplier real_adder real_addsub real_negative real_adder_tree \
     real_mac real_mac_w_bias complex_multiplier complex_adder complex_addsub \
     complex_conj complex_negative complex_adder_tree complex_real_multiplier \
     complex_mac complex_mac_w_bias"
for tb in $TBS; do
  d=vcs_tb_$tb
  if [ -f "$d/sim.log" ] && grep -q "TEST PASSED" "$d/sim.log"; then
    echo "[PASS] $tb"
  else
    if [ -f "$d/sim.log" ]; then
      echo "[FAIL] $tb (sim.log present)"
    else
      echo "[FAIL] $tb (no sim.log)"
    fi
  fi
done
echo "=== sim.log count ==="
ls vcs_tb_*/sim.log | wc -l
