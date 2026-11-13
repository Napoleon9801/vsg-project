function info = build_stage5k(P,label,varargin)
% BUILD_STAGE5K  Stage 5k model = Stage 5j + three single-phase step-up
% transformers (star-star) between the LC filter and the load.  MATLAB R2018b.
%
%   P = vsg_stage5k_params();  build_stage5k(P,'tx12');
%   -> validation_outputs/stage5k/vsg_stage5k_tx12.slx   ('open',true opens it)
%
% The Stage 5j model is built first with build_stage5j (unchanged). Changes made
% here, per phase x, inside Gate_Driver_and_MOSFET_Circuit:
%   1. The line iload_x -> Load_RL_x is cut. TX_x (powerlib Linear Transformer,
%      two windings) goes in between: LV winding from the iload_x output to the
%      AC neutral, HV winding to the load through the new current sensor ihv_x.
%      iload_x therefore still measures the current leaving the filter (now the
%      transformer LV current, magnetizing current included); the controller and
%      its load-current feed-forward keep using it unchanged.
%   2. Load_RL_x becomes a pure resistor (vsg_R_load), Load_Extra_R_x and its
%      bypass breaker are untouched: the same load-step circuit, now at HV level.
%   3. New sensors Vhv_x (HV winding terminal to neutral) and ihv_x, logged as
%      Vhv_abc_ts / ihv_abc_ts with the same settings as Vload_abc_ts.
% The HV star point is tied to the LV / filter-capacitor neutral in the model.
% That single connection carries no current (each HV winding feeds its own
% resistor), so it does not change any voltage or current; on hardware the HV
% side is galvanically isolated.
% The voltage loop still regulates the capacitor (LV) voltage: nothing
% compensates the transformer drop.
opt=struct('open',false);
for k=1:2:numel(varargin); opt.(varargin{k})=varargin{k+1}; end
assert(isstruct(P) && isfield(P,'tx') && isfield(P,'base'),'Pass the struct returned by vsg_stage5k_params().');
assert(ischar(label) && ~isempty(regexp(label,'^[a-zA-Z0-9_]{1,28}$','once')),'label: letters, digits, _ (max 28).');

root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5k');
if ~exist(folder,'dir'); mkdir(folder); end
model=['vsg_stage5k_' label];
modelPath=fullfile(folder,[model '.slx']);
if bdIsLoaded(model); close_system(model,0); end

% ---- Stage 5j model with the HV load resistors, then move it into stage5k
tmpLabel=['k_' label]; %#ok<NASGU>
[~,j]=evalc('build_stage5j(P,tmpLabel)');
if exist(modelPath,'file'); vsg_backup_output(modelPath); end
copyfile(j.model_file,modelPath);
delete(j.model_file);                                         % intermediate, just created
tmpJson=fullfile(fileparts(j.model_file),[j.model '_params.json']);
if exist(tmpJson,'file'); delete(tmpJson); end
load_system(modelPath);
if ~opt.open; cl=onCleanup(@() close_system(model,0)); end %#ok<NASGU>
load_system('powerlib');

b=P.tx.block;
mw=get_param(model,'ModelWorkspace');
assignin(mw,'vsg_tx_Pn',b.NominalPower);
assignin(mw,'vsg_tx_w1',b.winding1);
assignin(mw,'vsg_tx_w2',b.winding2);
assignin(mw,'vsg_tx_RmLm',b.RmLm);
% load-current feed-forward: gain (E12_ff_gain_d/q use vsg_ff_on) and i_L low-pass
% (E12_LPF_iLd/q use e12_lpf_K, backward Euler at the 100 us controller rate)
assert(hasVariable(mw,'vsg_ff_on') && hasVariable(mw,'e12_lpf_K'),'Feed-forward variables not found in the model workspace.');
assert(strcmp(get_param([model '/E12_ff_gain_d'],'Gain'),'vsg_ff_on') && ~isempty(strfind(get_param([model '/E12_LPF_iLd'],'Numerator'),'e12_lpf_K')),'Unexpected feed-forward blocks.'); %#ok<STREMP>
wcTs=2*pi*P.ff_lpf_Hz*1e-4;
assignin(mw,'vsg_ff_on',P.ff_gain);
assignin(mw,'e12_lpf_K',wcTs/(1+wcTs));

pl=[model '/Gate_Driver_and_MOSFET_Circuit'];
lib='powerlib/Elements/Linear Transformer';
dp=get_param(lib,'DialogParameters');
need={'NominalPower','winding1','winding2','ThreeWindings','RmLm','UNITS'};
for k=1:numel(need); assert(isfield(dp,need{k}),'Linear Transformer has no parameter %s in this release.',need{k}); end

% lowest block in the subsystem: new blocks go underneath
blks=find_system(pl,'SearchDepth',1,'LookUnderMasks','none','FollowLinks','off','Type','block');
ymax=0; xmin=inf;
for k=2:numel(blks); q=get_param(blks{k},'Position'); ymax=max(ymax,q(4)); xmin=min(xmin,q(1)); end
y0=ymax+120; x0=xmin+200;

ph='ABC'; vh=zeros(1,3); ihh=zeros(1,3);
for k=1:3
    x=ph(k); y=y0+170*(k-1);
    ld=[pl '/Load_RL_' x]; im=[pl '/iload_' x]; cf=[pl '/Rd_Cf_' x];
    lh=get_param(ld,'PortHandles'); ih=get_param(im,'PortHandles'); ch=get_param(cf,'PortHandles');
    assert(onNet(cf,'RConn1','N_AC_to_DCminus'),'Rd_Cf_%s RConn1 is not the AC neutral.',x);
    c=netOf(ld,'LConn1');
    assert(numel(c)==1 && strcmp(c{1},['iload_' x]),'Load_RL_%s is not fed by iload_%s only.',x,x);
    delete_line(get_param(lh.LConn(1),'Line'));

    tx=add_block(lib,[pl '/TX_' x],'Position',[x0 y x0+70 y+90]);
    set_param(tx,'ThreeWindings','off','UNITS','pu');
    set_param(tx,'NominalPower','vsg_tx_Pn','winding1','vsg_tx_w1','winding2','vsg_tx_w2','RmLm','vsg_tx_RmLm');
    th=get_param(tx,'PortHandles');
    assert(numel(th.LConn)==2 && numel(th.RConn)==2,'Unexpected Linear Transformer terminals.');
    cm=add_block(im,[pl '/ihv_' x],'Position',[x0+150 y x0+190 y+30]);
    vm=add_block([pl '/Vphase_' x],[pl '/Vhv_' x],'Position',[x0+260 y+40 x0+300 y+80]);
    ch2=get_param(cm,'PortHandles'); vh2=get_param(vm,'PortHandles');
    assert(numel(ch2.LConn)==1 && numel(ch2.RConn)==1 && numel(vh2.LConn)==2,'Unexpected sensor terminals.');

    add_line(pl,ih.RConn(1),th.LConn(1),'autorouting','on');       % filter side -> LV winding +
    add_line(pl,th.LConn(2),ch.RConn(1),'autorouting','on');       % LV winding - -> AC neutral
    add_line(pl,th.RConn(1),ch2.LConn(1),'autorouting','on');      % HV winding + -> ihv
    add_line(pl,ch2.RConn(1),lh.LConn(1),'autorouting','on');      % ihv -> load
    add_line(pl,th.RConn(2),ch.RConn(1),'autorouting','on');       % HV winding - -> neutral (single tie)
    add_line(pl,vh2.LConn(1),lh.LConn(1),'autorouting','on');      % Vhv + at the load terminal
    add_line(pl,vh2.LConn(2),ch.RConn(1),'autorouting','on');      % Vhv - at the neutral

    set_param(ld,'BranchType','R');                                % resistive HV load
    assert(strcmp(get_param(ld,'Resistance'),'vsg_R_load'),'Load_RL_%s resistance is not vsg_R_load.',x);
    vh(k)=vh2.Outport(1); ihh(k)=ch2.Outport(1);
    % wiring check: the two sides of the transformer
    assert(any(strcmp(netOf(im,'RConn1'),['TX_' x])) && any(strcmp(netOf(ld,'LConn1'),['ihv_' x])),'TX_%s wiring check failed.',x);
end

% ---- logs, same settings as the existing load-side logs
src={'Vload_abc_ts','iload_abc_ts'}; dst={'Vhv_abc_ts','ihv_abc_ts'}; sig={vh,ihh}; nm={'Vhv_abc','ihv_abc'};
for k=1:2
    tw=find_system(model,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace','VariableName',src{k});
    assert(numel(tw)==1,'Expected one To Workspace block for %s.',src{k});
    yb=y0+170*3+60*(k-1);
    mx=add_block('built-in/Mux',[pl '/' nm{k}],'Inputs','3','Position',[x0+420 yb x0+426 yb+50]);
    lg=add_block(tw{1},[pl '/Log_' nm{k}],'Position',[x0+480 yb+10 x0+620 yb+40]);
    set_param(lg,'VariableName',dst{k});
    mh=get_param(mx,'PortHandles'); gh=get_param(lg,'PortHandles');
    for q=1:3; add_line(pl,sig{k}(q),mh.Inport(q),'autorouting','on'); end
    add_line(pl,mh.Outport(1),gh.Inport(1),'autorouting','on');
end

% (no slash in the text: Simulink reads it as a path separator)
note=Simulink.Annotation([pl '/Stage 5k: TX_x = single-phase step-up transformers (star-star), ASSUMED data. Load_RL_x and Load_Extra_R_x are on the HV side.']);
note.Position=[x0 y0-50];
set_param(model,'StopTime',num2str(P.stop_time,16));
set_param(model,'SimulationCommand','update');                % compile check
save_system(model,modelPath);

info=struct('model',model,'model_file',modelPath,'model_sha256',fileHash(modelPath), ...
    'source_model_file',j.source_model_file,'source_model_sha256',j.source_model_sha256, ...
    'builder_sha256',fileHash([mfilename('fullpath') '.m']),'stage5j_builder_sha256',j.builder_sha256, ...
    'params',j.params,'stage5j',j.stage5j,'derived_lv_equivalent',j.derived,'lv_equivalent',P.lv_equivalent, ...
    'transformer',P.tx,'ff',struct('gain',P.ff_gain,'lpf_Hz',P.ff_lpf_Hz),'warnings',{P.warnings});
fid=fopen(fullfile(folder,[model '_params.json']),'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(info)); fclose(fid);
fprintf('STAGE5K_BUILT: %s\n',modelPath);
if opt.open; open_system(model); end
end

function c=netOf(blk,port)
% names of the blocks on one physical terminal
pc=get_param(blk,'PortConnectivity'); c={};
for k=1:numel(pc)
    if strcmp(pc(k).Type,port)
        for q=1:numel(pc(k).DstBlock); c{end+1}=get_param(pc(k).DstBlock(q),'Name'); end %#ok<AGROW>
    end
end
end

function tf=onNet(blk,port,name)
tf=any(strcmp(netOf(blk,port),name));
end

function hex=fileHash(file)
fid=fopen(file,'rb'); assert(fid>=0);
bytes=fread(fid,Inf,'*uint8'); fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
digest=typecast(md.digest(),'uint8');
hex=lower(reshape(dec2hex(digest,2).',1,[]));
end
