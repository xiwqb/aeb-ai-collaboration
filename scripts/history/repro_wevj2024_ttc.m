%% repro_wevj2024_ttc.m
%  复现：Lai, Liu, Hu (2024), "An Automatic Emergency Braking Control Method
%  for Improving Ride Comfort", World Electr. Veh. J. 15(6):259.
%  DOI: 10.3390/wevj15060259
%
%  复现对象：论文 2.1 节 "TTC Control Algorithm"（四级 TTC 制动）
%  场景：CCRs（前车静止），vF=30 km/h，vL=0，初始间距 60 m，路面 mu=1.0
%  模型：点质量模型，ode4 定步长 0.001 s（与论文 3.1 节描述一致）
%
%  【说明】论文正文只给出四个 TTC 阈值（2.0 / 1.6 / 0.7 s），三档减速度的
%  具体数值在 Figure 1 中、正文未给。本脚本按 0.1g / 0.2g / 0.3g 实现，
%  并做敏感性对比，不把"调参凑数"当"复现"。

clear; clc;

gRoad = 9.81;
muRoad = 1.0;          % 高附着路面（论文 3.1 节）
v0 = 30/3.6;           % 8.333 m/s
s0 = 60;               % m
dt = 0.001;

levels0 = [0.10 0.20 0.30] * gRoad;   % 假设值

[tS, tE, sE, aM, ttcM] = run_ttc(v0, s0, dt, levels0, gRoad, muRoad);

fprintf('=== 复现结果：TTC 四级控制 / CCRs (30 km/h, 60 m) ===\n');
fprintf('AEB 介入时刻       : %.3f s\n', tS);
fprintf('停车时刻           : %.3f s\n', tE);
fprintf('最终间距           : %.3f m\n', sE);
fprintf('最大减速度         : %.3f m/s2  (%.3f g)\n', aM, aM/gRoad);
fprintf('最小 TTC           : %.3f s\n', ttcM);

fprintf('\n=== 论文报告值（2.1 与 3.2.1 节）===\n');
fprintf('AEB 介入时刻       : 5.2 s\n');
fprintf('最终间距（停车距离）: 5.7 m\n');
fprintf('最大减速度         : ~0.3 g\n');
fprintf('最小 TTC           : 1.6 s\n');

fprintf('\n=== 敏感性：三档减速度不同取值 ===\n');
cands = {[0.10 0.20 0.30], [0.15 0.30 0.45], [0.20 0.40 0.60], [0.05 0.10 0.30], [0.30 0.30 0.30]};
names = {'0.10/0.20/0.30 g（默认假设）','0.15/0.30/0.45 g','0.20/0.40/0.60 g','0.05/0.10/0.30 g','0.30/0.30/0.30 g（单级）'};
for i = 1:numel(cands)
  L = cands{i} * gRoad;
  [tS2, ~, sE2, aM2, ttcM2] = run_ttc(v0, s0, dt, L, gRoad, muRoad);
  fprintf('%-28s 介入 %5.2f s | 间距 %6.2f m | a_max %.2f g | minTTC %4.2f s\n', ...
          names{i}, tS2, sE2, aM2/gRoad, ttcM2);
end

% ---------------- local function ----------------
function [tStart, tEnd, sEnd, aMax, ttcMin] = run_ttc(v0, s0, dt, levels, gRoad, muRoad)
  v = v0; s = s0; t = 0;
  tStart = NaN; aMax = 0; ttcMin = inf;

  while v > 1e-6 && t < 60
    ttc = s / max(v, 1e-6);
    ttcMin = min(ttcMin, ttc);
    if ttc > 2.0
      a = 0;
    elseif ttc > 1.6
      a = -levels(1);
    elseif ttc > 0.7
      a = -levels(2);
    else
      a = -levels(3);
    end
    a = max(a, -muRoad*gRoad);            % 附着上限

    if a < 0 && isnan(tStart), tStart = t; end
    aMax = max(aMax, -a);

    % RK4 一步，状态 y = [v; s]，dv/dt = a，ds/dt = -v
    f  = @(y) [a; -y(1)];
    y  = [v; s];
    k1 = f(y);
    k2 = f(y + dt/2*k1);
    k3 = f(y + dt/2*k2);
    k4 = f(y + dt*k3);
    y  = y + dt/6*(k1 + 2*k2 + 2*k3 + k4);

    v = max(y(1), 0);
    s = y(2);
    t = t + dt;
  end

  tEnd = t; sEnd = s;
end
