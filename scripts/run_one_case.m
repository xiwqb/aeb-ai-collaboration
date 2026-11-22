function result = run_one_case(caseId, root)
% Run exactly one isolated CarSim/Simulink experiment through the live MCP session.
assert(nargin==2,'Pass an isolated local run directory containing cases.json and AEB_Verify.slx.');
cases = jsondecode(fileread(fullfile(root,'cases.json')));
idx = find(strcmp({cases.id},caseId),1);
assert(~isempty(idx),'Unknown case');
c = cases(idx); folder = fullfile(root,caseId);
assert(~exist(fullfile(folder,'metrics.json'),'file'),'Case already completed; preserve evidence.');
mdl = 'AEB_Verify';
if ~bdIsLoaded(mdl), load_system(fullfile(root,[mdl '.slx'])); end
assert(strcmp(get_param(mdl,'SimulationStatus'),'stopped'));
sub = [mdl '/AEB Controller'];
set_param([mdl '/CarSim'],'SIMFILE',c.simfile);
set_param([sub '/Trig'],'OnSwitchValue','5','OffSwitchValue',num2str(c.off_threshold,17));
set_param([sub '/Kp'],'Gain',num2str(c.kp,17));
set_param([sub '/kmh2mps'],'Gain','1/3.6');
set_param([sub '/Xobs'],'Value','50');
set_param(mdl,'StopTime','10','ReturnWorkspaceOutputs','on');
sink = [sub '/VerifyTrigger'];
if getSimulinkBlockHandle(sink)<0
    add_block('simulink/Sinks/To Workspace',sink,'VariableName','verify_trigger', ...
        'SaveFormat','Structure With Time','Position',[680 20 770 55]);
    add_line(sub,'Trig/1','VerifyTrigger/1','autorouting','on');
end
config = struct('case',c,'matlab',version,'model',get_param(mdl,'FileName'), ...
    'solver',get_param(mdl,'Solver'),'max_step',get_param(mdl,'MaxStep'), ...
    'simfile',get_param([mdl '/CarSim'],'SIMFILE'),'started',char(datetime('now')));
write_json(fullfile(folder,'configuration.json'),config);
save_system(mdl);
copyfile(get_param(mdl,'FileName'),fullfile(folder,[mdl '.slx']),'f');
fprintf('START %s %s\n',caseId,config.started);
clockStart=tic;
try
    out=sim(mdl,'TimeOut',120);
    s=out.get('simout');
    if isa(s,'timeseries'), t=s.Time; Y=s.Data; else, t=s.time;Y=s.signals.values;end
    tr=out.get('verify_trigger');
    if isa(tr,'timeseries'), trig_t=tr.Time;trig_y=tr.Data;else,trig_t=tr.time;trig_y=tr.signals.values;end
    Y=squeeze(Y);trig_y=squeeze(trig_y);
    save(fullfile(folder,'raw_simulink.mat'),'t','Y','trig_t','trig_y','config','-v7');
    writematrix([t Y],fullfile(folder,'signals.csv'));
    writematrix([trig_t trig_y],fullfile(folder,'trigger.csv'));
    k=find(Y(:,1)<=0.5,1); if isempty(k), stopTime=NaN;else,stopTime=t(k);end
    kTrig=find(trig_y>0.5,1);if isempty(kTrig),triggerTime=NaN;else,triggerTime=trig_t(kTrig);end
    late=t>=6;
    result=struct('id',caseId,'status','completed','elapsed_s',toc(clockStart), ...
        'initial_v_kmh',Y(1,1),'final_v_kmh',Y(end,1),'min_gap_m',min(Y(:,4)), ...
        'stop_time_s',stopTime,'trigger_time_s',triggerTime,'final_x_m',Y(end,3), ...
        'peak_pressure_MPa',max(Y(:,6)),'peak_decel_g',-min(Y(:,2)), ...
        'relay_switch_count',sum(abs(diff(trig_y))>0.5), ...
        'pressure_crossings_1MPa',sum(diff(Y(:,6)>1)~=0), ...
        'late_v_abs_max_kmh',max(abs(Y(late,1))), ...
        'speed_integral_m',trapz(t,Y(:,1)/3.6),'sample_count',numel(t), ...
        'finished',char(datetime('now')));
    write_json(fullfile(folder,'metrics.json'),result);
    disp(jsonencode(result));
catch err
    failure=struct('id',caseId,'status','failed','elapsed_s',toc(clockStart), ...
        'identifier',err.identifier,'message',err.message,'report',getReport(err,'extended','hyperlinks','off'));
    write_json(fullfile(folder,'failure.json'),failure);
    rethrow(err);
end
end

function write_json(path,data)
fid=fopen(path,'w');assert(fid>=0,'Cannot write output');
fwrite(fid,jsonencode(data),'char');fclose(fid);
end
