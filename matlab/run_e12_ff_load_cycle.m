function report = run_e12_ff_load_cycle(maxStep,label,stopTime,ffGain,lpfHz)
% E1.2: Stage 5i load cycle with estimated load-current feedforward in the
% outer voltage loop.  MATLAB R2018b.
%
% Source = the exact tested Stage 5i load-cycle model (never modified here):
%   validation_outputs/stage5i_load_cycle/vsg_stage5i_load_cycle.tested_nominal.slx
% Built copy  = validation_outputs/e12_ff_load_cycle/vsg_e12_ff_load_cycle.slx
%
% Added controller path (10 kHz, same sampled signals as the original loops):
%   io_d_est = LPF(i_L_d) + w_s*Cf*V_load_q      (steady Cf branch current removed)
%   io_q_est = LPF(i_L_q) - w_s*Cf*V_load_d
%   i_d_ref  = PI_V_d + ff_gain*io_d_est,  i_q_ref = PI_V_q + ff_gain*io_q_est
% LPF: first-order backward-Euler, K = wc*Ts/(1+wc*Ts) (same form as the P/Q LPF).
% No new sensors: uses i_L (V1-V3) and V_load (V4-V6) already measured.
% ff_gain = 0 must reproduce the original model (equivalence smoke check).
if nargin<1; maxStep=2.5e-6; end
if nargin<2; label='nominal'; end
if nargin<3; stopTime=11; end
if nargin<4; ffGain=1; end
if nargin<5; lpfHz=1000; end
validateattributes(maxStep,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(ffGain,{'numeric'},{'scalar','real','finite','>=',0,'<=',1.5});
validateattributes(lpfHz,{'numeric'},{'scalar','real','finite','positive'});
assert(ischar(label) && ~isempty(regexp(label,'^[a-zA-Z0-9_]+$','once')));
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','e12_ff_load_cycle');
if ~exist(folder,'dir'); mkdir(folder); end
source=fullfile(root,'validation_outputs','stage5i_load_cycle','vsg_stage5i_load_cycle.tested_nominal.slx');
model='vsg_e12_ff_load_cycle';
modelPath=fullfile(folder,[model '.slx']);
sourceHash=fileHash(source);
assert(~bdIsLoaded(model),'E1.2 model is already open; use an isolated MATLAB process.');
oldPath=path;
pathCleanup=onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(folder);
if exist(modelPath,'file'); vsg_backup_output(modelPath); end
copyfile(source,modelPath);
load_system(modelPath);
closeCleanup=onCleanup(@() close_system(model,0)); %#ok<NASGU>

Ts=1e-4; Cf=10e-6; ws=2*pi*50;
K=(2*pi*lpfHz*Ts)/(1+2*pi*lpfHz*Ts);
mw=get_param(model,'ModelWorkspace');
assignin(mw,'e12_ff_gain',ffGain);
assignin(mw,'e12_lpf_K',K);
assignin(mw,'e12_wCf',ws*Cf);

axs={'d','q'};
crossTag={'V_load_q','V_load_d'};   % d uses +wCf*vq, q uses -wCf*vd
crossSign={'++','+-'};
y0=[700 930];
for k=1:2
    ax=axs{k};
    piBlk=[model '/PI_V_' ax];
    gotoBlk=[model '/Goto_i' ax 'ref'];
    assert(strcmp(get_param(gotoBlk,'GotoTag'),['i_' ax '_ref']),'Unexpected i_ref Goto tag.');
    piPorts=get_param(piBlk,'PortHandles');
    oldLine=get_param(piPorts.Outport,'Line');
    dst=get_param(oldLine,'DstBlockHandle');
    assert(numel(dst)==1 && strcmp(getfullname(dst),gotoBlk),'PI_V output must feed only the i_ref Goto.');
    delete_line(oldLine);
    set_param(gotoBlk,'Position',[900 y0(k)+84 1010 y0(k)+116]);
    y=y0(k)-120;
    fil=add_block('built-in/From',[model '/E12_From_iL' ax],'GotoTag',['i_L_' ax], ...
        'Position',[240 y 330 y+24]);
    lpf=add_block('built-in/DiscreteTransferFcn',[model '/E12_LPF_iL' ax], ...
        'Numerator','[e12_lpf_K 0]','Denominator','[1 e12_lpf_K-1]','SampleTime',num2str(Ts), ...
        'Position',[360 y-5 470 y+29]);
    fv=add_block('built-in/From',[model '/E12_From_' crossTag{k}],'GotoTag',crossTag{k}, ...
        'Position',[240 y+45 330 y+69]);
    gc=add_block('built-in/Gain',[model '/E12_wCf_' ax],'Gain','e12_wCf', ...
        'Position',[380 y+42 450 y+72]);
    sio=add_block('built-in/Sum',[model '/E12_io_' ax '_est'],'Inputs',crossSign{k}, ...
        'Position',[500 y 530 y+60]);
    gf=add_block('built-in/Gain',[model '/E12_ff_gain_' ax],'Gain','e12_ff_gain', ...
        'Position',[570 y+15 640 y+45]);
    sref=add_block('built-in/Sum',[model '/E12_iref_' ax '_sum'],'Inputs','++', ...
        'Position',[800 y0(k)+70 830 y0(k)+130]);
    tw=add_block('built-in/ToWorkspace',[model '/E12_Log_io_' ax],'VariableName',['e12_io_' ax '_ts'], ...
        'SaveFormat','Timeseries','MaxDataPoints','inf','SampleTime',num2str(Ts), ...
        'Position',[680 y-40 820 y-10]);
    hFil=get_param(fil,'PortHandles'); hLpf=get_param(lpf,'PortHandles');
    hFv=get_param(fv,'PortHandles'); hGc=get_param(gc,'PortHandles');
    hSio=get_param(sio,'PortHandles'); hGf=get_param(gf,'PortHandles');
    hRef=get_param(sref,'PortHandles'); hTw=get_param(tw,'PortHandles');
    hGoto=get_param(gotoBlk,'PortHandles');
    add_line(model,hFil.Outport,hLpf.Inport,'autorouting','on');
    add_line(model,hLpf.Outport,hSio.Inport(1),'autorouting','on');
    add_line(model,hFv.Outport,hGc.Inport,'autorouting','on');
    add_line(model,hGc.Outport,hSio.Inport(2),'autorouting','on');
    add_line(model,hSio.Outport,hGf.Inport,'autorouting','on');
    add_line(model,hSio.Outport,hTw.Inport,'autorouting','on');
    add_line(model,piPorts.Outport,hRef.Inport(1),'autorouting','on');
    add_line(model,hGf.Outport,hRef.Inport(2),'autorouting','on');
    add_line(model,hRef.Outport,hGoto.Inport,'autorouting','on');
end
note=Simulink.Annotation([model '/E1.2 estimated load-current feedforward: LPF i_L plus-minus wCf v into i_dq_ref']);
note.Position=[240 430 700 450];
% Memory: the first 11 s attempt (2026-11-10 01:02) crashed MATLAB with heap
% corruption 0xc0000374 at end-of-run log finalisation. Save the two 200 kHz
% V/I logs as plain arrays instead of Timeseries (same samples, no transpose).
hiRate=find_system(model,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace');
for k=1:numel(hiRate)
    if any(strcmp(get_param(hiRate{k},'VariableName'),{'Vload_abc_ts','iload_abc_ts'}))
        set_param(hiRate{k},'SaveFormat','Structure With Time');
    end
end
set_param(model,'StopTime','11','MaxStep',num2str(maxStep,16), ...
    'ReturnWorkspaceOutputs','on','SaveTime','off','SaveOutput','off', ...
    'SaveState','off','SignalLogging','off');
save_system(model,modelPath);
modelHash=fileHash(modelPath);
runnerHash=fileHash([mfilename('fullpath') '.m']);
fprintf('E12_FF_BUILT: %s (ff_gain=%g, lpf=%g Hz, K=%.6f)\n',modelPath,ffGain,lpfHz,K);

in=Simulink.SimulationInput(model);
in=in.setModelParameter('StopTime',num2str(stopTime,16),'MaxStep',num2str(maxStep,16), ...
    'ReturnWorkspaceOutputs','on');
tic;
out=sim(in);
elapsed=toc;
vars={'Vload_abc_ts','iload_abc_ts','sec_freq_Hz_ts','P_ts','Q_ts', ...
    'sec_P_ref_pu_ts','sec_delta_P_pu_ts','sec_clamp_state_ts','load_command_ts', ...
    'e12_io_d_ts','e12_io_q_ts'};
names={'Vload_abc','iload_abc','freq','P_meas','Q_meas', ...
    'sec_P_ref_pu','sec_delta_P_pu','sec_clamp_state','load_command','io_d_est','io_q_est'};
signals=struct();
for k=1:numel(names)
    ts=out.get(vars{k});
    if isstruct(ts)
        tt=ts.time(:); d=ts.signals.values;
        if size(d,1)~=numel(tt); d=permute(d,[ndims(d),1:ndims(d)-1]); end
        signals.(names{k})=struct('time',tt,'data',reshape(d,numel(tt),[]));
    else
        d=ts.Data;
        if ~ts.IsTimeFirst; d=permute(d,[ndims(d),1:ndims(d)-1]); end
        signals.(names{k})=struct('time',ts.Time(:),'data',reshape(d,numel(ts.Time),[]));
    end
    clear ts d tt;
end
clear out ts d;
finite=true; complete=true;
for k=1:numel(names)
    s=signals.(names{k});
    finite=finite && ~isempty(s.data) && all(isfinite(s.data(:)));
    complete=complete && s.time(1)<=1e-9 && s.time(end)>=stopTime-1e-8;
end
report=struct('model_file',modelPath,'model_sha256',modelHash, ...
    'source_model_file',source,'source_model_sha256',sourceHash, ...
    'runner_file',[mfilename('fullpath') '.m'],'runner_sha256',runnerHash, ...
    'stop_time_s',stopTime,'maximum_step_s',maxStep,'wall_seconds',elapsed, ...
    'ff_gain',ffGain,'lpf_cutoff_Hz',lpfHz,'lpf_K',K,'wCf',ws*Cf, ...
    'ff_definition','i_ref += ff_gain*(LPF(i_L_dq) + [+wCf*vq; -wCf*vd]); i_L and V_load are the existing 10 kHz ZOH samples', ...
    'retained_signal_names',{names},'all_signals_finite',finite, ...
    'all_logs_cover_requested_run',complete, ...
    'scope','Simulation only (SPS MOSFET switching model). PI_V/PI_I have no output saturation, unlike firmware Iref_max. No hardware qualification.');
report.execution_pass=finite && complete;
resultPath=fullfile(folder,['results_' label '.mat']);
reportPath=fullfile(folder,['report_' label '.json']);
if exist(resultPath,'file'); vsg_backup_output(resultPath); end
if exist(reportPath,'file'); vsg_backup_output(reportPath); end
save(resultPath,'signals','report','-v7.3');
fid=fopen(reportPath,'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(report)); fclose(fid);
assert(strcmp(fileHash(source),sourceHash),'Source model changed during execution.');
fprintf('E12_FF_COMPLETE: %s\n',jsonencode(report));
end

function hex=fileHash(file)
fid=fopen(file,'rb'); assert(fid>=0);
bytes=fread(fid,Inf,'*uint8'); fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
digest=typecast(md.digest(),'uint8');
hex=lower(reshape(dec2hex(digest,2).',1,[]));
end
