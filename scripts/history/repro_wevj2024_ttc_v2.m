%% repro_wevj2024_ttc_v2.m
%  复现（续）：Lai, Liu, Hu (2024), WEVJ 15(6):259, DOI 10.3390/wevj15060259
%  2.1 节 TTC 四级控制 / CCRs 场景（30 km/h, 60 m, mu=1.0）
%
%  第一版按"字面阈值直接切换"实现，结果出现 TTC 抖动（减速到 ttc 回升→制动
%  关闭→再触发），车最终爬到间距 0。说明字面实现与论文报告（5.7 m / minTTC
%  1.6 s）不符。此处增加"触发后锁存"变体，检验能否复现论文数值。

clear; clc;
gRoad = 9.81; muRoad = 1.0;
v0 = 30/3.6; s0 = 60; dt = 0.001;

fprintf('=== A. 字面实现（无锁存，阈值直接切换）===\n');
[tS,tE,sE,aM,ttcM] = ttc_sim(v0,s0,dt,[0.10 0.20 0.30]*gRoad,gRoad,muRoad,false);
fprintf('介入 %.3f s | 停车 %.3f s | 最终间距 %.3f m | a_max %.2f g | minTTC %.2f s\n', tS,tE,sE,aM/gRoad,ttcM);

fprintf('\n=== B. 触发后锁存（一旦开始制动就不关闭）===\n');
rows = { [0.10 0.20 0.30], [0.15 0.30 0.45], [0.20 0.40 0.60], [0.30 0.30 0.30] };
nms  = {'0.10/0.20/0.30 g','0.15/0.30/0.45 g','0.20/0.40/0.60 g','0.30/0.30/0.30 g'};
for i=1:numel(rows)
  [tS,tE,sE,aM,ttcM] = ttc_sim(v0,s0,dt,rows{i}*gRoad,gRoad,muRoad,true);
  fprintf('%-20s 介入 %5.2f s | 停车 %5.2f s | 间距 %6.2f m | a_max %.2f g | minTTC %4.2f s\n', ...
          nms{i}, tS,tE,sE,aM/gRoad,ttcM);
end

fprintf('\n=== 论文报告值（3.2.1 CCRs, TTC 控制）===\n');
fprintf('介入 5.2 s | 停车间距 5.7 m | a_max ~0.3 g | minTTC 1.6 s\n');

function [tStart,tEnd,sEnd,aMax,ttcMin] = ttc_sim(v0,s0,dt,levels,gRoad,muRoad,latch)
  v=v0; s=s0; t=0; tStart=NaN; aMax=0; ttcMin=inf; active=false;
  while v>1e-6 && t<60
    ttc = s/max(v,1e-6);
    ttcMin = min(ttcMin, ttc);
    if latch && active
      % 保持上一档，不因 ttc 回升而释放
      if ttc>1.6, a=-levels(1); elseif ttc>0.7, a=-levels(2); else, a=-levels(3); end
    else
      if ttc>2.0, a=0;
      elseif ttc>1.6, a=-levels(1);
      elseif ttc>0.7, a=-levels(2);
      else, a=-levels(3);
      end
    end
    if a<0, active=true; if isnan(tStart), tStart=t; end, end
    a = max(a,-muRoad*gRoad);
    aMax = max(aMax,-a);
    f=@(y)[a;-y(1)]; y=[v;s];
    k1=f(y); k2=f(y+dt/2*k1); k3=f(y+dt/2*k2); k4=f(y+dt*k3);
    y=y+dt/6*(k1+2*k2+2*k3+k4);
    v=max(y(1),0); s=y(2); t=t+dt;
  end
  tEnd=t; sEnd=s;
end
