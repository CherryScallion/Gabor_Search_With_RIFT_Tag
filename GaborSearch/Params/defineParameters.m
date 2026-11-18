function [params, gaborPat] = defineParameters()

% Keyboard
KbName('UnifyKeyNames');
params.exitKey = KbName('q');
params.one = KbName('1');
params.two = KbName('2');
params.three = KbName('3');
params.four = KbName('4');

% message
params.eyeMess = ['We are going to calibrate your eyes.\n' ...
    'Please follow a moving dot on the screen.'];
params.prepMess = 'Press the left mouse button to start.';
params.waitMess = 'Get Ready!';
params.gazeMess = 'Please look at the fixation.';
params.endMessPrac = 'You completed practice! \n Any question?';
params.endMessMain = 'Congratulations! You completed this experiment!';

% RT contrain & feedback
params.RTconstrain = 10;
params.volC = 0.4;
params.volF = 0.7;
params.freqC = 850;
params.freqF = 250;
params.duration = 0.25;

% size & distance
params.screenWidth = 59.674; %cm
params.screenHeight = 33.566; %cm
params.screenResolution = [1920 1080]; %pixel
%% Changed Start
params.distance = 77; %cm
%% Changed End
params.stimSize = 3; %circle size in visual angle
params.cueSize = 0.85; %target cue size in visual angle
params.lineWidthPix = 10;

% fixation
params.colorOval = [0 0 0]; %color of the two circles [R G B]
params.colorCross = [125 125 125]; %color of the two circles [R G B]
params.colorCue = [255 0 0]; %color of the Cross [R G B]
params.d1 = 0.55; %diameter of outer circle (degrees)
params.d2 = 0.125; %diameter of inner circle (degrees)

% font
params.fontSize = 1; %font visual angle
%% Changed Start
params.numSize = 0.5;       % dva
%% Changed End

% color
% Load color wheel file relative to this parameters file
thisDir = fileparts(mfilename('fullpath'));
colsFile = fullfile(thisDir, '1deg_cols.txt');
if exist(colsFile, 'file')
    colVec = importdata(colsFile);
    params.colVec = colVec.data;
else
    warning('Color file not found: %s. params.colVec set to empty.', colsFile);
    params.colVec = [];
end
params.fixColor = [0 0 0]; %fixation
params.textColor = [0 0 0]; %text
params.bgColor = [125 125 125]; %background

% Defaults for gabor and timing used by simple test scripts
params.orientation = 0; % degrees
% Use first color from color wheel as default (scale to 0-255)
if ~isempty(params.colVec)
    params.color = params.colVec(1,:)*255;
else
    params.color = [255 255 255];
end
params.fixDur = 0.35; % fixation duration (s)
params.stimDur = 2.0; % stimulus display duration (s)

% gabor
%% Changed Start
params.gaborSpFreq = 2/3;      % cycles/degree
params.gaborSD = 0.75;         % Gaussian sigma in dva
gaborPat.spFreq = params.gaborSpFreq * params.stimSize; % cycles/image
%% Changed End
gaborPat.phase = 0;
gaborPat.contrast = 1;

% search params
params.tarColor = [34 78 110 190 274 324]; %pink-orange, orange-yellow, yellow-green, green-blue, blue-purple, purple-pink
params.tarOrient = [17 37 77 103 143 163];
dstr1Color = [8 16 32];
dstr1Orient = [8 16 32];
params.dstr1ColorSet = repelem(dstr1Color,size(dstr1Color,2));
params.dstr1OrientSet = repmat(dstr1Orient,1,size(dstr1Orient,2));
params.dstr2Color = 60;
params.dstr2Orient = 60;
params.dstr3Color = -60;
params.dstr3Orient = -60;

% wheel params
params.innerSize = 7.15;
params.outerSize = 8;

% exp param
%% Changed Start
params.ecc = 6;
%% Changed End
params.nRun = 2;  %%  6
params.nBlock = 2;  %%  10
params.nSearch = size(params.dstr1ColorSet,2);
params.nWheel = 0;

%% Set interest-area properties
params.fixRectSize = params.stimSize; % Match the stimulus IA side in dva
params.fixIA = 99;
params.fixBoxColor = 15;            % Host fixation box
params.stimBoxColors = [4 2 1 1];    % Target, distractor 1, other distractors
params.fixIARGB = [255 255 255];     % Data Viewer fixation area
params.stimIARGB = [255 0 0; 0 255 0; 0 0 255; 0 0 255];

%% Set EyeLink properties
params.startKey = KbName('space');
%% Changed Start
params.pollDur = 0.001;   % s
%% Changed End
params.textSpacing = 3;
params.eye.dummyMode = 0;
params.eye.calType = 'HV9';
params.eye.tarSize = 1;   % Percent of screen width
params.eye.tarWidth = 0.5;
params.eye.sampleRate = 1000;  % Hz
params.eye.idleDelay = 0.05;   % s
params.eye.recordDelay = 0.1;  % s
params.eye.closeDelay = 0.5;   % s
params.eye.screenDistMm = [595 605]; % mm, eye to display top and bottom
params.eye.fileEvtFilter = 'LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,INPUT';
params.eye.linkEvtFilter = 'LEFT,RIGHT,FIXATION,SACCADE,BLINK';
params.eye.fileSampData = 'LEFT,RIGHT,GAZE,HREF,AREA,HTARGET,GAZERES,STATUS,INPUT';
params.eye.linkSampData = 'LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT';
