$ErrorActionPreference = 'Stop'
try {
    $matlabLayoutApp = [Runtime.InteropServices.Marshal]::GetActiveObject('Matlab.Application')
    Write-Output $matlabLayoutApp.Execute("disp('LAYOUT_SESSION_CHECK'); disp(find_system('type','block_diagram')); if bdIsLoaded('vsg_stage5h_mosfet'); disp(get_param('vsg_stage5h_mosfet','Dirty')); disp(get_param('vsg_stage5h_mosfet','FileName')); end")
} catch { Write-Output $_.Exception.Message }
