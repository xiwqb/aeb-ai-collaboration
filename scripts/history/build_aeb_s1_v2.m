%% build_aeb_s1_v2.m
%  完整重建 AEB_S1
%  判决律：所需减速度 a_req = v^2 / (2*(d - d0))，d0 = 2 m
%          用 Relay 做"带迟滞的触发"：a_req >= 5 m/s^2 触发，a_req <= 0.5 释放
%          触发后全力制动 9 m/s^2（原 TTC 分级表在阈值附近会来回抖，已去掉）
%          保底：d < 2 m 强制 9 m/s^2
%  执行层：Kp = 1.4 MPa/(m/s^2)，一阶液压滞后 0.05 s，限幅 0~14 MPa

mdl  = 'AEB_S1';
dir  = '<LOCAL_PROJECT>';
file = fullfile(dir, [mdl '.slx']);
SIM  = 'E:\carsim2024data1\simfile.sim';
SUB  = [mdl '/AEB Controller'];
AR   = {'autorouting','on'};
setp = @(b,p) set_param(b,'Position',p);

if bdIsLoaded(mdl), close_system(mdl, 0); end
if exist(file,'file'), delete(file); end
new_system(mdl);
save_system(mdl, file);

% ================= 1. CarSim 模块 =================
load_system('E:\carsim2024data1\Extensions\Simulink\abs_brake_slx.slx');
add_block('abs_brake_slx/CarSim S-Function', [mdl '/CarSim'], ...
    'SIMFILE', SIM, 'Position', [400 160 560 260]);
set_param([mdl '/CarSim'], 'SIMFILE', SIM);
set_param(mdl, 'SimulationCommand', 'update');

% ================= 2. 顶层 =================
add_block('simulink/Ports & Subsystems/Subsystem', SUB, 'Position', [90 240 330 420]);
add_block('simulink/Signal Routing/Demux', [mdl '/Demux'], 'Outputs','6','Position',[620  60 626 260]);
add_block('simulink/Signal Routing/Mux',   [mdl '/Mux'],   'Inputs','6', 'Position',[620 300 626 440]);
add_block('simulink/Sinks/To Workspace',   [mdl '/ToWs'], ...
    'VariableName','simout','SaveFormat','Structure With Time','Position',[700 350 770 400]);
add_block('simulink/Signal Routing/Goto', [mdl '/Goto_Vx'], ...
    'GotoTag','Vx_fb','TagVisibility','local','Position',[660  78 720  98]);
add_block('simulink/Signal Routing/Goto', [mdl '/Goto_Xo'], ...
    'GotoTag','Xo_fb','TagVisibility','local','Position',[660 138 720 158]);
add_block('simulink/Signal Routing/From', [mdl '/From_Vx'], ...
    'GotoTag','Vx_fb','Position',[ 30 285  80 305]);
add_block('simulink/Signal Routing/From', [mdl '/From_Xo'], ...
    'GotoTag','Xo_fb','Position',[ 30 355  80 375]);

% ================= 3. 子系统端口 =================
try, delete_line(SUB, 'In1/1', 'Out1/1'); catch, end
kids = find_system(SUB, 'SearchDepth', 1, 'Type', 'Block');
kids = setdiff(kids, {SUB});
for k = 1:numel(kids)
    try, delete_block(kids{k}); catch, end
end
add_block('simulink/Sources/In1', [SUB '/Vx'],   'Port','1','Position',[ 40  40  65  54]);
add_block('simulink/Sources/In1', [SUB '/Xo'],   'Port','2','Position',[ 40 200  65 214]);
add_block('simulink/Sinks/Out1',  [SUB '/P'],    'Port','1','Position',[1120 165 1145 179]);
add_block('simulink/Sinks/Out1',  [SUB '/d'],    'Port','2','Position',[ 560  80  585  94]);
add_block('simulink/Sinks/Out1',  [SUB '/areq'], 'Port','3','Position',[ 560 280  585 294]);

% ================= 4. 子系统内部 =================
add_block('simulink/Math Operations/Gain', [SUB '/kmh2mps'], 'Gain','1/3.6','Position',[105  32 145  62]);
add_block('simulink/Discontinuities/Saturation', [SUB '/Vlow'], ...
    'UpperLimit','inf','LowerLimit','0.5','Position',[175  32 215  62]);
add_block('simulink/Math Operations/Math Function', [SUB '/Sq'], ...
    'Function','square','Position',[245  30 275  65]);

add_block('simulink/Sources/Constant', [SUB '/Xobs'], 'Value','50','Position',[ 40 130  90 160]);
add_block('simulink/Math Operations/Sum', [SUB '/SumD'], 'Inputs','+-','Position',[135 155 165 185]);
add_block('simulink/Sources/Constant', [SUB '/d0'], 'Value','2','Position',[210 210 240 240]);
add_block('simulink/Math Operations/Sum', [SUB '/SumD0'], 'Inputs','+-','Position',[210 160 240 190]);
add_block('simulink/Discontinuities/Saturation', [SUB '/SatD'], ...
    'UpperLimit','inf','LowerLimit','0.5','Position',[280 160 320 190]);
add_block('simulink/Math Operations/Gain', [SUB '/GainD'], 'Gain','2','Position',[350 160 390 190]);

add_block('simulink/Math Operations/Divide', [SUB '/DivReq'], 'Position',[450 120 480 200]);
add_block('simulink/Discontinuities/Saturation', [SUB '/SatReq'], ...
    'UpperLimit','9','LowerLimit','0','Position',[520 160 560 190]);
add_block('simulink/Discontinuities/Relay', [SUB '/Trig'], ...
    'OnSwitchValue','5','OffSwitchValue','0.5', ...
    'OnOutputValue','1','OffOutputValue','0','Position',[610 158 650 192]);
add_block('simulink/Math Operations/Gain', [SUB '/Gfull'], 'Gain','9', 'Position',[690 160 730 190]);

add_block('simulink/Sources/Constant', [SUB '/dHold'], 'Value','2','Position',[210 320 240 350]);
add_block('simulink/Logic and Bit Operations/Relational Operator', [SUB '/Near'], ...
    'Operator','<','Position',[280 315 320 345]);
add_block('simulink/Sources/Constant', [SUB '/aHold'], 'Value','9','Position',[350 320 390 350]);
add_block('simulink/Math Operations/Product', [SUB '/Hold'], ...
    'Inputs','2','Position',[430 310 460 360]);

add_block('simulink/Math Operations/MinMax', [SUB '/MaxA'], ...
    'Function','max','Inputs','2','Position',[770 150 810 210]);
add_block('simulink/Math Operations/Gain', [SUB '/Kp'], 'Gain','1.4','Position',[850 160 890 190]);
add_block('simulink/Discontinuities/Saturation', [SUB '/Psat'], ...
    'UpperLimit','14','LowerLimit','0','Position',[930 160 970 190]);
add_block('simulink/Continuous/Transfer Fcn', [SUB '/Hyd'], ...
    'Numerator','[1]','Denominator','[0.05 1]','Position',[1010 155 1080 190]);

% ================= 5. 子系统连线 =================
add_line(SUB,'Vx/1','kmh2mps/1',AR{:});
add_line(SUB,'kmh2mps/1','Vlow/1',AR{:});
add_line(SUB,'Vlow/1','Sq/1',AR{:});
add_line(SUB,'Xobs/1','SumD/1',AR{:});
add_line(SUB,'Xo/1','SumD/2',AR{:});
add_line(SUB,'SumD/1','SumD0/1',AR{:});
add_line(SUB,'d0/1','SumD0/2',AR{:});
add_line(SUB,'SumD0/1','SatD/1',AR{:});
add_line(SUB,'SatD/1','GainD/1',AR{:});
add_line(SUB,'Sq/1','DivReq/1',AR{:});
add_line(SUB,'GainD/1','DivReq/2',AR{:});
add_line(SUB,'DivReq/1','SatReq/1',AR{:});
add_line(SUB,'SatReq/1','Trig/1',AR{:});
add_line(SUB,'Trig/1','Gfull/1',AR{:});
add_line(SUB,'SumD/1','Near/1',AR{:});
add_line(SUB,'dHold/1','Near/2',AR{:});
add_line(SUB,'Near/1','Hold/1',AR{:});
add_line(SUB,'aHold/1','Hold/2',AR{:});
add_line(SUB,'Gfull/1','MaxA/1',AR{:});
add_line(SUB,'Hold/1','MaxA/2',AR{:});
add_line(SUB,'MaxA/1','Kp/1',AR{:});
add_line(SUB,'Kp/1','Psat/1',AR{:});
add_line(SUB,'Psat/1','Hyd/1',AR{:});
add_line(SUB,'Hyd/1','P/1',AR{:});
add_line(SUB,'SumD/1','d/1',AR{:});
add_line(SUB,'SatReq/1','areq/1',AR{:});

% ================= 6. 顶层连线 =================
add_line(mdl,'From_Vx/1','AEB Controller/1',AR{:});
add_line(mdl,'From_Xo/1','AEB Controller/2',AR{:});
add_line(mdl,'AEB Controller/1','CarSim/1',AR{:});
add_line(mdl,'CarSim/1','Demux/1',AR{:});
add_line(mdl,'Demux/1','Goto_Vx/1',AR{:});
add_line(mdl,'Demux/3','Goto_Xo/1',AR{:});
add_line(mdl,'Demux/1','Mux/1',AR{:});
add_line(mdl,'Demux/2','Mux/2',AR{:});
add_line(mdl,'Demux/3','Mux/3',AR{:});
add_line(mdl,'AEB Controller/2','Mux/4',AR{:});
add_line(mdl,'AEB Controller/3','Mux/5',AR{:});
add_line(mdl,'AEB Controller/1','Mux/6',AR{:});
add_line(mdl,'Mux/1','ToWs/1',AR{:});

set_param(mdl, 'StopTime','10','Solver','ode45','MaxStep','0.01');
save_system(mdl);
fprintf('V2 BUILD OK\n');
