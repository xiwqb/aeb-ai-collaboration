# 运行与复核

## 仅复核已公开记录

在仓库根目录运行：

```bash
python -m pip install -r requirements.txt
python scripts/verify_evidence.py
python scripts/reproduce_ccrs.py
```

前一个脚本使用六组完整采样数据和原生通道，不调用CarSim或MATLAB；后一个脚本独立实现已保存MATLAB脚本的CCRs数值核，检验触发时刻与停车间距，结果写入`results/recomputed/`。

`signals.csv.gz`与`trigger.csv.gz`是原始导出的无损压缩副本，无表头。前者的列依次为时间s、Vx km/h、Ax g、Xo m、坐标间距m、所需减速度m/s²、压力MPa。后者为时间s及Relay输出。原生通道在`native_selected.npz`中，`values`的列为Vx、Ax、Xo、Pbk_Con，保持原始float32数值。全690通道档案按115列一块保存；通道名称和单位见相邻JSON。

## 重新运行CarSim与Simulink

需要有可用的CarSim 2024.0、MATLAB/Simulink R2024a及相应车辆数据库。本仓库包含冻结Simulink模型和参数摘要，不包含商用数据库、求解器或许可证。

1. 依据`data/model_configuration.json`在自己的CarSim数据库创建直道停车工况，并设置两个导入与六个导出通道。
2. 使用自己的数据库导出有效`simfile.sim`和展开参数。保留原始输出，确认各组速度设定实际被读取。
3. 在`local_runs/`新建隔离目录，复制`models/AEB_Verify.slx`，配置各案例的本地`simfile`、`parsfile`路径，形成包含`id/speed_kmh/off_threshold/kp/role/simfile/parsfile`的`cases.json`。
4. 将`scripts/`加入MATLAB路径，调用`run_one_case('hold_50', '你的隔离目录绝对路径')`。模型内部S-Function仍需绑定自己的CarSim求解器环境。
5. 分别运行六组工况，检查本地原生输出、外推警告、车型回读和指标。不同数据库、车型标定及软件版本可能产生不同数值，不能只靠匹配终值判断重跑成功。

`scripts/history/`保留早期脚本，含明显的`<LOCAL_PROJECT>`路径占位符，仅供理解修改过程。它们不是当前冻结模型的权威生成入口，不应未经核对直接覆盖现有工程。
