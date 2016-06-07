settings = [];
dataDir = 'D:\Data\Selmaan';
expName = input('Experiment Name? ','s');
thisFileName = fullfile(dataDir,expName);
%% Parameters

settings.nTrials = 15;
settings.barWidth = 5; % Degrees
settings.barSpeed = 8; % Degrees per second
settings.checkerWidth = 5; % Degrees
settings.checkerHeight = 5; % Degrees
settings.checkerBlinkRate = 10; % Camera Frames per Phase Shift
settings.flipMod = 2; % (monitor refresh rate) / (camera imaging rate and/or display update rate)
settings.redLED = 1;
settings.blueLED = 1;
%% Initialize DAQ and Data Logging

camControl = daq.createSession('ni');
dCh = addDigitalChannel(camControl,'Dev1','Port0/Line0:2','OutputOnly');


%% Initialize Variables and Settings

if numel(Screen('Screens')) > 1
    settings.screen.id = 2; % Choose primary monitor;
else
    settings.screen.id = 0; % Choose primary monitor;
end
settings.screen.width = 2560;
settings.screen.height = 1440;
settings.screen.hz = 120;
settings.screen.deg2pix = 15; %Pixels per Degree
% calibrated for average in vertical direction (~20 for horizontal on
% average, but this includes very wide angles that are less relevant)

retSynch = struct;
retSynch.nFrame = uint32(0);
retSynch.nTrial = uint16(0);
retSynch.trialOnsets = uint32(0);
retSynch.trialConditions = uint16(0);
retSynch.barLocation = pi*1e6;
retSynch.isTrialDone = true;
retSynch.barVerticalTrial = true;
retSynch.posDirectionTrial = true;
retSynch.redLED = settings.redLED;
retSynch.blueLED = settings.blueLED;

%% Create Textures

% Make checkerboard
settings.w = settings.checkerWidth * settings.screen.deg2pix; %width in pixels
settings.h = settings.checkerHeight * settings.screen.deg2pix; %height in pixels

white=255;
black=0;
gray=white/2;
inc=white-gray;  
x = 1:settings.screen.width + 4 * settings.h;
checkerPattern = gray + inc.*repmat(square(pi*x/settings.h)',1,settings.w);
settings.textureSize = size(checkerPattern);



%% Screen Setup

[retScreen]=Screen('OpenWindow',settings.screen.id, gray);

Priority(1);

checkerTex=Screen('MakeTexture', retScreen, checkerPattern);
checkerTransTex=Screen('MakeTexture', retScreen, checkerPattern');
ifi=Screen('GetFlipInterval', retScreen);
vbl=Screen('Flip', retScreen);
settings.barPixFrame = settings.barSpeed * settings.screen.deg2pix *...
    ifi * settings.flipMod;

%% Display and Acquisition Loop

retSynch.thisCondition = 0;
stillImaging = 1;
thisPhase = 0;
while stillImaging %Image indefinitely until user quits
    
    % Determine bar orientation and direction (4 conditions)
    retSynch.thisCondition = mod(retSynch.thisCondition+1,4);
    if retSynch.thisCondition == 0
        retSynch.thisCondition = 4;
    end
    
    retSynch.barVerticalTrial = retSynch.thisCondition<3;
    retSynch.posDirectionTrial = mod(retSynch.thisCondition,2);
    
    initTrialBlock = 1;
    while mod(retSynch.nTrial,settings.nTrials) > 0 || initTrialBlock || ~retSynch.isTrialDone
            
        if KbCheck
            stillImaging = 0;
            break;
        end;
        
        initTrialBlock = 0;
        
        % Advance frame counter
        retSynch.nFrame = retSynch.nFrame + 1;
        if retSynch.isTrialDone
            % Increase trial counter and determine next trial type
            retSynch.nTrial = retSynch.nTrial + 1;
            retSynch.isTrialDone = false;
            retSynch.trialOnsets(retSynch.nTrial) = retSynch.nFrame;
            retSynch.trialConditions(retSynch.nTrial) = retSynch.thisCondition;

            % set initial bar position depending on trial type
            if retSynch.barVerticalTrial
                posLength = settings.screen.width;
            else
                posLength = settings.screen.height;
            end
            if retSynch.posDirectionTrial
                initPos = 0;
            else
                initPos = posLength;
            end        
            retSynch.barLocation(retSynch.nFrame) = initPos;
        else
            % Move bar position by trial type
            if retSynch.posDirectionTrial
                retSynch.barLocation(retSynch.nFrame) = ...
                    retSynch.barLocation(retSynch.nFrame-1) + settings.barPixFrame;
            else
                retSynch.barLocation(retSynch.nFrame) = ...
                    retSynch.barLocation(retSynch.nFrame - 1) - settings.barPixFrame;
            end
            
            % Check if bar has traversed screen
            if retSynch.barVerticalTrial
                terminationLength = settings.screen.width;
            else
                terminationLength = settings.screen.height;
            end
            if retSynch.barLocation(retSynch.nFrame) < 0 || ...
                    retSynch.barLocation(retSynch.nFrame) > terminationLength
                retSynch.isTrialDone = true;
            end
        end
        
        
        % Set camera trigger line low, without changing LEDs
        outputSingleScan(camControl,[retSynch.blueLED retSynch.redLED 0]),
        
        % Determine Lighting for Next Frame
        if settings.redLED && settings.blueLED
            retSynch.blueLED = mod(retSynch.nFrame,2)==1;
            retSynch.redLED = mod(retSynch.nFrame,2)==0;
        elseif settings.redLED
            retSynch.blueLED = 0;
            retSynch.redLED = 1;
        elseif settings.blueLED
            retSynch.blueLED = 1;
            retSynch.redLED = 0;
        end      
        
        if mod(retSynch.nFrame,settings.checkerBlinkRate)==1
            thisPhase = 2*rand*settings.h;
        end
        
        if retSynch.barVerticalTrial
            srcRect = [0 thisPhase ...
                settings.w thisPhase+settings.screen.height];
            dstRect = [retSynch.barLocation(retSynch.nFrame)-settings.w/2 0 ...
                retSynch.barLocation(retSynch.nFrame)+settings.w/2 settings.screen.height];
            Screen('DrawTexture', retScreen, checkerTex, srcRect, dstRect);
        else
            srcRect = [thisPhase 0 ...
                thisPhase+settings.screen.width settings.w];
            dstRect = [0 retSynch.barLocation(retSynch.nFrame)-settings.w/2 ...
                settings.screen.width retSynch.barLocation(retSynch.nFrame)+settings.w/2];
            Screen('DrawTexture', retScreen, checkerTransTex, srcRect, dstRect);    
        end
        
        vbl = Screen('Flip', retScreen, vbl + (settings.flipMod - 0.5) * ifi);
        
        % Send Trigger to Camera + LEDs
        outputSingleScan(camControl,[retSynch.blueLED retSynch.redLED 1]),
        
    end
end

%%
Priority(0);
Screen('CloseAll');
outputSingleScan(camControl,[0 0 0]),
delete(camControl),
save(thisFileName,'retSynch'),