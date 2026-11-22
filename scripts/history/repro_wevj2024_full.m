%% repro_wevj2024_full.m
%  复现：Lai, Liu, Hu (2024), WEVJ 15(6):259, DOI 10.3390/wevj15060259
%  对象：2.1 节 TTC 四级控制、2.2 节二次曲线减速控制（Quad）
%  场景：乘用车 CCRs / CCRm / CCRb（Table 1）
%  模型：点质量 + RK4，dt = 0.001 s（论文 3.1 节）
%
%  参数说明（论文未给出，见正文"完全复现的缺口"）：
%   - TTC 三档减速度：论文只画了 Slight/Medium/Complete brake，无数值。
%     本脚本按 0.10/0.20/0.30 g 取（与论文报告的 CCRs 峰值 0.3 g 一致）。
%   - Quad 的目标停车间距 d_safe：论文未给，本脚本按报告值 2.0 m 取。

clear; clc;
g = 9.81;

%% ---------- 算法：TTC 四级（含触发锁存） ----------
function a = ttc_accel(ttc, lv)
  if ttc > 2.0,      a = 0;
  elseif ttc > 1.6,  a = -lv(1);
  elseif ttc > 0.7,  a = -lv(2);
  else,              a = -lv(3);
  end
end

%% ---------- 算法：Quad（a(t) = -k*(t-tb)，jerk 恒定） ----------
%  边界：v(tf)=0, s(tf)=d_safe  →  解出 k 与 tf
function [k, tf] = quad_solve(vb, sb, dsafe)
  % 设 tau = tf-tb，则 v(tf)=vb - k*tau^2/2 = 0  → k = 2*vb/tau^2
  % s 减少量 = vb*tau - k*tau^3/6 = sb - dsafe
  % 代入 k：vb*tau - (2 vb/tau^2)*tau^3/6 = vb*tau*(1-1/3) = (2/3) vb tau
  % 所以 (2/3) vb tau = sb - dsafe
  dneed = sb - dsafe;
  if dneed <= 0, k = 0; tf = 0; return; end
  tf = 1.5 * dneed / vb;
  k  = 2 * vb / tf^2;
end

%% ---------- 仿真主体 ----------
function R = simulate(scen, alg, g, lv, dsafe)
  dt = 0.001; t = 0;
  v = scen.vF; s = scen.xr;
  vL = scen.vL; aL = scen.aL; tLead = 2.0;
  tStart = NaN; aMax = 0; ttcMin = inf; latched = false;
  kq = 0; tf_q = 0; tb_q = NaN; quadInit = false;

  while v > 1e-6 && s > 0 && t < 60
    if t >= tLead
      vL_now = max(vL + aL*(t - tLead), 0);
    else
      vL_now = vL;
    end
    vr = v - vL_now;
    if vr > 1e-6
      ttc = s / vr;
    else
      ttc = inf;
    end
    ttcMin = min(ttcMin, ttc);

    switch alg
      case 'TTC'
        a = ttc_accel(ttc, lv);
        if a < 0, latched = true; end
        if latched && a == 0, a = -lv(1); end      % 锁存：不因 ttc 回升释放
      case 'Quad'
        if ~quadInit && ttc <= 2.0
          quadInit = true; tb_q = t;
          [kq, tf_q] = quad_solve(v, s, dsafe);
        end
        if quadInit
          tau = t - tb_q;
          a = -kq * max(tau, 0);
          if tau >= tf_q, a = 0; end
        else
          a = 0;
        end
    end

    if a < 0 && isnan(tStart), tStart = t; end
    aMax = max(aMax, -a);

    f  = @(y) [a; -(y(1) - vL_now)];         % y=[v; s]，s 按相对速度收敛
    y  = [v; s];
    k1 = f(y); k2 = f(y+dt/2*k1); k3 = f(y+dt/2*k2); k4 = f(y+dt*k3);
    y  = y + dt/6*(k1+2*k2+2*k3+k4);
    v = max(y(1), 0); s = y(2); t = t + dt;

    if v <= 1e-6, break; end
  end
  R = struct('tStart', tStart, 'gap', s, 'aMax', aMax/g, 'ttcMin', ttcMin, 'tEnd', t);
end

%% ---------- 场景（Table 1） ----------
S(1) = struct('name','CCRs', 'vF',30/3.6, 'vL',0,        'aL',0, 'xr',60);
S(2) = struct('name','CCRm', 'vF',50/3.6, 'vL',20/3.6,   'aL',0, 'xr',120);
S(3) = struct('name','CCRb', 'vF',50/3.6, 'vL',50/3.6,   'aL',-4,'xr',40);

lv = [0.10 0.20 0.30] * g;     % TTC 三档（假设值）
dsafe = 2.0;                   % Quad 目标间距（按报告值取）

%% ---------- 论文报告值 ----------
paper = struct();
paper.TTC  = [5.70 5.77 2.36];
paper.Quad = [2.00 2.00 1.92];
paper.TTC_t   = [5.20 12.40 4.90];
paper.Quad_t  = [5.57 12.77 4.13];
paper.TTC_ttc = [1.60 1.60 0.97];
paper.Quad_ttc= [2.38 2.89 0.75];
paper.TTC_a   = [0.30 NaN NaN];
paper.Quad_a  = [0.40 NaN NaN];

fprintf('%-6s %-5s %8s %8s %8s %8s\n','场景','算法','间距m','论文m','介入s','论文s');
fprintf('%s\n', repmat('-',1,56));
for i = 1:3
  rt = simulate(S(i), 'TTC',  g, lv, dsafe);
  rq = simulate(S(i), 'Quad', g, lv, dsafe);
  fprintf('%-6s %-5s %8.2f %8.2f %8.2f %8.2f\n', S(i).name,'TTC', rt.gap, paper.TTC(i),  rt.tStart, paper.TTC_t(i));
  fprintf('%-6s %-5s %8.2f %8.2f %8.2f %8.2f\n', S(i).name,'Quad',rq.gap, paper.Quad(i), rq.tStart, paper.Quad_t(i));
end

fprintf('\n细节（minTTC / a_max）:\n');
for i = 1:3
  rt = simulate(S(i), 'TTC',  g, lv, dsafe);
  rq = simulate(S(i), 'Quad', g, lv, dsafe);
  fprintf('%s TTC : minTTC %.2f (论文 %.2f) | a_max %.2f g\n', S(i).name, rt.ttcMin, paper.TTC_ttc(i),  rt.aMax);
  fprintf('%s Quad: minTTC %.2f (论文 %.2f) | a_max %.2f g\n', S(i).name, rq.ttcMin, paper.Quad_ttc(i), rq.aMax);
end
