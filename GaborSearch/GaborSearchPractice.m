function GaborSearchPractice(subNo)
%Modulated by Cherry Scallion Oct.2026
%%%%%%%%%%%%%%%%%%%%

%% Sub ID Input
if nargin == 0
    promptParams = {'Subject ID'};
    settings = inputdlg(promptParams,'settings',1,{'100'}); %% default settings
    subNo = str2double(settings{1});
end
AssertOpenGL;
Screen('Preference','SkipSyncTests',0);
rng('shuffle'); %random numbers generated from different calls are all different

%% Create and open data file
% Create data folder
currentFileFolder = fileparts(mfilename('fullpath'));
dataFolder = fullfile(currentFileFolder, '..', 'data');
GaborFolder = fullfile(dataFolder, 'GaborSearch');
saveFolder = fullfile(GaborFolder, 'Behavioral');
if ~exist(saveFolder, 'dir')
    mkdir(saveFolder);
end

%% Experiment parameters
currentFileFolder = fileparts(mfilename("fullpath"));
targetFolder = fullfile(currentFileFolder, 'search');
addpath(targetFolder)
addpath(dataFolder)
%% here is the path index
%addpath('./search');

[params, gaborPat] = defineParameters();
colVec = params.colVec; %color wheel
bgColor = params.bgColor; %background color
distance = params.distance; %distance between eyeball and screen
innerSize = params.innerSize;
outerSize = params.outerSize;
one = params.one;
two = params.two;
three = params.three;
four = params.four;
nRun = 1;
nBlock = 2;
nSearch = 9;
nWheel = 0;
nTrial = nSearch+nWheel;
wheelType = Shuffle(repelem([1 2],nRun*nBlock*nWheel/2));

%% Main Experiement
accuracyCorrect = 0;
accuracyTrialCount = 0;
try
    screens = max(Screen('Screens'));
    HideCursor;
    [w,screenRect] = Screen('OpenWindow',screens,0,[],32,2);
    Screen('FillRect',w,bgColor);
    Screen('Preference','SkipSyncTests',0);
    [cx,cy] = RectCenter(screenRect);
    [width, ~] = Screen('WindowSize',w);
    Screen('BlendFunction',w,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);

    ppd = pi*width / atan(params.screenWidth/ distance/2) /360; %pixel per degree
    stimSizeP = ppd*params.stimSize;
    baseRect = [0 0 stimSizeP stimSizeP];
    fixRect = [0 0 ppd*params.d1 ppd*params.d1];
    centerRect = round(CenterRectOnPointd(fixRect,cx,cy));
    ELBox = round(ppd,0); %eye link box
    fixBox = round(1.75*ppd,0); %fixation box
    fixDiag = ((ppd*params.d1+fixBox*2)*sqrt(2))/2;
    fixCoord = [centerRect(1)-fixBox centerRect(2)-fixBox ...
        centerRect(3)+fixBox centerRect(4)+fixBox]; %fixation
    eccP = round(ppd*params.ecc,0);
    cueSizeP = round(ppd*params.cueSize,0);
    gaborPat.size = round(ppd*params.stimSize,0);
    gaborPat.sd = round(gaborPat.size/4,0);

    fps = Screen('FrameRate',w); %frames per second
    ifi = Screen('GetFlipInterval',w); %inter flip interval
    if fps == 0
        fps = 1/ifi;
    end

    fontSizeP = round(ppd*params.fontSize,0);
    Screen('TextFont',w,'Arial');
    Screen('TextSize',w,fontSizeP);
    ListenChar(2);

    Priority(MaxPriority(w)); %MaxPriority(w) = 1 on eye tracking computer


    %% Exp Start
    for run = 1:nRun
        
        %% Screen setup...?
        % Change background color back to gray
        Screen('FillRect',w,bgColor);
        % "Get ready"
        DrawFormattedText(w,double(params.waitMess),'center','center', ...
            params.textColor,[],[],[],3);
        Screen('Flip',w);
        [~,~,mbuttons] = GetMouse;
        while mbuttons(1) == 0
            [~,~,mbuttons] = GetMouse;
        end
        WaitSecs(0.5);
        % Display fixation
        arcFixation(w,cx,cy,ppd,99,params);
        fixTime1 = Screen('Flip',w);
        startt = GetSecs();

        for block = 1:nBlock
            type = Shuffle([repelem(4,nSearch) repelem(1,nWheel)]); %trial type
            idx = find(type==1);
            while (sum(diff(idx)==1)~=0)
                type = Shuffle([repelem(4,nSearch) repelem(1,nWheel)]);
                idx = find(type==1);
            end
            dstr1Prop = [params.dstr1ColorSet; params.dstr1OrientSet]; %dstr1 parameters
            dstr1Prop = dstr1Prop(:,randperm(nSearch));
            gazeCorrect = ones(1,nTrial); %gaze contigency

            for trial = 1:nTrial
                % Target and distractor colors
                tarColor = params.tarColor(randperm(length(params.tarColor),1));
                tarOrient = params.tarOrient(randperm(length(params.tarOrient),1));
                colorSet = repelem(999,4); orientSet = repelem(999,4);
                index = repelem(999,4); number = repelem(999,4);
                dstr1Color = 999; dstr1Orient = 999;
                nStimSearch = size(colorSet,2);

                if type(trial) == 4 %search trial
                    dstr1Color = dstr1Prop(1,1); dstr1Orient = dstr1Prop(2,1);
                    dstr1Prop(:,1) = [];
                    npColor = randsample([-1 1],1); %1 - pos rotate; %-1 - neg rotate
                    npOrient = randsample([-1 1],1); %1 - pos rotate; %-1 - neg rotate
                    colorSet = tarColor+[0 npColor*dstr1Color params.dstr2Color ...
                        params.dstr3Color];
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
                end



                %Cue duration, fixation duration, response, answer, decision time
                %basically display time and response time
                
                % Time, location and eyelink parameters
                cueDur = 0.5; fixDur = 0.35;
                choice = NaN; Ans = [0 0]; decTime = NaN;
                if type(trial) == 4
                    wType = 999;
                    options = [30, 60];
                    degree = options(randi(2));%randi([0,359],1);
                elseif type(trial) == 1
                    wType = wheelType(1); wheelType(1) = [];
                    if wType == 1
                        degree = randi([1,360],1);
                    elseif wType == 2
                        degree = 0;
                    end
                end
                if type(trial) == 4
                    locSets = nan(nStimSearch,4); coord = nan(nStimSearch,4);
                    for i = 1:nStimSearch
                        locSets(i,:) = round(CenterRectOnPointd(baseRect, ...
                            cx+cosd(degree+(360/nStimSearch)*(i-1))*eccP, ...
                            cy-sind(degree+(360/nStimSearch)*(i-1))*eccP));
                        coord(i,:) = [locSets(i,1)-ELBox locSets(i,2)-ELBox ...
                            locSets(i,3)+ELBox locSets(i,4)+ELBox];
                    end
                end

                % Display target cue
                xCoords = [cueSizeP*sind(tarOrient) -cueSizeP*sind(tarOrient)];
                yCoords = [-cueSizeP*cosd(tarOrient) cueSizeP*cosd(tarOrient)];
                Screen('DrawLines',w,[xCoords; yCoords],params.lineWidthPix, ...
                    colVec(tarColor,:)*255,[cx cy],2);
                cueTime = Screen('Flip',w,fixTime1+0.35-ifi/2);
                % Display fixation
                arcFixation(w,cx,cy,ppd,99,params);
                fixTime2 = Screen('Flip',w,cueTime+cueDur-ifi/2);


                %% Display test stimuli
                Screen('TextSize',w,round(fontSizeP/2,0));
                if type(trial) == 4 %gabor search
                    index = randperm(nStimSearch);
                    number = randperm(nStimSearch);
                    arcFixation(w,cx,cy,ppd,99,params);
                    for i = 1:nStimSearch
                        gabor = Screen('MakeTexture',w,makeGabor(gaborPat,orientSet(i), ...
                            bgColor,colVec(colorSet(i),:)*255,bgColor));
                        Screen('Drawtexture',w,gabor,[],locSets(index(i),:));
                        DrawFormattedText(w,double(int2str(number(i))),'center','center', ...
                            params.textColor,[],[],[],3,[],locSets(index(i),:));
                    end
                elseif type(trial) == 1 %memory wheel
                    wheel = Screen('MakeTexture',w,makeWheel(wType,ppd,params));
                    Screen('DrawTexture',w,wheel,[],[],degree);
                end
                testTime = Screen('Flip',w,fixTime2+fixDur-ifi/2);

                % Wait for response
                if type(trial) == 4 %gabor search
                    [~,~,KeyCode] = KbCheck;
                    while sum(KeyCode([one;two;three;four]))==0 && ...
                            (GetSecs-testTime<params.RTconstrain)
                        [~,decTime,KeyCode] = KbCheck;
                        if ~(sum(KeyCode([one;two;three;four]))==0)
                            choice = [1 2 3 4]*[KeyCode(one) KeyCode(two) KeyCode(three) KeyCode(four)]';%'
                            if choice == number(1)
                                Beeper(params.freqC,params.volC,params.duration);
                                Ans = [1 0]; %right
                            else
                                Beeper(params.freqF,params.volF,params.duration);
                                Ans = [0 1]; %false
                            end
                        end
                    end
                elseif type(trial) == 1 %memory wheel
                   SetMouse(cx,cy);
                    mouse = [0 0 0]; r = 0;
                    while (sum(mouse)==0 || (r<innerSize*ppd) || (r>outerSize*ppd)) ...
                            && (GetSecs-testTime<params.RTconstrain)
                        Screen('DrawTexture',w,wheel,[],[],degree);
                        [x,y,mouse] = GetMouse;
                        decTime = GetSecs();
                        Screen('FillOval',w,[90 90 90],[x-6 y-6 x+6 y+6]); %mouse location
                        r = sqrt((x-cx)^2+(y-cy)^2);
                        if (r>=innerSize*ppd) && (r<=outerSize*ppd)
                            if wType == 1
                                if y-cy <= 0
                                    rotation = acos((x-cx)/r)*180/pi;
                                elseif y-cy > 0
                                    rotation = 360-acos((x-cx)/r)*180/pi;
                                end
                                choice = mod(floor(rotation+degree)+1,360);
                                if choice <= 0
                                    choice = choice+360;
                                end
                                Screen('FillOval',w,colVec(choice,:)*255, ...
                                    CenterRectOnPointd(baseRect,cx,cy), ...
                                    max(baseRect)*1.01);
                            elseif wType == 2
                                if x-cx > 0
                                    rotation = 180-acos((y-cy)/r)*180/pi;
                                elseif x-cx <= 0
                                    rotation = acos((y-cy)/r)*180/pi;
                                end
                                choice = mod(floor(rotation),180);
                                Screen('DrawLines',w, ...
                                    [ppd*sind(choice) -ppd*sind(choice); ...
                                    -ppd*cosd(choice) ppd*cosd(choice)], ...
                                    params.lineWidthPix, ...
                                    [0 0 0],[cx cy],2); %length of inner line is 2 deg
                            end
                        end
                        Screen('Flip',w);
                    end
                end



                % Display fixation
                arcFixation(w,cx,cy,ppd,99,params);
                fixTime3 = Screen('Flip',w);



                % Gaze contigency
                WaitSecs(0.5);
                fixTime1 = fixTime3+0.5;
                
                % Exit the program
                [~,~,KeyCode] = KbCheck;
                if(KeyCode(params.exitKey) == 1)
                    Screen('CloseAll');
                    ShowCursor;
                    fclose('all');
                    ListenChar(0);
                    Priority(0);
                    error('The experiment is aborted by user.');
                end
                % keyCode A 256-element logical array.
                % Each bit within the logical array represents one keyboard key.
                % If a key is pressed, its bit is set, othewise the bit is clear.
                KeyCode(KeyCode==1) = 0;

                if type(trial) == 4
                    accuracyCorrect = accuracyCorrect + Ans(1);
                    accuracyTrialCount = accuracyTrialCount + 1;
                end

            end %end trial loop
        end %end block loop

        % Display break or end message
        endMessPracWithAccu = ['You have completed the practice session.\n' ...
            'Your accuracy is ' ...
            num2str(100*accuracyCorrect/accuracyTrialCount) ' %.\n' ...
            'Please wait for the experimenter to continue.'];
        Screen('TextSize',w,fontSizeP); %screen font size for instruction
        if run < nRun
            brkMess = ['You completed block ' num2str(run) ' out of ' num2str(nRun) ' blocks.\n ' ...
                'You can take a break now.'];
            DrawFormattedText(w,double(brkMess),'center','center', ...
                params.textColor,[],[],[],3);
        elseif run == nRun
            DrawFormattedText(w,double(endMessPracWithAccu),'center','center', ...
                params.textColor,[],[],[],3);
        end
        Screen('Flip', w);
        WaitSecs(0.5);
        [~,~,mbuttons] = GetMouse;
        while mbuttons(1) == 0
            [~,~,mbuttons] = GetMouse;
        end
    end

    %% The End
    Screen('CloseAll');

    ShowCursor;
    fclose('all');
    ListenChar(0);
    Priority(0);
end
rmpath(targetFolder)