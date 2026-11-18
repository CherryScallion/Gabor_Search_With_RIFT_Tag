%Created by Shiye Jiang, Oct. to Nov.2026
%%%%%%%
function GaborSearchRIFT(subNo, EL, ProPixx, useTrigger)

%% Sub ID Input
if nargin == 0 % if no input arguments, ask for subID
    promptParams = {'Subject ID', 'EL(0:No, 1:Yes)', 'ProPixx', 'Use Trigger'};
    settings = inputdlg(promptParams, 'settings', 1, {'100', '0','0','0'});
    subNo = str2double(settings{1});
    EL = str2double(settings{2});
    ProPixx = str2double(settings{3}); % default to ProPixx enabled
    useTrigger = str2double(settings{4}); % default to useTrigger disabled
end

AssertOpenGL;
KbName('UnifyKeyNames');
Screen('Preference', 'SkipSyncTests', 1); % skip sync tests
rng('shuffle'); % shuffle random number generator
%% Create and open data file
% Create data folder and path

%% Open params
[params, gaborPat] = defineParameters();
Resolution = params.screenResolution;

colVec = params.colVec; %color wheel
bgColor = params.bgColor; %background color
one = params.one;
two = params.two;
three = params.three;
four = params.four;
nRun = params.nRun;
nBlock = params.nBlock;
nSearch = params.nSearch;
nTrial = nSearch;

% define paths for data storage
currentFileFolder = fileparts(mfilename('fullpath'));
dataFolder = fullfile(currentFileFolder, '..', 'data');
GaborFolder = fullfile(dataFolder, 'GaborSearch');
saveFolder = fullfile(GaborFolder, 'Behavioral');
saveFolderEL = fullfile(GaborFolder, 'EL');
if ~exist(saveFolder, 'dir')
    mkdir(saveFolder);
end
if ~exist(saveFolderEL, 'dir')
    mkdir(saveFolderEL);
end
% Add the organized component folders to the MATLAB path.
componentFolders = {'Params', 'General_Componets', 'Task_Components'};
for iFolder = 1:numel(componentFolders)
    addpath(fullfile(currentFileFolder, componentFolders{iFolder}));
end
addpath(dataFolder)

edfActive = false;

%% Trigger device setup

if useTrigger == 1
    clear device
    device_found = 0;
    device = [];
    ports = serialportlist("available");
    for p = 1:length(ports)
        try
            temp_dev = serialport(ports(p), 9600, "Timeout", 1);
            temp_dev.flush();

            write(temp_dev, "_c1", "char");
            query_return = read(temp_dev, 5, "char");
            display(query_return);

            if ~isempty(query_return) && query_return == "_xid0"
                device = temp_dev;
                device_found = 1;
                fprintf('XID Device found on port: %s\n', ports(p));
                break;
            else
                clear temp_dev;
            end

        catch
            continue;
        end
    end

    if ~device_found
        error(['CRITICAL ERROR: XID Device not found. ' ...
            'For formal data collection, the trigger device is required. ' ...
            'Check connection or set is_debug=1.']);
    end

    setPulseDuration(device, 30);
else
    warning('DEBUG MODE: experiment will continue without XID triggers.');
    device = [];
end



try
    screens = max(Screen('Screens'));
    HideCursor;
    [w, screenRect] = Screen('OpenWindow', screens, 0, [], 32, 2); % PTB fullscreen window, black background, 32 bit color depth, multi-sampling 2
    Screen('FillRect',w,bgColor);
    [cx, cy] = RectCenter(screenRect);
    Screen('BlendFunction',w,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); 
    ifi = Screen('GetFlipInterval',w); %inter flip interval

    ppd = angle2pixel(1, Resolution(1), params);

    % Font size and font type
    fontSizeP = angle2pixel(params.fontSize, Resolution(1), params);
    Screen('TextFont',w,'Arial');
    Screen('TextSize',w,fontSizeP);

    %stimsize calculation 
    stimSizeP = angle2pixel(params.stimSize, Resolution(1), params);
 
    baseRect = [0 0 stimSizeP stimSizeP];

    fixSizePx = angle2pixel(params.fixRectSize, Resolution(1), params);
    fixRect = round(CenterRectOnPointd([0 0 fixSizePx fixSizePx], cx, cy));

    eccP = angle2pixel(params.ecc, Resolution(1), params);

    cueSizeP = angle2pixel(params.cueSize, Resolution(1), params);
    gaborPat.size = stimSizeP;
    % Convert Gaussian sigma to pixels and frequency to cycles/image
    stimPxPerDeg = stimSizeP / params.stimSize;
    gaborPat.sd = max(1, round(params.gaborSD * stimPxPerDeg));

    ListenChar(2); % PTB function to suppress keypresses from 
    % presses CTRL+C to reenable keyboard input.
    %% press q to quit (defined by defParam)   
    Priority(MaxPriority(w));

    % '%s' String formatting
    % '\t' Tab character
    % '\n' New line character
    schemaVersion = 1;  % extra column: data format version

    % Silent-append design (reverted): one file per subject, no timestamp.
    Metadata = sprintf(['subNo=%d,EL=%d \n' ... %'
        'Parameters: \necc=%d, nRun=%d,nBlock=%d,nSearch=%d' ...
        'screenWidth=%d,screenHeight=%d,distance=%d,stimSize=%d,cueSize=%d,lineWidthPix=%d'], ...%'
        subNo, EL,...
        params.ecc, params.nRun, params.nBlock, params.nSearch,...
        params.screenWidth, params.screenHeight, params.distance, params.stimSize, params.cueSize, params.lineWidthPix);
    Filename = fullfile(saveFolder, sprintf('S%03d_GaborSearch.csv', subNo));
    Metadataname = fullfile(saveFolder, sprintf('S%03d_Params_GaborSearch.txt', subNo));

    % Columns 1-37 match ReferenceCodes/GaborSearch.m in name, order and
    % meaning so both scripts share the same analysis pipeline. Columns 38+
    % are RIFT-specific extras.
    Header = {'subID', 'eyelink', 'run', 'block', 'trial', ...
        'eccentricity', 'degOrient', ...
        'tarColor', 'tarOrient', 'dstr1Color', 'dstr1Orient', ...
        'color1', 'color2', 'color3', 'color4', ...
        'orient1', 'orient2', 'orient3', 'orient4', ...
        'loc1', 'loc2', 'loc3', 'loc4', ...
        'num1', 'num2', 'num3', 'num4', ...
        'response', 'right', 'wrong', ...
        'startTime', 'cueTime', 'fixTime2', 'testTime', 'decTime', ...
        'fixTime3', 'fixTime1', ...
        'ppd', 'proPixx', 'responseTime', 'stimDuration', 'stimFrames', ...
        'responded', 'valid', 'triggerCode', 'triggerTime', 'schemaVersion'};

    %% RIFT Tag Settings, render the tag textures for target and distractor
    freqstim = 8; % 480hz / 60Hz
    freqdistfull = 15; % 480hz / 64Hz * 2 for interleaving
    gaborTargetTagTexture = cell(1, freqstim);
    gaborTargetDotTexture = cell(1, freqstim);
    for i = 1:freqstim
        gaborTargetTagTexture{i} = Screen('MakeTexture', w, ...
            makeRIFTtag(gaborPat, bgColor, freqstim, i-1, 1, 0)); %gaborpat, colorBG, freqRIFT, frames, ratio, isvalid
        gaborTargetDotTexture{i} = Screen('MakeTexture', w, ...
            makeRIFTtag(gaborPat, bgColor, freqstim, i-1, 0.3, 1));
    end
    gaborDistractTagTexture = cell(1, freqdistfull);
    gaborDistractDotTexture = cell(1, freqdistfull);
    for i = 1:freqdistfull
        gaborDistractTagTexture{i} = Screen('MakeTexture', w, ...
            makeRIFTtag(gaborPat, bgColor, freqdistfull/2, i-1, 1, 0));
        gaborDistractDotTexture{i} = Screen('MakeTexture', w, ...
            makeRIFTtag(gaborPat, bgColor, freqdistfull/2, i-1, 0.3, 1));
    end
    %% RIFT Tag Settings End

    % make a fixation image with 4 quadrants
    stimWin = Screen('OpenOffscreenWindow', w, bgColor);
    Screen('WindowKind', stimWin);
    arcFixation(stimWin, cx, cy, ppd, 99, params);
    fiximage = Screen('GetImage', stimWin);
    fiximageTexture = Screen('MakeTexture',w, fiximage);
    fiximage4 = quadrantLayout(fiximage, fiximage, fiximage, fiximage, w, bgColor);
    fiximage4Texture = Screen('MakeTexture',w, fiximage4);
    Screen('Close', stimWin);

    ringThicknessPix = 6;
    ringTexture = Screen('MakeTexture', w, ...
        makeCircle(gaborPat.size, ringThicknessPix));

    %% Exp Start
    % Open calibration audio once for all runs
    if EL == 1
        InitializePsychSound;
        pahandle = PsychPortAudio('Open', [], 1, 0, [], 2);
        audioCleanup = onCleanup(@() PsychPortAudio('Close', pahandle));
    end

    for run = 1:nRun %% change it if the code crashes
        if EL == 1
            edfName = sprintf('S%03dR%d.edf', subNo, run);
            setupEyeTracker(w, edfName, run, params, pahandle);
            edfActive = true;
        end

        % prompt message for the start of the run
        Screen('TextSize',w,round(fontSizeP/2));
        Screen('FillRect',w,bgColor);
        DrawFormattedText(w,double(params.waitMess),cx/2-50,cy/2, ...
            params.textColor,[],[],[],3);
        DrawFormattedText(w,double(params.waitMess),cx*3/2-50,cy/2, ...
            params.textColor,[],[],[],3);
        DrawFormattedText(w,double(params.waitMess),cx/2-50,cy*3/2, ...
            params.textColor,[],[],[],3);
        DrawFormattedText(w,double(params.waitMess),cx*3/2-50,cy*3/2, ...
            params.textColor,[],[],[],3);
        Screen('Flip',w);
        [~,~,mbuttons] = GetMouse; % should i use keyboard?
        while mbuttons(1) == 0
            [~,~,mbuttons] = GetMouse;
        end
        WaitSecs(2);

        if EL == 1
            Eyelink('StartRecording');
            WaitSecs(params.eye.recordDelay);
        end
        % Get experiment start time since startup
        startt = GetSecs();
  
        Screen('Drawtexture', w, fiximage4Texture); % display fixation
        fixTime1 = Screen('Flip',w);
        if EL == 1
            Eyelink('Message', 'Fix 1 Display');
        end

        if ProPixx == 1
            initProPixx(1);
        end
        
        for block = 1:nBlock
            dstr1Prop = [params.dstr1ColorSet; params.dstr1OrientSet]; %dstr1 parameters
            dstr1Prop = dstr1Prop(:,randperm(nSearch));
            for trial = 1:nTrial
                trialNo = (block-1)*nTrial + trial;
                if EL == 1
                    Eyelink('Message', 'TRIALID %d', trialNo);
                end
                ResponseTime = NaN;
                stimulusOnsetTime = NaN;
                stimulusOffsetTime = NaN;
                stimulusFrameCount = 0;
                responseDetected = false;

                % setting target and distractor colors
                tarColor = params.tarColor(randperm(length(params.tarColor),1));
                tarOrient = params.tarOrient(randperm(length(params.tarOrient),1));
                dstr1Color = dstr1Prop(1,1); 
                dstr1Orient = dstr1Prop(2,1);
                dstr1Prop(:,1) = [];
                npColor = randsample([-1 1],1); %1 - pos rotate; %-1 - neg rotate
                npOrient = randsample([-1 1],1); %1 - pos rotate; %-1 - neg rotate
                colorSet = tarColor+[0 npColor*dstr1Color params.dstr2Color ...
                    params.dstr3Color];
                nStimSearch = numel(colorSet);
                orientSet = tarOrient+[0 npOrient*dstr1Orient params.dstr2Orient ...
                    params.dstr3Orient];
                for i = 1:nStimSearch
                    if colorSet(i) > 360
                        colorSet(i) = rem(colorSet(i),360);
                    elseif colorSet(i) < 1
                        colorSet(i) = rem(colorSet(i),360)+360;
                    end
                    if orientSet(i) > 180
                        orientSet(i) = rem(orientSet(i),180);
                    elseif orientSet(i) < 0
                        orientSet(i) = rem(orientSet(i),180)+180;
                    end
                end

                % Cue duration, response, answer, and decision time
                %basically display time and response time
                decTime = NaN;   % response time; aligned with GaborSearch.m decTime column                
                choice = NaN; 
                cueDur = 0.5;
                options = [30, 60];
                degree = options(randi(2));
                locSets = nan(nStimSearch,4);
                for i = 1:nStimSearch
                    locSets(i,:) = round(CenterRectOnPointd(baseRect, ...
                        cx+cosd(degree+(360/nStimSearch)*(i-1))*eccP, ...
                        cy-sind(degree+(360/nStimSearch)*(i-1))*eccP));
                end
                locSets2 = nan(nStimSearch,4);
                for i = 1:nStimSearch
                    locSets2(i,:) = round(CenterRectOnPointd(baseRect*2, ...
                        cx+cosd(degree+(360/nStimSearch)*(i-1))*eccP, ...
                        cy-sind(degree+(360/nStimSearch)*(i-1))*eccP));
                end

                % Display target cue
                xCoords = [cueSizeP/2 -cueSizeP/2] * cosd(tarOrient);
                yCoords = [-cueSizeP/2 cueSizeP/2] * sind(tarOrient);
                Screen('DrawLines',w,[xCoords; yCoords],params.lineWidthPix/2, ...
                    colVec(tarColor,:)*255,[cx/2 cy/2],2);
                Screen('DrawLines',w,[xCoords; yCoords],params.lineWidthPix/2, ...
                    colVec(tarColor,:)*255,[cx/2 cy*3/2],2);
                Screen('DrawLines',w,[xCoords; yCoords],params.lineWidthPix/2, ...
                    colVec(tarColor,:)*255,[cx*3/2 cy/2],2);
                Screen('DrawLines',w,[xCoords; yCoords],params.lineWidthPix/2, ...
                    colVec(tarColor,:)*255,[cx*3/2 cy*3/2],2);
                
                cueTime = Screen('Flip',w,fixTime1+params.fixDur-ifi/2);
                if EL == 1
                    Eyelink('Message', 'Cue Display');
                end

                % Display fixation
                Screen('Drawtexture', w, fiximage4Texture);
                fixTime2 = Screen('Flip',w,cueTime+cueDur-ifi/2);
                if EL == 1
                    Eyelink('Message', 'Fix 2 Display');
                end
                
                index = randperm(4);
                locIndex = randperm(4);
                loca1 = locIndex(1);
                loca2 = locIndex(2);
                loca3 = locIndex(3);
                loca4 = locIndex(4);
                Ans = [0 0];
                if EL == 1
                    Eyelink('Command', 'record_status_message "BLOCK %d TRIAL %d/%d"', ...
                        block, trial, nTrial);
                    % Draw interest areas without expanding stimulus rectangles
                    Eyelink('Command', 'clear_screen 0');
                    Eyelink('Command', 'draw_box %d %d %d %d %d', fixRect(1), fixRect(2), fixRect(3), fixRect(4), params.fixBoxColor);
                    Eyelink('Message', '!V FILLBOX %d %d %d %d %d %d %d', ...
                        params.fixIARGB(1), params.fixIARGB(2), params.fixIARGB(3), ...
                        fixRect(1), fixRect(2), fixRect(3), fixRect(4));
                    Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %d', ...
                        9, fixRect(1), fixRect(2), fixRect(3), fixRect(4), params.fixIA);

                    % Label target and distractors by stimulus identity
                    for stimIdx = 1:nStimSearch
                        stimRect = locSets(index(locIndex(stimIdx)), :);
                        Eyelink('Command', 'draw_box %d %d %d %d %d', stimRect(1), stimRect(2), stimRect(3), stimRect(4), params.stimBoxColors(stimIdx));
                        iaRGB = params.stimIARGB(stimIdx, :);
                        Eyelink('Message', '!V FILLBOX %d %d %d %d %d %d %d', ...
                            iaRGB(1), iaRGB(2), iaRGB(3), ...
                            stimRect(1), stimRect(2), stimRect(3), stimRect(4));
                        Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %d', ...
                            stimIdx, stimRect(1), stimRect(2), stimRect(3), stimRect(4), stimIdx);
                    end
                end
                stimWin = Screen('OpenOffscreenWindow', w, bgColor);
                Screen('WindowKind', stimWin);
                Screen('Drawtexture', stimWin, fiximageTexture); % draw fixation
                numSizePx = angle2pixel(params.numSize, Resolution(1), params);
                Screen('TextSize', stimWin, numSizePx);

                gaborTarget = Screen('MakeTexture', w, makeGabor(gaborPat,...
                    orientSet(1),bgColor,colVec(colorSet(1),:)*255, bgColor));
                Screen('Drawtexture', stimWin, gaborTarget,[],locSets(index(loca1),:));
                DrawFormattedText(stimWin,double(int2str(loca1)),'center','center', ...
                    params.textColor,[],[],[],3,[],locSets(index(loca1),:));
    
                gaborDistract = Screen('MakeTexture', w, makeGabor(gaborPat,...
                    orientSet(2),bgColor,colVec(colorSet(2),:)*255,bgColor));
                Screen('Drawtexture', stimWin, gaborDistract,[],locSets(index(loca2),:));                        
                DrawFormattedText(stimWin,double(int2str(loca2)),'center','center', ...
                    params.textColor,[],[],[],3,[],locSets(index(loca2),:));

                % other 2 gabors
                gaborNPC1 = Screen('MakeTexture', w, makeGabor(gaborPat,...
                    orientSet(3),bgColor,colVec(colorSet(3),:)*255,bgColor));
                Screen('Drawtexture', stimWin, gaborNPC1,[],locSets(index(loca3),:));
                DrawFormattedText(stimWin,double(int2str(loca3)),'center','center', ...
                    params.textColor,[],[],[],3,[],locSets(index(loca3),:));

                gaborNPC2 = Screen('MakeTexture', w, makeGabor(gaborPat,...
                    orientSet(4),bgColor,colVec(colorSet(4),:)*255,bgColor));
                Screen('Drawtexture', stimWin, gaborNPC2,[],locSets(index(loca4),:)); 
                DrawFormattedText(stimWin,double(int2str(loca4)),'center','center', ...
                    params.textColor,[],[],[],3,[],locSets(index(loca4),:));
                q1 = Screen('GetImage', stimWin);
                imagename = quadrantLayout(q1, q1, q1, q1, w, bgColor);
                imageTexture = Screen('MakeTexture', w, imagename);
                
                % 4 quadrants
                [screenX, screenY] = Screen('WindowSize', w);

                quadrantCenters = [
                    screenX/4,   screenY/4;    
                    screenX*3/4, screenY/4;    
                    screenX/4,   screenY*3/4;  
                    screenX*3/4, screenY*3/4  
                ];

                baseOffsets = [-19/80 * screenX, 19/80 * screenX];

                DotRects = @(i, n) ...
                    CenterRectOnPoint( ...
                        [0, 0, ...
                        (locSets2(index(n),3) - locSets2(index(n),1)) * 0.5, ... 
                        (locSets20(index(n),4) - locSets2(index(n),2)) * 0.5], ...  
                        quadrantCenters(i,1) + baseOffsets(n), ...                 
                        quadrantCenters(i,2) + 9/40 * screenY ...                   
                    );

                tagRects = @(i,q) ...
                    CenterRectOnPoint( ...
                        [0, 0, ...
                        (locSets2(index(q),3)-locSets2(index(q),1))*0.5, ...
                        (locSets2(index(q),4)-locSets2(index(q),2))*0.5], ...
                        quadrantCenters(i,1) + ...
                            0.5*((locSets2(index(q),1)+locSets2(index(q),3))/2-screenX/2), ...
                        quadrantCenters(i,2) + ...
                            0.5*((locSets2(index(q),2)+locSets2(index(q),4))/2-screenY/2));
                        



                for frames = 1:600
                Screen('DrawTexture', w, imageTexture);                    
                    for i = 1:4             
                        targetPhase = mod((frames-1)*4 + i-1, freqstim) + 1;
                        distractorPhase = mod((frames-1)*4 + i-1, freqdistfull) + 1;
                        Screen('DrawTexture', w, gaborTargetTagTexture{targetPhase}, ...
                            [], tagRects(i,loca1));

                        Screen('DrawTexture', w, gaborDistractTagTexture{distractorPhase}, ...
                            [], tagRects(i,loca2));

                        Screen('DrawTexture', w, gaborTargetDotTexture{targetPhase}, ...
                            [], DotRects(i, 1));

                        Screen('DrawTexture', w, gaborDistractDotTexture{distractorPhase}, ...
                            [], DotRects(i, 2));

                        %Screen('DrawTexture', w, ringTexture, [], tagRects(i,loca1));
                        %Screen('DrawTexture', w, ringTexture, [], tagRects(i,loca2));
                        %Screen('DrawTexture', w, ringTexture, [], tagRects(i,loca3));
                        %Screen('DrawTexture', w, ringTexture, [], tagRects(i,loca4));
                    end
                    if frames == 1
                        stimulusVblTime = Screen('Flip',w, ...
                            fixTime2+params.fixDur-ifi/2);
                        if useTrigger == 1
                            MEGTrigger(device, 1); % send trigger
                        end
                    else
                        stimulusVblTime = Screen('Flip',w);
                    end
                    if isnan(stimulusOnsetTime)
                        stimulusOnsetTime = stimulusVblTime;
                        if EL == 1
                            Eyelink('Message', 'Stim Display');
                        end
                    end
                    stimulusFrameCount = stimulusFrameCount + 1;

                    [~,respSecs,KeyCode] = KbCheck;   % respSecs = response time (GetSecs)
                    checkQuitKey(KeyCode, params.exitKey);
                    if sum(KeyCode([one;two;three;four])) ~= 0
                        Screen('Drawtexture', w, fiximage4Texture);
                        stimulusOffsetTime = Screen('Flip',w);
                        responseDetected = true;
                        decTime = respSecs;   % align decTime with GaborSearch.m (response time)
                        if EL == 1
                            Eyelink('Message', 'Response');
                        end
                        choice = [1 2 3 4] * ...
                            [KeyCode(one) KeyCode(two) KeyCode(three) KeyCode(four)]';%'

                        if choice == loca1
                            Beeper(params.freqC,params.volC,params.duration);
                            Ans = [1 0];      % right
                        else
                            Beeper(params.freqF,params.volF,params.duration);
                            Ans = [0 1];      % false
                        end
                        ResponseTime = frames/120;
                        break
                    end
                end
                if ~responseDetected
                    Screen('Drawtexture', w, fiximage4Texture);
                    stimulusOffsetTime = Screen('Flip',w);
                    ResponseTime = 1;
                end


                fixTime3 = stimulusOffsetTime;
                stimulusDuration = stimulusOffsetTime - stimulusOnsetTime;
                if EL == 1
                    Eyelink('Message', 'Fix 3 Display');
                    % Keep identifiers only; read conditions from the behavior log
                    Eyelink('Message', '!V TRIAL_VAR subID %d', subNo);
                    Eyelink('Message', '!V TRIAL_VAR run %d', run);
                    Eyelink('Message', '!V TRIAL_VAR block %d', block);
                    Eyelink('Message', '!V TRIAL_VAR trial %d', trial);
                    Eyelink('Message', 'TRIAL_RESULT 0');
                end
                Screen('Close', [gaborTarget, gaborDistract, ...
                    gaborNPC1, gaborNPC2, imageTexture]);
                Screen('Close', stimWin);

                responded    = double(responseDetected);
                valid        = 1;      % set to 0 if a frame drop or early response is detected (future)
                triggerCode  = 0;      % reserved for MEG trigger integration
                triggerTime  = NaN;    % reserved: GetSecs() at trigger send time

                TrialData = [subNo, EL, run, block, trial, ...
                    params.ecc, degree, ...
                    tarColor, tarOrient, dstr1Color, dstr1Orient, ...
                    colorSet, orientSet, ...
                    [index(loca1) index(loca2) index(loca3) index(loca4)], ...
                    [loca1 loca2 loca3 loca4], ...
                    choice, Ans, ...
                    startt, cueTime-startt, fixTime2-startt, ...
                    stimulusOnsetTime-startt, decTime-startt, ...
                    fixTime3-startt, fixTime3-startt, ...
                    ppd, ProPixx, ResponseTime, stimulusDuration, ...
                    stimulusFrameCount, ...
                    responded, valid, triggerCode, triggerTime, schemaVersion];

                savedata(Filename, Header, TrialData, Metadataname, Metadata);
                fixTime1 = fixTime3;
            end

            WaitSecs(0.5);
        end

        if EL == 1
            if edfActive
                closeEyeTracker(edfName, saveFolderEL, false, params);
                edfActive = false;
            else
                Eyelink('StopRecording');
                Eyelink('SetOfflineMode');
            end
        end

        % Display break or end message
        Screen('TextSize',w,round(fontSizeP/2)); %screen font size for instruction
        if run < nRun
            brkMess = ['You completed block ' num2str(run) ' out of ' num2str(nRun) ' blocks.\n ' ...
                'You can take a break now.'];
            DrawFormattedText(w,double(brkMess),cx*1/3,cy*5/12+20, ...
                params.textColor,[],[],[],3);
            DrawFormattedText(w,double(brkMess),cx*4/3,cy*5/12+20, ...
                params.textColor,[],[],[],3);
            DrawFormattedText(w,double(brkMess),cx*4/3,cy*17/12+20, ...
                params.textColor,[],[],[],3);
            DrawFormattedText(w,double(brkMess),cx*1/3,cy*17/12+20, ...
                params.textColor,[],[],[],3);
        elseif run == nRun
            Screen('TextSize',w,fontSizeP)
            
            if ProPixx == 1
                initProPixx(0);
            end

            DrawFormattedText(w,double(params.endMessMain),'center','center', ...
                params.textColor,[],[],[],3);

        end
        Screen('Flip', w);
        WaitSecs(0.5);
        [~,~,mbuttons] = GetMouse;
        while mbuttons(1) == 0
            [~,~,mbuttons] = GetMouse;
        end
    end %end run loop
    Screen('Close', [gaborTargetTagTexture{:}, ...
        gaborDistractTagTexture{:}, ringTexture]);

    %% Close experiment
    if EL == 1
        if edfActive
            closeEyeTracker(edfName, saveFolderEL, true, params);
        else
            Eyelink('Shutdown');
        end
    end

    %% The End    
    Screen('CloseAll');
    ShowCursor;
    fclose('all');
    ListenChar(0);
    Priority(0);
catch ME
    % Preserve any open EDF before restoring display and input
    if EL == 1
        if edfActive
            try
                closeEyeTracker(edfName, saveFolderEL, true, params);
            catch MEedf
                fprintf(2, 'Could not receive EDF file: %s\n', MEedf.message);
            end
        end
        try
            Eyelink('Shutdown');
        catch
        end
    end
    Screen('CloseAll');
    ShowCursor;
    fclose('all');
    ListenChar(0);
    Priority(0);
    if strcmp(ME.identifier, 'GaborSearchRIFT:UserQuit')
        fprintf('Experiment aborted by q key.\n');
        return;
    end
    fprintf(2, '\nGaborSearch failed: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf(2, 'File: %s\nLine: %d\n', ME.stack(1).file, ME.stack(1).line);
    end
    rethrow(ME);
end
 