%Created by CherryScallion, Oct.2026
%%%%%%%
function GaborSearchRIFT(subNo, EL, ProPixx)

%% Sub ID Input
if nargin == 0 % if no input arguments, ask for subID
    promptParams = {'Subject ID', 'EL(0:No, 1:Yes)', 'ProPixx' };
    settings = inputdlg(promptParams, 'settings', 1, {'100', '0','0'});
    subNo = str2double(settings{1});
    EL = str2double(settings{2});
    ProPixx = str2double(settings{3}); % default to ProPixx enabled
end

AssertOpenGL;
KbName('UnifyKeyNames');
Screen('Preference', 'SkipSyncTests', 1); % skip sync tests
rng('shuffle'); % shuffle random number generator
%% Create and open data file
% Create data folder and path
if ProPixx == 1
    initProPixx(1);
end

%% Open params
[params, gaborPat] = defineParameters();
% dva calculation
Resolution = params.screenResolution;
width = params.screenWidth;
height = params.screenHeight;
dva = 2*atand((width/2)/params.distance);
dva2pixels = @(inputDva) inputDva .* Resolution(1) ./ dva;

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
targetFolder = fullfile(currentFileFolder, 'search'); % ?
GaborFolder = fullfile(dataFolder, 'GaborSearch');
saveFolder = fullfile(GaborFolder, 'Behavioral');
saveFolderEL = fullfile(GaborFolder, 'EL');
if ~exist(saveFolder, 'dir')
    mkdir(saveFolder);
end
if ~exist(saveFolderEL, 'dir')
    mkdir(saveFolderEL);
end
TimingFilename = fullfile(saveFolder, sprintf('S%03d_StimulusTiming.csv', subNo));
addpath(targetFolder)
addpath(dataFolder)

el = [];
eyelinkInitialized = false;
eyelinkFileOpen = false;
eyelinkRecording = false;
edfFile = '';
edfPath = '';

try
    screens = max(Screen('Screens'));
    HideCursor;
    [w, screenRect] = Screen('OpenWindow', screens, 0, [], 32, 2); % PTB fullscreen window, black background, 32 bit color depth, multi-sampling 2
    Screen('FillRect',w,bgColor);
    [cx, cy] = RectCenter(screenRect);
    Screen('BlendFunction',w,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA); 
    ifi = Screen('GetFlipInterval',w); %inter flip interval

    % Convert visual angle to pixels using configured screen dimensions.
    ppd = dva2pixels(1);

    % Font size and font type
    fontSizeP = round(ppd*params.fontSize,0);
    Screen('TextFont',w,'Arial');
    Screen('TextSize',w,fontSizeP);

    %stimsize calculation 
    stimSizeP = ppd * params.stimSize;
 
    baseRect = [0 0 stimSizeP stimSizeP];
    fixRect = [0 0 ppd*params.d1 ppd*params.d1];
    centerRect = round(CenterRectOnPointd(baseRect, cx, cy));

    %Eyelink and fixation box size
    ELBox = round(ppd, 0);
    fixBox = round(ppd * 1.75, 0);
    fixDiag = ((ppd*params.d1+fixBox*2)*sqrt(2))/2;
    fixCoord = [centerRect(1)-fixBox centerRect(2)-fixBox ...
        centerRect(3) + fixBox centerRect(4)+fixBox]; %fixation caculation

    eccP = round(ppd*params.ecc, 0);

    cueSizeP = round(ppd*params.cueSize,0);
    gaborPat.size = round(ppd*params.stimSize,0);
    gaborPat.sd = round(gaborPat.size/4,0);          

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

    % Columns 1-40 match ReferenceCodes/GaborSearch.m in name, order and
    % meaning so both scripts share the same analysis pipeline. Columns 41+
    % are RIFT-specific extras.
    Header = {'subID', 'eyelink', 'run', 'block', 'trial', 'type', 'wheelType', ...
        'eccentricity', 'degOrient', 'ppd', ...
        'tarColor', 'tarOrient', 'dstr1Color', 'dstr1Orient', ...
        'color1', 'color2', 'color3', 'color4', ...
        'orient1', 'orient2', 'orient3', 'orient4', ...
        'loc1', 'loc2', 'loc3', 'loc4', ...
        'num1', 'num2', 'num3', 'num4', ...
        'response', 'right', 'wrong', ...
        'startTime', 'cueTime', 'fixTime2', 'testTime', 'decTime', ...
        'fixTime3', 'fixTime1', ...
        'proPixx', 'responseTime', 'stimDuration', 'stimFrames', ...
        'responded', 'valid', 'triggerCode', 'triggerTime', 'schemaVersion'};


    %% RIFT Tag Settings, render the tag textures for target and distractor
    freqstim = 8; % 480hz / 60Hz
    freqdistfull = 15; % 480hz / 64Hz * 2 for interleaving
    gaborTargetTagTexture = cell(1, freqstim);
    gaborTargetDotTexture = cell(1, freqstim);
    for i = 1:freqstim
        gaborTargetTagTexture{i} = Screen('MakeTexture', w, ...
            makeGaborRIFT(gaborPat, bgColor, freqstim, i-1, 1, 0)); %gaborpat, colorBG, freqRIFT, frames, ratio, isvalid
        gaborTargetDotTexture{i} = Screen('MakeTexture', w, ...
            makeGaborRIFT(gaborPat, bgColor, freqstim, i-1, 0.3, 1));
    end
    gaborDistractTagTexture = cell(1, freqdistfull);
    gaborDistractDotTexture = cell(1, freqdistfull);
    for i = 1:freqdistfull
        gaborDistractTagTexture{i} = Screen('MakeTexture', w, ...
            makeGaborRIFT(gaborPat, bgColor, freqdistfull/2, i-1, 1, 0));
        gaborDistractDotTexture{i} = Screen('MakeTexture', w, ...
            makeGaborRIFT(gaborPat, bgColor, freqdistfull/2, i-1, 0.3, 1));
    end
    %% RIFT Tag Settings End

    % make a fixation image with 4 quadrants
    stimWin = Screen('OpenOffscreenWindow', w, bgColor);
    Screen('WindowKind', stimWin);
    arcFixation(stimWin, cx, cy, ppd, 99, params);
    fiximage = Screen('GetImage', stimWin);
    fiximageTexture = Screen('MakeTexture',w, fiximage)
    fiximage4 = quadrantLayout(fiximage, fiximage, fiximage, fiximage, w, bgColor);
    fiximage4Texture = Screen('MakeTexture',w, fiximage4)
    Screen('Close', stimWin);


    %% Exp Start
    for run = 1:nRun %% change it if the code crashes
        % Display eye calibration message
        if run == 1 && EL == 1 % run the eye calibration only for every first run
            DrawFormattedText(w,double(params.eyeMess),'center','center', ...
                params.textColor,[],[],[],3);
            Screen('Flip',w);
            WaitSecs(0.5);
            [~,~,mbuttons] = GetMouse; % should i use keyboard?
            while mbuttons(1) == 0
                [~,~,mbuttons] = GetMouse;
            end
        end

        %%%%%%%%%%%%%%%%%%%%% EYELINK SETUP %%%%%%%%%%%%%%%%%%%%%
        % Initialize the EyeLink connection only once, at run 1.
        if run == 1 && EL == 1
            dummyMode = 0;

            % Initialize EyeLink defaults.
            InitializePsychSound;
            el = EyelinkInitDefaults(w);

            el.calibrationtargetsize = 1.5;
            el.calibrationtargetwidth = 0.75;
            EyelinkUpdateDefaults(el);

            % Configure calibration and display colors.
            el.backgroundcolour = bgColor;
            el.calibrationtargetcolour = params.fixColor;
            el.foregroundcolour = WhiteIndex(el.window);
            el.msgfontcolour = params.textColor;
            el.imgtitlecolour = WhiteIndex(el.window);
            EyelinkUpdateDefaults(el);            
            if ~EyelinkInit(dummyMode, 1)
                cleanup;
                return;
            end

            % Configure the sample data sent over the link.
            Eyelink('Command', ...
                'link_sample_data=LEFT,RIGHT,GAZE,AREA');
        end

        % Open a separate EDF file for every run.
        if EL == 1
            % Perform the initial calibration only in run 1.
            if run == 1
                EyelinkDoTrackerSetup(el);
                EyelinkDoDriftCorrection(el);
            end


            Eyelink('Command', 'set_idle_mode');
            Eyelink('Command', 'clear_screen %d', 0);
            WaitSecs(0.05);

            % Open a separate EDF file for each run.
            edfFile = sprintf('S%03dR%d.edf', subNo, run);
            edfPath = fullfile(saveFolderEL, edfFile);
            Eyelink('Openfile', edfFile);
        end
        %%%%%%%%%%%%%%%%%%%% EYELINK FILE SETUP End %%%%%%%%%%%%%%%%


        % prompt message for the start of the run
        Screen('TextSize',w,fontSizeP/2);
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
            Eyelink('Command','set_idle_mode');
            WaitSecs(0.05);
            % Start recording eye position
            Eyelink('StartRecording');
            WaitSecs(0.1); %wait a moment for recording to have definitely started
            % Mark when the experiment has actually started
            Eyelink('Message','SYNCTIME');
        end
        % Get experiment start time since startup
        startt = GetSecs();
  
        Screen('Drawtexture', w, fiximage4Texture); % display fixation
        fixTime1 = Screen('Flip',w);
        if EL == 1
            Eyelink('Message','fixTime1');
        end

        for block = 1:nBlock
            dstr1Prop = [params.dstr1ColorSet; params.dstr1OrientSet]; %dstr1 parameters
            dstr1Prop = dstr1Prop(:,randperm(nSearch));
            for trial = 1:nTrial
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
                coord = nan(nStimSearch,4);
                for i = 1:nStimSearch
                    locSets(i,:) = round(CenterRectOnPointd(baseRect, ...
                        cx+cosd(degree+(360/nStimSearch)*(i-1))*eccP, ...
                        cy-sind(degree+(360/nStimSearch)*(i-1))*eccP));
                    coord(i,:) = [locSets(i,1)-ELBox locSets(i,2)-ELBox ...
                        locSets(i,3)+ELBox locSets(i,4)+ELBox];
                end
                locSets2 = nan(nStimSearch,4);
                for i = 1:nStimSearch
                    locSets2(i,:) = round(CenterRectOnPointd(baseRect*2, ...
                        cx+cosd(degree+(360/nStimSearch)*(i-1))*eccP, ...
                        cy-sind(degree+(360/nStimSearch)*(i-1))*eccP));
                end

                if EL == 1
                    % Clear tracker display
                    Eyelink('Command','clear_screen %d',0);
                    WaitSecs(0.05);
                    % Draw interest area box on host pc
                    Eyelink('Command','draw_box %d %d %d %d 15',...
                    fixCoord(1,1),fixCoord(1,2),fixCoord(1,3),fixCoord(1,4));
                    for i = 1:size(coord,1)
                        Eyelink('Command','draw_box %d %d %d %d 15',...
                        coord(i,1),coord(i,2),coord(i,3),coord(i,4));
                    end
                    Eyelink('Message', 'TRIALID %d', trial+nTrial*(block-1));
                    Eyelink('Command','record_status_message "TRIAL %d/%d"',...
                        trial+nTrial*(block-1),nTrial*nBlock);
                end

                % Display target cue
                xCoords = [cueSizeP*sind(tarOrient)/2 -cueSizeP*sind(tarOrient)/2];
                yCoords = [-cueSizeP*cosd(tarOrient)/2 cueSizeP*cosd(tarOrient)/2];
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
                    Eyelink('Message','cueTime');
                end

                % Display fixation
                Screen('Drawtexture', w, fiximage4Texture);
                fixTime2 = Screen('Flip',w,cueTime+cueDur-ifi/2);
                if EL == 1
                    Eyelink('Message','fixTime2');
                end
                
                % testTime = 999;                 % OLD: stimulus onset is now saved in the testTime column
                % number = randperm(4);           % OLD: displayed labels are now saved as num1..num4
                index = randperm(4);
                locIndex = randperm(4);
                loca1 = locIndex(1);
                loca2 = locIndex(2);
                loca3 = locIndex(3);
                loca4 = locIndex(4);
                Ans = [0 0];
                stimWin = Screen('OpenOffscreenWindow', w, bgColor);
                Screen('WindowKind', stimWin);
                Screen('Drawtexture', stimWin, fiximageTexture); % draw fixation

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
                
                baseOffsets = [-1/5 * screenX, 1/5 * screenX];
                DotRects = @(i, n) ...
                    CenterRectOnPoint( ...
                        [0, 0, ...
                        (locSets2(index(n),3) - locSets2(index(n),1)) * 0.5, ... 
                        (locSets2(index(n),4) - locSets2(index(n),2)) * 0.5], ...  
                        quadrantCenters(i,1) + baseOffsets(n), ...                 
                        quadrantCenters(i,2) + 1/5 * screenY ...                   
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
                    end
                    if frames == 1
                        stimulusVblTime = Screen('Flip',w, ...
                            fixTime2+params.fixDur-ifi/2);
                    else
                        stimulusVblTime = Screen('Flip',w);
                    end
                    if isnan(stimulusOnsetTime)
                        stimulusOnsetTime = stimulusVblTime;
                        if EL == 1
                            Eyelink('Message','testTime');
                        end
                    end
                    stimulusFrameCount = stimulusFrameCount + 1;

                    [~,respSecs,KeyCode] = KbCheck;   % respSecs = response time (GetSecs)
                    if sum(KeyCode([one;two;three;four])) ~= 0
                        Screen('Drawtexture', w, fiximage4Texture);
                        stimulusOffsetTime = Screen('Flip',w);
                        responseDetected = true;
                        decTime = respSecs;   % align decTime with GaborSearch.m (response time)
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
                    else
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
                    Eyelink('Message','fixTime3');
                    Eyelink('Message','!V IAREA RECTANGLE %d %d %d %d %d %d',1, ...
                        fixCoord(1,1),fixCoord(1,2), ...
                        fixCoord(1,3),fixCoord(1,4), ...
                        99);
                    loclabel = 1:nStimSearch;
                    for i = 1:nStimSearch
                        Eyelink('Message','!V IAREA RECTANGLE %d %d %d %d %d %d',i, ...
                            coord(index(i),1),coord(index(i),2), ...
                            coord(index(i),3),coord(index(i),4), ...
                            loclabel(i));
                    end
                    Eyelink('Message','!V TRIAL_VAR subID %d',subNo);
                    Eyelink('Message','!V TRIAL_VAR run %d',run);
                    Eyelink('Message','!V TRIAL_VAR block %d',block);
                    Eyelink('Message','!V TRIAL_VAR trial %d',trial);
                    Eyelink('Message','!V TRIAL_VAR degOrient %d',degree);
                    Eyelink('Message','!V TRIAL_VAR tarColor %d',tarColor);
                    Eyelink('Message','!V TRIAL_VAR tarOrient %d',tarOrient);
                    Eyelink('Message','!V TRIAL_VAR dstr1Color %d',dstr1Color);
                    Eyelink('Message','!V TRIAL_VAR dstr1Orient %d',dstr1Orient);
                    Eyelink('Message','!V TRIAL_VAR right %d',Ans(1));
                end
                Screen('Close', [gaborTarget, gaborDistract, ...
                    gaborNPC1, gaborNPC2, imageTexture]);
                Screen('Close', stimWin);


                % =====================================================================
                % OLD (replaced) trial-data assembly:
                % TrialData = [subNo, EL, run, block, trial, ...
                %     params.ecc, degree, ppd, ...
                %     tarColor, tarOrient, dstr1Color, dstr1Orient, ...
                %     colorSet, orientSet, index, number, ...
                %     choice, Ans, ...
                %     startt, cueTime-startt, fixTime2-startt, ...
                %     testTime-startt, decTime-startt, ...
                %     ResponseTime, fixTime3-startt, fixTime1-startt];
                % savedata(Filename, Header, TrialData, Metadataname, Metadata);
                % =====================================================================

                % RIFT is search-only: type = 4 (search), wheelType = 999, matching
                % the convention used by ReferenceCodes/GaborSearch.m search trials.
                trialType = 4;
                wheelType = 999;

                % Per-trial flags and reserved columns (triggers are wired up later).
                responded    = double(responseDetected);
                valid        = 1;      % set to 0 if a frame drop or early response is detected (future)
                triggerCode  = 0;      % reserved for MEG trigger integration
                triggerTime  = NaN;    % reserved: GetSecs() at trigger send time

                TrialData = [subNo, EL, run, block, trial, trialType, wheelType, ...
                    params.ecc, degree, ppd, ...
                    tarColor, tarOrient, dstr1Color, dstr1Orient, ...
                    colorSet, orientSet, ...
                    [index(loca1) index(loca2) index(loca3) index(loca4)], ...
                    [loca1 loca2 loca3 loca4], ...
                    choice, Ans, ...
                    startt, cueTime-startt, fixTime2-startt, ...
                    stimulusOnsetTime-startt, decTime-startt, ...
                    fixTime3-startt, fixTime3-startt, ...
                    ProPixx, ResponseTime, stimulusDuration, stimulusFrameCount, ...
                    responded, valid, triggerCode, triggerTime, schemaVersion];
                savedata(Filename, Header, TrialData, Metadataname, Metadata);

                fixTime1 = fixTime3;
            end

            WaitSecs(0.5);

            [~,~,KeyCode] = KbCheck;
            if(KeyCode(params.exitKey) == 1)
                Screen('CloseAll');
                ShowCursor;
                fclose('all');
                ListenChar(0);
                Priority(0);
                error('The experiment is aborted by user.');
            end
            KeyCode(KeyCode==1) = 0;
        end

        if EL == 1
            Eyelink('Message','RUN_END %d',run);
            Eyelink('StopRecording');
            eyelinkRecording = false;
            Eyelink('Command','set_idle_mode');
            WaitSecs(0.5);
            closeStatus = Eyelink('CloseFile');
            if closeStatus ~= 0
                error('GaborSearchRIFT:EyeLinkCloseFileFailed', ...
                    'Could not close EyeLink data file "%s" (status %d).', ...
                    edfFile, closeStatus);
            end
            eyelinkFileOpen = false;
            receiveStatus = Eyelink('ReceiveFile',edfFile,edfPath);
            if receiveStatus < 0
                error('GaborSearchRIFT:EyeLinkReceiveFileFailed', ...
                    'Could not receive EyeLink data file "%s" (status %d).', ...
                    edfFile, receiveStatus);
            end
        end

        % Display break or end message
        Screen('TextSize',w,fontSizeP/2); %screen font size for instruction
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
    Screen('Close', [gaborTargetTagTexture{:}, gaborTargetDotTexture{:}, ...
        gaborDistractTagTexture{:}, gaborDistractDotTexture{:}]);
    if EL ==1
        Eyelink('Shutdown');
        eyelinkInitialized = false;
    end

    %% The End    
    Screen('CloseAll');
    ShowCursor;
    fclose('all');
    ListenChar(0);
    Priority(0);
catch ME
    if eyelinkInitialized
        try
            if eyelinkRecording
                Eyelink('StopRecording');
            end
            Eyelink('Command','set_idle_mode');
            WaitSecs(0.05);
            if eyelinkFileOpen
                Eyelink('CloseFile');
                eyelinkFileOpen = false;
                receiveStatus = Eyelink('ReceiveFile',edfFile,edfPath);
                if receiveStatus < 0
                    warning('GaborSearchRIFT:EyeLinkReceiveFileFailed', ...
                        'Could not receive EyeLink data file "%s" during cleanup (status %d).', ...
                        edfFile, receiveStatus);
                end
            end
        catch cleanupME
            warning('GaborSearchRIFT:EyeLinkCleanupFailed', ...
                'EyeLink cleanup failed: %s', cleanupME.message);
        end
        try
            Eyelink('Shutdown');
        catch cleanupME
            warning('GaborSearchRIFT:EyeLinkShutdownFailed', ...
                'EyeLink shutdown failed: %s', cleanupME.message);
        end
    end
    Screen('CloseAll');
    ShowCursor;
    fclose('all');
    ListenChar(0);
    Priority(0);
    fprintf(2, '\nGaborSearch failed: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf(2, 'File: %s\nLine: %d\n', ME.stack(1).file, ME.stack(1).line);
    end
    rethrow(ME);
end
 