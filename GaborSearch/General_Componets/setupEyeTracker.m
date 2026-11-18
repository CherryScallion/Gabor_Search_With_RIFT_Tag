function el = setupEyeTracker(win, edfName, runIdx, params, pahandle)
% Initialize EyeLink once, open one EDF per run, and configure calibration.

%% Load display parameters
if nargin < 4
    params = defineParameters();
end
if nargin < 5
    pahandle = [];
end
[screenWidthPx, screenHeightPx] = Screen('WindowSize', win);
screenWidthMm = params.screenWidth * 10;
screenHeightMm = params.screenHeight * 10;

%% Initialize tracker connection
if runIdx == 1
    if ~EyelinkInit(params.eye.dummyMode, 1)
        error('GaborSearch:EyeInit', 'EyeLink initialization failed.');
    end
end
el = EyelinkInitDefaults(win);
el.ppa_pahandle = pahandle;
% Empty edfName enables practice without creating an EDF
if ~isempty(edfName)
    status = Eyelink('Openfile', edfName);
    if status ~= 0
        error('GaborSearch:EyeFile', 'Cannot open EDF file: %s', edfName);
    end
end

try
    %% Set display coordinates and recording properties
    Eyelink('Command', 'screen_phys_coords = %ld %ld %ld %ld', ...
        -round(screenWidthMm/2), round(screenHeightMm/2), ...
        round(screenWidthMm/2), -round(screenHeightMm/2));
    Eyelink('Command', 'screen_pixel_coords = %ld %ld %ld %ld', ...
        0, 0, screenWidthPx-1, screenHeightPx-1);
    Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld', ...
        0, 0, screenWidthPx-1, screenHeightPx-1);
    % Eye-to-screen distances in mm, measured at the display top and bottom
    Eyelink('Command', 'screen_distance = %d %d', params.eye.screenDistMm(1), params.eye.screenDistMm(2));
    Eyelink('Command', 'calibration_type = %s', params.eye.calType);
    Eyelink('Command', 'generate_default_targets = YES');
    Eyelink('Command', 'calibration_area_proportion 0.80 0.83');
    Eyelink('Command', 'validation_area_proportion 0.80 0.83');
    Eyelink('Command', 'sample_rate = %d', params.eye.sampleRate);
    Eyelink('Command', 'file_event_filter = %s', params.eye.fileEvtFilter);
    Eyelink('Command', 'link_event_filter = %s', params.eye.linkEvtFilter);
    Eyelink('Command', 'file_sample_data = %s', params.eye.fileSampData);
    Eyelink('Command', 'link_sample_data = %s', params.eye.linkSampData);

    %% Set calibration appearance
    el.backgroundcolour = params.bgColor;
    el.foregroundcolour = params.textColor;
    el.msgfontcolour = params.textColor;
    el.calibrationtargetcolour = params.fixColor;
    el.calibrationtargetsize = params.eye.tarSize;
    el.calibrationtargetwidth = params.eye.tarWidth;
    EyelinkUpdateDefaults(el);

    %% Run calibration and drift correction on every run
    DrawFormattedText(win, double(params.eyeMess), 'center', 'center', ...
        params.textColor, [], [], [], params.textSpacing);
    Screen('Flip', win);
    while true
        [~, ~, keyCode] = KbCheck;
        if keyCode(params.startKey)
            break;
        end
        WaitSecs('YieldSecs', params.pollDur);
    end
    EyelinkDoTrackerSetup(el);
    EyelinkDoDriftCorrection(el);
    Eyelink('SetOfflineMode');
    WaitSecs(params.eye.idleDelay);
catch ME
    % No trial recording has begun; close the newly opened setup file.
    try
        Eyelink('SetOfflineMode');
        if ~isempty(edfName)
            Eyelink('CloseFile');
        end
    catch
    end
    rethrow(ME);
end
end
