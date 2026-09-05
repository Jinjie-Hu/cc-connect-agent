# L_PJG 面积对比总结文档（full 完整库 vs compact 结构截位）

本目录集中归档 L_PJG 相关的「用 `arithmetic_unit_full`（完整库、全精度+单次截位）替换 compact（结构截位）」系列**总结报告**，作为远程仓库的正式记录。各报告均保留其在实验工程目录下的原始版本，本目录为汇总索引。

> 综合环境：Synopsys DC J-2014.09-SP3，TSMC 28nm TT（`tcbn28hpcplusbwp30p140`），800 MHz + 20% setup uncertainty，logic 模式。

## 报告列表

| 报告 | 主题 | 日期 | 关键结论 |
|---|---|---|---|
| [arithmetic_area面积对比总结.md](./arithmetic_area面积对比总结.md) | 整库对比：`arithmetic_unit_full` vs `arithmetic_unit_compact`（complex / real 版，MAC 与加法树） | 2026-09-03 | complex MAC 上 full 明显更省（DUT −9.7%，总 −8.7%，功耗 −13.5%）；纯加法树两者基本持平（<2%）；4 个 top @800MHz+20% 0 setup 违例。数据：`arithmetic_area_test/` |
| [G_PE_full_library面积对比总结.md](./G_PE_full_library面积对比总结.md) | 在 L_PJG 中把 PE 级算术换成完整库模块，以 **G_PE** 为例的前后综合对比 | 2026-09-05 | struct（compact）2434.57 → full_lib 2318.02（−4.8%）→ **fused（融合 complex_mac_w_bias）2166.57（−11.0%）**；三版 WNS/TNS=0、寄存器均 187；差分 VCS 验证 PASS（干净窗口逐位一致）。数据：`g_pe_area_test/` 与仓库 `L_PJG/g_pe_area_compare/` |
| [整机综合对比准备计划.md](./整机综合对比准备计划.md) | 整机（`detector`，528 G-阵列 MAC PE + 32 MF_PE）BEFORE/AFTER 综合对比的**准备计划** | 2026-09-07 | 定义 BEFORE（git HEAD compact）vs AFTER（fused 工作树）两版与 filelist 差异；选定流程方案 A（logic、no retime，与 PE 级同口径）；列出 RAM 映射等整机特有核查项与前置条件（先 0-LSB FC 通过再综合）；**尚未跑综合** |

## 演进关系（按时间）

1. **2026-09-03** `arithmetic_area` 整库摸底：full 相对 compact 的面积优势**主要来自复数 MAC**（乘法融合/合并网络），纯加法树几乎无差别 → 选定「在 L_PJG 中把算术模块换成 full」的方向。
2. **2026-09-05** `G_PE` 实例验证：在 L_PJG 的 PE（G_PE）上把 compact 三段算术替换为完整库模块并做前后综合对比；进一步构造 **G_PE_fused**（把两级 MAC 融合为 `complex_mac_w_bias` 全位宽+单次截位），面积从 struct 的 2434.57 降到 2166.57 µm²（−11.0%），并通过差分功能验证证明布线与功能等价。
3. 为兼容 EDA VCS2014，对 `arithmetic_unit/complex_mac.sv` 做了纯语义保持的 localparam 提升（hoist），DC 复跑面积逐字节一致。
4. **2026-09-06** 整机 fused FC 0-LSB 收敛：三份 fused golden 对旧 RTL 差 ±1 LSB，根因 = fused `complex_mac_w_bias` 反馈寄存器每拍截位（`G_reg` fp10 / `y_mf` fp8）与平台「整段单次截位」结构不符；Option A（平台 per-write 逐拍建模 golden，32/32 佐证根因）后，按用户批准走 **Option B**——把 `G_reg`/`y_mf` 加宽到 `complex_mac_w_bias` 内部 ACC3 全宽（`G_ACC_FULL_QTZ(1,10,12)` / `YMF_ACC_FULL_QTZ(1,13,11)`），整段扫描真正单次截位 → RTL 对 **gauss golden（`29cdbe71`）FC PASS 0/32（0-LSB）**。4 份 golden 与 run 脚本归档见 [fc_golden/](../fc_golden/)（含背景/语义对照表）。AFTER 综合范围 = 当前工作树（已含 Option B 寄存器加宽），整机综合对比仍未跑（先掌握流程）。

## 复现

- 整库对比：EDA `/home/asic03/graduate/proj_hujinjie/arithmetic_area_test/`（syn 各 run 目录 + 报告）
- G_PE 对比：仓库 [L_PJG/g_pe_area_compare/](../g_pe_area_compare/)（rtl/sim/syn 全套，含 config、filelist、差分 TB、轨迹）及 EDA `g_pe_area_test/`