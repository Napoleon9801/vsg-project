% phase5b_hd_sweep.m
% =========================================================================
%  VSG PROJECT  ::  STAGE 5b — H-D Parametric Sweep (Chapter 4 figures)
% =========================================================================
%
%  Builds on Stage 5a's switching abc model. For each (H, D) pair in the
%  sweep grid, runs an islanded simulation with R_load step disturbance and
%  extracts inertial-response metrics:
%
%     max_RoCoF, nadir_f, overshoot_f, t_settle, f_ss, P_ss
%
%  Grid (full): H = [0 1 3 5 7 10],  D = [0 5 10 20 40]   (30 cases)
%  Grid (smoke): H = [0 5],          D = [0 20]            (4 cases)
%
%  WHY setBlockParameter (not setVariable):
%  phase5a bakes several parameters as LITERAL strings into block
%  properties at build time (num2str of the workspace var). The blocks
%  affected:
%      Gain_inv_2Hws.Gain     <- 1/inertia_coeff = omega_s / (2*H)
%      Gain_D.Gain            <- D
%      R_load_step.Time       <- R_load_t  (disturbance instant)
%      <model StopTime>       <- T_sim
%  setVariable on the base-workspace name won't change a baked literal.
%  We override these block parameters per case via Simulink.SimulationInput.
%
%  Disturbance time moves to t = 1.0 s (was 0.2 s in 5a), simulation
%  extends to T_sim = 3.0 s to capture full inertial settle with low D.
%
%  Output : matlab/data/hd_sweep_results.mat
%
%  MATLAB R2018b. No `arguments` blocks. No R2019b+ APIs.
%
%  Author: Napoleon (Chinnawat Dumklang) — SUT EE
%  Stage 5b: 2026-05-28
% =========================================================================

%% --- CONFIG -------------------------------------------------------------

% Smoke vs full sweep — flip this flag after smoke passes.
SMOKE_ONLY = false;

if SMOKE_ONLY
    H_grid = [0, 5];
    D_grid = [0, 20];
else
    H_grid = [0, 1, 3, 5, 7, 10];
    % D grid revised after smoke test: original {0,5,10,20,40} over-damped
    % every case with D>=5 (Δf < 0.005 Hz). Lowered range to {0,0.5,1,2,5}
    % to span underdamped �?� moderately-damped regime visible in figures.
    D_grid = [0, 0.5, 1, 2, 5];
end

% Disturbance + simulation timing (Stage 5b overrides)
R_load_t_sweep = 1.0;     % step happens at t = 1.0 s
T_sim_sweep    = 3.0;     % run to 3.0 s

% Downsample stride for stored time series (target dt = 1 ms).
% Solver MaxStep = 5 us so output time vector has ~variable step but
% bounded by 5 us. We resample on a uniform 1-ms grid for storage.
ts_dt_store   = 1e-3;

%% --- BUILD STAGE 5a MODEL ----------------------------------------------

script_dir = fileparts(mfilename('fullpath'));
model      = 'vsg_stage5a';
model_path = fullfile(script_dir, [model '.slx']);

% If the model file already exists from a previous Stage 5a run, just load
% it and skip the 4-minute rebuild + sim. Otherwise rebuild via phase5a
% (which will also run a baseline sim — unavoidable).
if exist(model_path, 'file')
    fprintf('[Stage 5b] Found existing model %s — loading.\n', model_path);
    if ~bdIsLoaded(model)
        load_system(model_path);
    end
    % Re-establish required base-workspace constants by running phase5a's
    % parameter block only would be ideal — but cleanest is just to source
    % them. phase5a rebuilds from scratch and re-sims; to avoid that, we
    % manually inject the constants needed by the model's symbolic refs.
    % HOWEVER: Stage 5a bakes ALL its numerics as literals in block params.
    % So the model is fully self-contained after build. No base vars are
    % strictly required by the model itself once it is loaded.
    % We still need a few constants locally for metric calc.
    omega_s = 2*pi*50;
    f_base  = 50;
    P_base  = 100;
else
    fprintf('[Stage 5b] No existing model — building via phase5a (~4 min)...\n');
    run(fullfile(script_dir, 'phase5a_switching_abc.m'));
    omega_s = 2*pi*50;
    f_base  = 50;
    P_base  = 100;
    % Close all figures opened by phase5a's plot block so the sweep stays clean
    close all;
end

% Ensure model is loaded (not necessarily open in GUI)
if ~bdIsLoaded(model)
    load_system(model_path);
end

%% --- PRE-ALLOCATE -------------------------------------------------------

nH = numel(H_grid);
nD = numel(D_grid);
nCases = nH * nD;

metrics.max_RoCoF   = nan(nH, nD);
metrics.nadir_f     = nan(nH, nD);
metrics.overshoot_f = nan(nH, nD);
metrics.t_settle    = nan(nH, nD);
metrics.f_ss        = nan(nH, nD);
metrics.P_ss        = nan(nH, nD);
metrics.ok          = false(nH, nD);
metrics.err_msg     = cell(nH, nD);

% time-series struct array (downsampled)
ts(nH, nD).t      = [];
ts(nH, nD).f_inv  = [];
ts(nH, nD).P_meas = [];
ts(nH, nD).V_d    = [];
ts(nH, nD).delta  = [];

%% --- BUILD SimulationInput LIST ----------------------------------------

% Pre-build all SimulationInput objects so we can sim in a single batch
% if desired. For now we run sequentially with per-case try/catch.

in_list = repmat(Simulink.SimulationInput(model), nH*nD, 1);
k = 0;
for i = 1:nH
    for j = 1:nD
        k = k + 1;
        H_ij = H_grid(i);
        D_ij = D_grid(j);

        % 1/inertia_coeff = omega_s / (2*H).  Handle H=0 -> droop-only.
        % Mathematically H=0 collapses swing eq to algebraic droop, but a
        % literal 1/0 or huge integrator gain (1e6) explodes ode23tb (smoke
        % test: H=0 D=0 ran 601s wall vs 19s otherwise, with RoCoF=8678 Hz/s
        % numerical artifact). Use H_eff = max(H, 0.01): integrator time
        % constant �?? 64 µs �?� 1 s control timescale, so dynamics behave
        % algebraic but the solver stays stable.
        H_eff = max(H_ij, 0.01);
        inv_2Hws = omega_s / (2 * H_eff);

        in = Simulink.SimulationInput(model);
        in = in.setBlockParameter([model '/Gain_inv_2Hws'], ...
                'Gain', num2str(inv_2Hws));
        in = in.setBlockParameter([model '/Gain_D'], ...
                'Gain', num2str(D_ij));
        in = in.setBlockParameter([model '/R_load_step'], ...
                'Time', num2str(R_load_t_sweep));
        in = in.setModelParameter('StopTime', num2str(T_sim_sweep));

        in_list(k) = in;
    end
end

%% --- RUN SWEEP ---------------------------------------------------------

fprintf('[Stage 5b] Sweep grid: %d x %d = %d cases\n', nH, nD, nCases);
fprintf('[Stage 5b] R_load_t = %.2f s,  T_sim = %.2f s\n', ...
        R_load_t_sweep, T_sim_sweep);
fprintf('[Stage 5b] Starting at %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
t_sweep_start = tic;

k = 0;
for i = 1:nH
    for j = 1:nD
        k = k + 1;
        H_ij = H_grid(i);
        D_ij = D_grid(j);
        t_case = tic;
        try
            out = sim(in_list(k));

            % Pull logged timeseries via SimulationOutput.get
            omega_ts  = out.get('omega_ts');
            P_ts      = out.get('P_ts');
            Vload_d_ts = out.get('Vload_d_ts');
            delta_ts  = out.get('delta_ts');

            t_full     = omega_ts.Time;
            f_full     = omega_ts.Data / (2*pi);
            P_full     = P_ts.Data;
            Vd_full    = Vload_d_ts.Data;
            delta_full = delta_ts.Data;

            % --- METRICS ---
            % steady-state window: last 0.2 s of sim
            mask_ss = t_full >= (T_sim_sweep - 0.2);
            f_ss_ij = mean(f_full(mask_ss));
            P_ss_ij = mean(P_full(mask_ss));

            % nadir + overshoot: search within [R_load_t, R_load_t + 1.5 s]
            mask_post = (t_full >= R_load_t_sweep) & ...
                        (t_full <= R_load_t_sweep + 1.5);
            f_post = f_full(mask_post);
            nadir_ij = min(f_post);
            overshoot_ij = abs(nadir_ij - f_ss_ij);

            % max RoCoF in 0.5 s window after disturbance
            mask_rocof = (t_full >= R_load_t_sweep) & ...
                         (t_full <= R_load_t_sweep + 0.5);
            t_r = t_full(mask_rocof);
            f_r = f_full(mask_rocof);
            if numel(t_r) > 3
                df = diff(f_r);
                dt = diff(t_r);
                rocof = df ./ max(dt, eps);
                max_rocof_ij = max(abs(rocof));
            else
                max_rocof_ij = NaN;
            end

            % settling time: first t* > R_load_t such that |f - f_ss| < 0.05 Hz
            % sustained for 0.2 s. Search up to end of sim.
            mask_search = t_full >= R_load_t_sweep;
            t_s = t_full(mask_search);
            f_s = f_full(mask_search);
            within = abs(f_s - f_ss_ij) < 0.05;
            t_settle_ij = NaN;
            if any(within)
                % find first index where 'within' stays true for 0.2 s
                for idx = 1:numel(t_s)
                    if within(idx)
                        t_end_check = t_s(idx) + 0.2;
                        chk_mask = (t_s >= t_s(idx)) & (t_s <= t_end_check);
                        if all(within(chk_mask))
                            t_settle_ij = t_s(idx) - R_load_t_sweep;
                            break;
                        end
                    end
                end
            end

            metrics.max_RoCoF(i,j)   = max_rocof_ij;
            metrics.nadir_f(i,j)     = nadir_ij;
            metrics.overshoot_f(i,j) = overshoot_ij;
            metrics.t_settle(i,j)    = t_settle_ij;
            metrics.f_ss(i,j)        = f_ss_ij;
            metrics.P_ss(i,j)        = P_ss_ij;
            metrics.ok(i,j)          = true;
            metrics.err_msg{i,j}     = '';

            % --- DOWNSAMPLE TIME SERIES ---
            t_ds = (0:ts_dt_store:T_sim_sweep).';
            f_ds     = interp1(t_full, f_full,     t_ds, 'linear', 'extrap');
            P_ds     = interp1(t_full, P_full,     t_ds, 'linear', 'extrap');
            Vd_ds    = interp1(t_full, Vd_full,    t_ds, 'linear', 'extrap');
            delta_ds = interp1(t_full, delta_full, t_ds, 'linear', 'extrap');

            ts(i,j).t      = t_ds;
            ts(i,j).f_inv  = f_ds;
            ts(i,j).P_meas = P_ds;
            ts(i,j).V_d    = Vd_ds;
            ts(i,j).delta  = delta_ds;

            dt_case = toc(t_case);
            fprintf(['[%2d/%2d, %d/%d] H=%2g D=%2g -> ' ...
                     'RoCoF=%6.3f Hz/s  nadir=%7.4f Hz  ' ...
                     't_settle=%5.3f s  f_ss=%7.4f Hz  ' ...
                     '(%.1f s wall)\n'], ...
                    i, nH, j, nD, H_ij, D_ij, ...
                    max_rocof_ij, nadir_ij, t_settle_ij, f_ss_ij, dt_case);

        catch ME
            metrics.ok(i,j)      = false;
            metrics.err_msg{i,j} = ME.message;
            fprintf('[%2d/%2d, %d/%d] H=%2g D=%2g -> FAILED: %s\n', ...
                    i, nH, j, nD, H_ij, D_ij, ME.message);
        end
    end
end

t_sweep_total = toc(t_sweep_start);
fprintf('[Stage 5b] Sweep complete in %.1f s (%.2f min)\n', ...
        t_sweep_total, t_sweep_total/60);

%% --- SAVE --------------------------------------------------------------

data_dir = fullfile(script_dir, 'data');
if ~exist(data_dir, 'dir'); mkdir(data_dir); end

if SMOKE_ONLY
    out_file = fullfile(data_dir, 'hd_sweep_results_smoke.mat');
else
    out_file = fullfile(data_dir, 'hd_sweep_results.mat');
end

meta = struct();
meta.timestamp    = datestr(now, 'yyyy-mm-dd HH:MM:SS');
meta.T_sim        = T_sim_sweep;
meta.R_load_t     = R_load_t_sweep;
meta.V_dc         = 40;  % metadata only — actual value baked into vsg_stage5a.slx
                         % (rebuild via phase5a_switching_abc.m at 40 V first).
                         % Per-unit sweep metrics are V_dc-invariant (duty =
                         % 0.5 + v/V_dc cancels in the fundamental).
meta.R_p          = 0.05;
meta.f_base       = f_base;
meta.P_base       = P_base;
meta.ts_dt_store  = ts_dt_store;
meta.smoke_only   = SMOKE_ONLY;
meta.sweep_wall_s = t_sweep_total;

save(out_file, 'H_grid', 'D_grid', 'metrics', 'ts', 'meta', '-v7');
fprintf('[Stage 5b] Saved: %s\n', out_file);

%% --- SUMMARY TABLE -----------------------------------------------------

fprintf('\n=================  SWEEP SUMMARY  =================\n');
fprintf('  H    D     RoCoF    nadir   overshoot  t_settle   f_ss    P_ss\n');
fprintf(' [-] [-]   [Hz/s]    [Hz]      [Hz]       [s]      [Hz]    [W]\n');
fprintf('---------------------------------------------------------------\n');
for i = 1:nH
    for j = 1:nD
        if metrics.ok(i,j)
            fprintf(' %3g  %3g  %7.3f  %7.4f   %7.4f   %6.3f  %7.4f  %6.2f\n', ...
                H_grid(i), D_grid(j), ...
                metrics.max_RoCoF(i,j), metrics.nadir_f(i,j), ...
                metrics.overshoot_f(i,j), metrics.t_settle(i,j), ...
                metrics.f_ss(i,j), metrics.P_ss(i,j));
        else
            fprintf(' %3g  %3g  FAILED: %s\n', ...
                H_grid(i), D_grid(j), metrics.err_msg{i,j});
        end
    end
end
fprintf('===============================================================\n');

if SMOKE_ONLY
    fprintf('\n[Stage 5b] SMOKE TEST complete. Review metrics above.\n');
    fprintf('           If sane, set SMOKE_ONLY=false at top of script and re-run.\n');
end
