# ============================================================================
# Makefile for arithmetic_unit testbenches
#
# Usage:
#   make run_all              — compile & simulate ALL testbenches, show summary
#   make <test_name>          — run a single test (e.g. make real_multiplier)
#   make <test_name>_only     — compile & simulate WITHOUT log aggregation
#   make list                 — show available test targets
#   make clean                — remove all build artifacts
#
# Supported test targets:
#   real_multiplier   real_adder_tree    complex_multiplier   complex_adder_tree
#   real_adder        real_addsub        complex_adder        complex_addsub
#   real_negative     real_mac           complex_conj         complex_negative
#   real_mac_w_bias                      complex_real_multiplier
#                                        complex_mac          complex_mac_w_bias
# ============================================================================

SHELL := /bin/bash

# ---- Configuration ---------------------------------------------------------
VCS      := vcs -sverilog +v2k -timescale=1ns/1ns \
            +notimingcheck \
            -full64 -j$$(nproc) -ignore all -l compile.log

SIM      := ./simv -l sim.log
SIM_DIR  := sim
SRC_DIR  := ..
TEST_DIR := .

TB_LIST := real_multiplier real_adder real_addsub real_negative \
           real_adder_tree real_mac real_mac_w_bias \
           complex_multiplier complex_adder complex_addsub \
           complex_conj complex_negative complex_adder_tree \
           complex_real_multiplier complex_mac complex_mac_w_bias

# Source files dependencies (src relative to $(SRC_DIR))
COMMON_SRC = qtz_def.svh

real_multiplier_SRC     = real_multiplier.sv
complex_multiplier_SRC  = complex_multiplier.sv  real_multiplier.sv
real_adder_SRC          = real_adder.sv
real_addsub_SRC         = real_addsub.sv
real_negative_SRC       = real_negative.sv
real_adder_tree_SRC     = real_adder_tree.sv
real_mac_SRC            = real_mac.sv
real_mac_w_bias_SRC     = real_mac.sv
complex_adder_SRC       = complex_adder.sv       real_adder.sv
complex_addsub_SRC      = complex_addsub.sv      real_addsub.sv
complex_conj_SRC        = complex_conj.sv
complex_negative_SRC    = complex_negative.sv
complex_adder_tree_SRC  = complex_adder_tree.sv  real_adder_tree.sv
complex_real_multiplier_SRC = complex_real_multiplier.sv  real_multiplier.sv
complex_mac_SRC         = complex_mac.sv
complex_mac_w_bias_SRC  = complex_mac.sv

# All expected output files live in data/out/
# Real TBs share data/real_input.txt; complex TBs use data/<module>_input.txt

# ---- Coloured output -------------------------------------------------------
RED   := \033[0;31m
GREEN := \033[0;32m
YELLOW:= \033[1;33m
CYAN  := \033[0;36m
NC    := \033[0m

# ---- Build rules -----------------------------------------------------------

.PHONY: all run_all list clean help $(TB_LIST)

all: run_all

# ---- Per-test compile+simulate ---------------------------------------------

define TB_template =

# Check that required data files exist
$(1)_check:
	@if [ ! -f "data/$(1)_input.txt" -a ! -f "data/real_input.txt" ]; then \
		echo -e "$(YELLOW)[WARN]  $(1): no input data file found$(NC)"; \
		echo "         Provide data/real_input.txt or data/$(1)_input.txt"; \
	fi; \
	if [ ! -f "data/out/$(1)_expected.txt" ]; then \
		echo -e "$(YELLOW)[WARN]  $(1): missing data/out/$(1)_expected.txt$(NC)"; \
		echo "         Provide expected output file."; \
	fi

# Compile + simulate, capture exit code
$(1): $(1)_check
	@echo -e "$(CYAN)[BUILD] $(1)$(NC)"
	@mkdir -p $(SIM_DIR)/$(1)
	cd $(SIM_DIR)/$(1) && \
	  ln -sf ../../data . 2>/dev/null; \
	  echo "[CMD] $$(VCS) -top $(1)_tb -o simv ../../$(1)_tb.sv $$(addprefix ../../$(SRC_DIR)/, $(COMMON_SRC) $$($(1)_SRC))" && \
	  $$(VCS) -top $(1)_tb -o simv ../../$(1)_tb.sv $$(addprefix ../../$(SRC_DIR)/, $(COMMON_SRC) $$($(1)_SRC)) && \
	  echo "[SIM]  $$(SIM)" && \
	  $$(SIM); \
	  rc=$$$$?; \
	  if [ $$$$rc -eq 0 ]; then \
	    echo -e "$(GREEN)[PASS]  $(1)$(NC)"; \
	  else \
	    echo -e "$(RED)[FAIL]  $(1)$(NC)"; \
	  fi; \
	  exit $$$$rc

endef

$(foreach tb,$(TB_LIST),$(eval $(call TB_template,$(tb))))

# ---- Run one test (shortcut) -----------------------------------------------

# ---- Run all tests and show summary table ----------------------------------

RESULTS_FILE := $(SIM_DIR)/.results

run_all:
	@echo -e "$(CYAN)============================================$(NC)"
	@echo -e "$(CYAN)  Running ALL testbenches ...$(NC)"
	@echo -e "$(CYAN)============================================$(NC)"
	@mkdir -p $(SIM_DIR)
	@echo "" > $(RESULTS_FILE)
	@total=0; pass=0; fail=0; \
	for tb in $(TB_LIST); do \
		total=$$((total + 1)); \
		echo -e "$(YELLOW)--- [$${total}/$$(echo $(TB_LIST) | wc -w)] $$tb ---$(NC)"; \
		$(MAKE) --no-print-directory $$tb 2>&1; \
		rc=$$$$?; \
		if [ $$$$rc -eq 0 ]; then \
			echo "PASS: $$tb" >> $(RESULTS_FILE); \
			pass=$$((pass + 1)); \
		else \
			echo "FAIL: $$tb" >> $(RESULTS_FILE); \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo -e "$(CYAN)============================================$(NC)"; \
	echo -e "$(CYAN)           TEST SUMMARY$(NC)"; \
	echo -e "$(CYAN)============================================$(NC)"; \
	printf "$(CYAN)%-28s %s$(NC)\n" "Module" "Result"; \
	printf "$(CYAN)%-28s %s$(NC)\n" "------" "------"; \
	while IFS=: read -r result name; do \
		if [ "$$result" = "PASS" ]; then \
			printf "  %-26s $(GREEN)%-8s$(NC)\n" "$$name" "PASS"; \
		else \
			printf "  %-26s $(RED)%-8s$(NC)\n" "$$name" "FAIL"; \
		fi; \
	done < $(RESULTS_FILE); \
	echo ""; \
	printf "  %-26s " "TOTAL"; \
	if [ $$fail -eq 0 ]; then \
		echo -e "$(GREEN)$$pass/$$total passed$(NC)"; \
	else \
		echo -e "$(RED)$$fail/$$total failed$(NC)"; \
	fi; \
	echo ""; \
	rm -f $(RESULTS_FILE)

# ---- Utilities -------------------------------------------------------------

list:
	@echo -e "$(CYAN)Available test targets:$(NC)"
	@for tb in $(TB_LIST); do \
		echo "  $$tb"; \
	done
	@echo ""
	@echo "Use:  make run_all        — run all tests"
	@echo "      make <target>      — run a single test"

help: list

clean:
	rm -rf $(SIM_DIR) simv* csrc* *.log *.key *.vpd .vlogansetup.*
	rm -rf DVEfiles* .fsdb* AN.DB
