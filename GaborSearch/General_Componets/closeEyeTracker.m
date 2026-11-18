function closeEyeTracker(edfName, saveDir, disconnect, params)
% Stop recording, close and download the EDF, and optionally disconnect.

if nargin < 3
    disconnect = true;
end
if nargin < 4
    params = defineParameters();
end

%% Close tracker data file
Eyelink('StopRecording');
Eyelink('SetOfflineMode');
WaitSecs(params.eye.closeDelay);
Eyelink('Command', 'generate_default_targets = YES');
Eyelink('CloseFile');

%% Download EDF file
status = Eyelink('ReceiveFile', edfName, saveDir, 1);
if status < 0
    error('GaborSearch:EyeDownload', 'Could not receive EDF file: %s', edfName);
end

%% Disconnect after the last run
if disconnect
    Eyelink('Shutdown');
end
end
