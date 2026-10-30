function vsg_backup_output(path)
% Preserve previous generated output before replacement.
if exist(path,'file')
    backup=[path '.backup_' datestr(now,'yyyymmdd_HHMMSS_FFF')];
    assert(copyfile(path,backup),'VSG:BackupFailed','Could not back up %s',path);
end
end
