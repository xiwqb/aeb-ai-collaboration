# 论文与证据对应

| 论文位置 | 对应文件 |
|---|---|
| 2.2 模型与单位 | `data/model_configuration.json`、`models/` |
| 表2-1 协作阶段 | `docs/project_process.md` |
| 式3-1 所需减速度 | `models/AEB_S1.slx`与配置摘要 |
| 表4-1、图4-1 简化复现 | `data/reproduction/`、`scripts/reproduce_ccrs.py`、`results/figures/reproduction_ccrs.png` |
| 表4-2、图4-2 释放条件对照 | `data/cases/hold_50/`、`data/cases/release_50/`、`results/results_summary.csv` |
| 表4-3 初速扰动 | `data/cases/hold_45/`、`data/cases/hold_55/` |
| 零制动对照 | `data/cases/brake_zero_50/` |
| 4.4 通道一致性与重复性 | `scripts/verify_evidence.py`、`data/cases/hold_50_repeat/`及原始核验报告 |
| 讨论与结论边界 | `docs/verification.md`、`docs/literature_reproduction.md` |

本仓库为整理后的过程与证据归档。Git初次提交不代表整个项目过去所有操作的提交历史；未伪造逐次提交或逐字对话。原始记录经过的变换在`data/provenance.json`中说明。
