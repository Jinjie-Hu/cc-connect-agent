# EDA Manual Index — D:\ICAIS\EDA_Manual

> Maintained by the IC Dev Lead orchestrator. Purpose: each EDA-related agent consults this index to find the manual(s) relevant to its own tasks. Manuals live under `D:\ICAIS\EDA_Manual`. All guides are Synopsys (or Cadence SoC Encounter) EDA tool docs.

## Agent → Manual mapping (quick lookup)

| Agent | Relevant manuals (folder) | Status |
|---|---|---|
| **DC** (synthesis/timing/power/area/DFT) | `DC/` (8 core files below) | ✅ mapped |
| **RTL developer** (SV/Verilog RTL, VCS TBs) | `DC/` HDL Compile SV+Verilog, Design Compiler UG, SDC; root `vera_user_guide` | ✅ mapped |
| **MIMO platform** (Python sim/BER) | — none — | ✅ confirmed none relevant |
| **PT** (STA signoff / power / SI) | `pt/` (4 docs below) | ✅ mapped |
| **ICC** (place & route ICC1/ICC2) | `icc2/` + `eetop.cn_ICC教程/` | ✅ mapped |
| **Formality** (LEC) | `DC/eetop.cn_forug.pdf` | ✅ mapped |

---

## DC agent — `D:\ICAIS\EDA_Manual\DC\`

| File | Topic | Consult for |
|---|---|---|
| `eetop.cn_Design Compiler®User Guide.pdf` | DC P-2019.03 (792pp) — **primary** | read/elaborate/link/compile flow, `compile_ultra`, DC-Tcl scripting, constraints, timing/area/QoR reporting, datapath/register/FSM optimization, retiming, Formality handoff |
| `eetop.cn_dcug.pdf` | DC D-2010.03-SP2 (465pp, older) | legacy DC syntax; concise end-to-end design example; cross-check when P-2019.03 wording differs |
| `eetop.cn_DC Explorer User Guide.pdf` (+ identical dup `(1).pdf`) | DC Explorer GUI P-2019.03 (422pp) | GUI flows, physical-constraint driven runs, UPF power-intent exploration (dup is byte-identical — treat as one) |
| `eetop.cn_sdc.pdf` | SDC App Note v2.0 (38pp) | exact SDC syntax: `create_clock`, `set_input/output_delay`, `set_false_path`, `set_multicycle_path`, `get_ports/pins/cells/clocks` |
| `eetop.cn_Power Compiler™ User Guide.pdf` | Power Compiler P-2019.03-SP4 (466pp) | `report_power`, SAIF generation/annotation, clock gating, leakage/dynamic power optimization, UPF multivoltage |
| `eetop.cn_dftxg1.pdf` | DFT Compiler Scan D-2010.03-SP4 (515pp) | scan insertion, RTL/pre-scan test DRC, `insert_dft`, scan chains/clocks, OCC, TetraMAX export |
| `eetop.cn_HDL Compile for SystemVerilog User Guide.pdf` | HDL Compiler SV P-2019.03-SP4 (332pp) | `read_sverilog`, synthesizable SV constructs, interfaces/packages/enums/structs/`$unit`, RTL pragmas, sim-vs-synth mismatch troubleshooting |
| `eetop.cn_HDL Compile for Verilog User Guide.pdf` | HDL Compiler Verilog P-2019.03-SP2 (208pp) | `read_verilog`, Verilog-2001/2005 support, coding for synthesis, synthesis directives |
| `eetop.cn_HDL Compile for VHDL User Guide.pdf` | HDL Compiler VHDL P-2019.03-SP2 (305pp) | only if VHDL work arises (current RTL is SV/Verilog) |
| `eetop.cn_forug.pdf` | Formality D-2010.03 (331pp) — adjacent | LEC (RTL-vs-netlist equivalence) after synthesis |

**Not DC's:** `eetop.cn_tmug.pdf` (TetraMAX ATPG), `eetop.cn_vera_user_guide.pdf` (Vera), all of `pt/`, `icc2/`, `eetop.cn_ICC教程/` (place & route / STA sign-off).

---

## RTL developer — relevant manuals

| File | Topic | Consult for |
|---|---|---|
| `DC\eetop.cn_HDL Compile for SystemVerilog User Guide.pdf` | HDL Compiler SV P-2019.03-SP4 | **HIGH** — SV RTL syntax/semantics + which constructs are synthesizable and how DC maps them; combinational/sequential/FSM inference; bit-truncation coding for datapath; interfaces/packages; RTL pragmas; sim-vs-synth mismatch troubleshooting |
| `DC\eetop.cn_HDL Compile for Verilog User Guide.pdf` | HDL Compiler Verilog P-2019.03-SP2 | **HIGH** — Verilog-2001/2005 guidance, esp. for mixed `.sv`/`.v` code (e.g. `reciprocal_lut.v`) |
| `DC\eetop.cn_Design Compiler®User Guide.pdf` | DC P-2019.03 | **HIGH** — because our RTL is synthesized (see `L_PJG/makefile`, `spyglass_run.tcl`): how RTL is compiled/optimized/constrained; datapath optimization |
| `DC\eetop.cn_sdc.pdf` | SDC App Note v2.0 | when constraints (`create_clock`, input/output delays) come up |
| `eetop.cn_vera_user_guide.pdf` (root) | Vera D-2009.12 (624pp) | verification **methodology** only (randomization, functional coverage concepts → map to SV/UVM thinking); Vera syntax itself is not used |

**NOT relevant:** `eetop.cn_tmug.pdf` (TetraMAX ATPG), `DC\eetop.cn_HDL Compile for VHDL User Guide.pdf` (VHDL only), all of `pt/`, `icc2/`, `eetop.cn_ICC教程/`.

**Gap:** no VCS user guide exists in this folder — for VCS-specific debugging rely on the HDL-Compile-SV guide's "Reading Designs Using VCS Command-Line Options" section + general SV knowledge, or the workspace `vcs_*.sh` wrappers.

---

## MIMO platform — relevance check

**None of the manuals are relevant.** The MIMO platform is pure-Python wireless simulation (numpy/torch/commpy: channel models, modulation, FEC/LDPC, IDD/2D detection, BER via `idd_test`/`up_test`/`2D_sym`). All `D:\ICAIS\EDA_Manual` docs are Synopsys/Cadence hardware EDA tool manuals (DC synthesis, ICC/ICC2 P&R, PrimeTime STA/power/SI, DFT/ATPG, Formality, SDC, Vera) that operate on RTL/netlists via Tcl/GUI and gate-level libraries — none interface with Python or BER/channel simulation.

Closest-but-not-applicable: `DC\eetop.cn_HDL Compile for SystemVerilog User Guide.pdf` touches VCS+SV only for reading RTL into synthesis (no co-sim/DPI/Python linkage).

---

## PT agent — `D:\ICAIS\EDA_Manual\pt\`

| File | Topic | Consult for |
|---|---|---|
| `eetop.cn_ptugf.pdf` | PrimeTime Fundamentals v2016.06 (470pp) | core STA/signoff: read netlist/.db/.ddc, link_design, SDC constraints, check_timing, report_timing/report_constraint/report_analysis_coverage |
| `eetop.cn_ptuga.pdf` | PrimeTime Advanced Timing Analysis v2016.06 (378pp) | back-annotation (read_sdf/read_parasitics), OCV/derating/CRPR, latch time-borrowing, multivoltage, write_sdf |
| `eetop.cn_PrimeTime PX User Guide.pdf` | PrimeTime PX (168pp) | power analysis: averaged + time-based, report_power, set_switching_activity, read_vcd/read_saif |
| `eetop.cn_PrimeTime SI User Guide.pdf` | PrimeTime SI (201pp) | crosstalk/noise: set_si_options, report_noise, read_parasitics (SPEF), write_spice_deck |

Executable: `pt_shell` (batch `-f`, GUI, multicore). Note: PT links a gate-level netlist (no compile); shares SDC/Tcl with DC.

---

## ICC agent — `D:\ICAIS\EDA_Manual\icc2\` + `eetop.cn_ICC教程\`

Key manuals:
| File | Topic | Consult for |
|---|---|---|
| `icc2\icc2_implementation.pdf` | ICC2 Implementation UG (470pp) | ICC2 flow narrative |
| `icc2\icc2_tool_command.pdf` | ICC2 per-command reference (5050pp) | exhaustive command/flags lookup |
| `icc2\icc2_application options and attribute.pdf` | ICC2 app options (1191pp) | set_app_options/get_app_options |
| `icc2\icc2 Error message.pdf` | ICC2 message reference (3194pp) | error lookup by code |
| `icc2\icc2_timing_analysis.pdf` | ICC2 timing/QoR (148pp) | timing analysis |
| `icc2\IC Compiler 2 CTS Student Guide.pdf` + `icc2\CTS-ICC2_UG.docx` | CTS | clock tree synthesis deep-dive |
| `eetop.cn_ICC教程\IC Compiler Implementation User Guide Version F-2011.09.pdf` | ICC1 Implementation UG | primary ICC1 manual |
| `eetop.cn_ICC教程\ICC1_201003_SG_02_Design_Planning.pdf` | ICC1 design planning | floorplan |
| `eetop.cn_ICC教程\workshop\ICC-RM_C-2009.06-SP4\` | ICC-RM reference methodology scripts | authoritative ICC1 command spellings per phase |

Executables: ICC1 `icc_shell -64bit`, ICC2 `icc2_shell`. Flow: floorplan (initialize_floorplan/create_floorplan) → place_opt → clock_opt (CTS) → route_opt/route_auto → chip finish → signoff_opt/signoff_drc. Note: many ICC教程 PDFs are scanned/compressed — use ICC-RM scripts + icc2_tool_command.pdf as command truth.

---

## Formality agent — `D:\ICAIS\EDA_Manual\DC\eetop.cn_forug.pdf`

| File | Topic | Consult for |
|---|---|---|
| `DC\eetop.cn_forug.pdf` | Formality® User Guide D-2010.03-era (331pp) | whole LEC flow: read ref/impl, set_top_designs, match, verify, debug failing points, naming rules, set_constant/set_equivalent |

Executable: `fm_shell` (batch `-f`, GUI `-gui`). Flow: setup libraries → read_verilog (ref) → read_verilog -i (impl netlist) → set_top_designs → functional constraints (set_clock/set_constant/set_case_analysis) → match → verify → report_*_points / analyze_points. No timing/area/power — functional equivalence only.

---

## Notes
- `pt/` = PrimeTime sign-off (STA/power/SI) — owned by the **PT** agent.
- `icc2/` + `eetop.cn_ICC教程/` = IC Compiler II / ICC1 place & route (incl. SoC Encounter) — owned by the **ICC** agent.
- Duplicates: `DC Explorer User Guide.pdf` == `(1).pdf` (byte-identical).
- Maintained via subagent research on 2026-08-12 (DC, RTL developer, MIMO platform, PT, ICC, Formality each classified their own manuals).
