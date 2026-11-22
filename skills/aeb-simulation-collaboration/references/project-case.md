# AEB项目案例与证据入口

## 案例摘要

项目把静止目标前的单次停车拆成接口确认、模型实现、异常定位、针对性实验和结果核验。AI承担模型、脚本与运行整理；研究者的关键判断落在可验收目标、证据选择、对照设计及结论取舍。

当前配置是由C-Class模板调整的BMW X3 xDrive 25i参数化模型，簧载质量回读1674 kg，部分子系统仍为通用部件。它不是X5实验，也不代表完成实车标定。早期说明中的8.36 m结果不作为当前基线，当前基线约为6.7281 m。

案例设定：50 m目标坐标，间距定义为`50−Xo`，控制器预留2 m，仿真10 s；名义停车为首次车速不高于0.5 km/h，不等于停车后无残余运动。

## 本案例实际采用的实验

| 记录 | 改变的条件 | 核验作用与结果 |
|---|---|---|
| hold_50 | 50 km/h基线，Relay释放阈值−1 | 触发2.0712 s，名义停车4.0825 s，最小间距6.728096 m，切换1次 |
| release_50 | 仅把释放阈值改为4.9 | 相同触发时刻，名义停车4.9554 s，间距1.725811 m，切换12次 |
| hold_45 | 初速45 km/h | 触发2.5927 s，间距5.748947 m |
| hold_55 | 初速55 km/h | 触发1.6185 s，间距7.823071 m |
| brake_zero_50 | 压力增益归零，保留触发与断油门 | 10 s车速44.118462 km/h，Xo为132.292923 m，未停车 |
| hold_50_repeat | 与基线配置相同 | 687个非计时原生通道和全部Simulink输出逐点相同；3个实际耗时通道不同 |

保持与释放对照使用相同的所需减速度触发条件，不是历史TTC控制器的前后比较。负释放阈值用于该单次停车保持工况，不能作为完整AEB退出策略推广。

本例原生Vx为km/h、Ax为g，采样周期0.0001 s，每组100001点。观察到Vx与Xo同索引对应；`native_Ax[k]=simulink_Ax[k+1]`，`native_pressure[k+1]=simulink_pressure[k]`。对齐后残差小于10⁻⁵，速度积分与位移变化的差小于0.0006 m。原始记录含参数表外推警告，不能由接口一致性推出独立物理验证。

文献点质量CCRs简化复现采用30 km/h、60 m和0.001 s步长，加入保持逻辑且包含补充档位假设。介入5.201 s接近原文约5.2 s，停车间距3.549 m与原文约5.7 m不同；本次未进入更高减速度档位，结论仍是存在偏差的简化复现。

## 证据与执行位置

仓库：<https://github.com/xiwqb/aeb-ai-collaboration>。论文采用的证据固定在[paper-v1](https://github.com/xiwqb/aeb-ai-collaboration/tree/paper-v1)。

如果已获得该仓库，在其根目录按需读取：

- `docs/project_process.md`：工程过程与关键判断。
- `docs/verification.md`：核验方法与适用边界。
- `data/model_configuration.json`、`data/cases.json`：实际设定与实验矩阵。
- `data/cases/`：完整采样记录及原生通道。
- `results/verification/original_audit.json`：指标、残差及外推警告。
- `docs/literature_reproduction.md`：文献复现假设和未匹配结果。
- `docs/reproduce.md`：记录复核及有商业软件环境时的重跑步骤。

在确认当前目录为上述仓库根目录且已安装其`requirements.txt`依赖后，可按需执行：

```bash
python scripts/verify_evidence.py
python scripts/reproduce_ccrs.py
```

两个命令会在`results/recomputed/`写入复核结果，不运行CarSim、不开启新实验。复制skill目录后，仓库数据与这些脚本不会自动随附；从用户提供或允许访问的项目位置取用，缺失时明确可复核范围。
