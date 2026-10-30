function report = vsg_validate_signals(signals)
% Validate schema-v2 exports without assuming all signals share one clock.
names = fieldnames(signals);
assert(~isempty(names), 'VSG:EmptyExport', 'No signals exported.');
report = struct();
for k = 1:numel(names)
    s = signals.(names{k});
    assert(isstruct(s) && isfield(s,'time') && isfield(s,'data'), ...
        'VSG:SignalSchema', 'Signal %s needs time and data.', names{k});
    assert(isnumeric(s.time) && isvector(s.time) && numel(s.time)>=2, ...
        'VSG:TimeShape', 'Signal %s needs at least two timestamps.', names{k});
    assert(isnumeric(s.data) && size(s.data,1)==numel(s.time), ...
        'VSG:LengthMismatch', 'Signal %s has mismatched timestamps/data.', names{k});
    assert(all(isfinite(s.time(:))) && all(isfinite(s.data(:))), ...
        'VSG:Nonfinite', 'Signal %s contains nonfinite data.', names{k});
    assert(all(diff(s.time(:))>0), 'VSG:TimeOrder', ...
        'Signal %s timestamps must strictly increase.', names{k});
    report.(names{k}) = struct('samples',numel(s.time), ...
        'columns',size(s.data,2),'start',s.time(1),'stop',s.time(end));
end
end
