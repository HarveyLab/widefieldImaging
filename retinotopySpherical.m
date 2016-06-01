%% User settings:
isDebug = true;
settings = struct;
settings.saveDir = 'F:\';
settings.expName = char(inputdlg('Experiment Name? '));
settings.nRepeats = 2; % How often each direction is repeated, i.e. there will be 4 times as many sweeps.
settings.barWidth_deg = 5;
settings.barSpeed_dps = 30;
settings.checkerBlink_hz = 6;
settings.minDistEyeToScreen_mm = 100;
settings.screenOri_xyPix = [-622, 329];
settings.pixelReductionFactor = 5; % How much the texture is downsampled...affects frame rate.

%% Run this to find the screen origin:
if false
    screenId = 2; %#ok<UNRCH>
    res = Screen('Resolution', settings.screen.id);
    while KbCheck 
    end

    while ~KbCheck
        [x, y] = GetMouse(screenId);
        fprintf('Mouse pos x: %1.0f, y:%1.0f\n', x-res.width/2, y-res.height/2)
        pause(0.3)
    end
end

%% Initialize DAQ and Data Logging
if ~isDebug
    camControl = daq.createSession('ni');
    addDigitalChannel(camControl,'Dev1','Port0/Line0:2','OutputOnly');
end

%% Initialize screen:
if numel(Screen('Screens')) > 1
    screen.id = 2;
else
    screen.id = 0;
end

res = Screen('Resolution', screen.id);

screen.width = res.width;
screen.height = res.height;
screen.hz = res.hz;
screen.diagInch = 27;
screen.pixPerMm = hypot(screen.width, screen.height)/(25.4 * screen.diagInch);
screen.isAntiAliasing = 0;

%% Initialize sync data storage:
retSynch = struct;
retSynch.nFrame = uint32(0);
retSynch.nTrial = uint16(0);
retSynch.trialOnsets = uint32(0);
retSynch.trialConditions = uint16(0);
retSynch.barLocation = pi*1e6;
retSynch.isTrialDone = true;
retSynch.barVerticalTrial = true;
retSynch.posDirectionTrial = true;
% retSynch.redLED = settings.redLED;
% retSynch.blueLED = settings.blueLED;

frameStruct = struct;
frameStruct.frameId = 0;
frameStruct.flipTime_s = 0;
frameStruct.barDirection_deg = 0;
frameStruct.barPosition_deg = 0;
frame = eventSeries(frameStruct);

%% Screen Setup
if isDebug
    Screen('Preference', 'SkipSyncTests', 2);
    Screen('Preference', 'WindowShieldingLevel', 1000 + 400); % 1000 means that mouse gets through to Windows.
    oldPriority = Priority;
else
    oldPriority = Priority(1);
end

screen.win = PsychImaging('OpenWindow',  screen.id, [], [], [], [], [], screen.isAntiAliasing);
screen.fullRect = Screen('Rect', screen.win);

%% Display and Acquisition Loop
timeFirstFrame_s = Screen('Flip', screen.win, 0);
isExit = 0;

while KbCheck
end

for iCond = 1:4
    switch iCond
        case 1 % Azi forward
            frame.next.barDirection_deg = 0;
        case 2 % Alt forward
            frame.next.barDirection_deg = 90;
        case 3 % Azi backward
            frame.next.barDirection_deg = 180;
        case 4 % Alt backward
            frame.next.barDirection_deg = 270;
    end
    
    % Prepare texture and timers:
    tex = prepareSphericalBarTex(screen, settings, frame.next.barDirection_deg);
    repeatDuration_s = range(tex.altLimits_deg)/settings.barSpeed_dps;
    
    if frame.next.frameId == 0
        t0 = timeFirstFrame_s;
    else
        t0 = frame.current.flipTime_s;
    end
    timeInCondition_s = 0;
    
    while timeInCondition_s < (repeatDuration_s * settings.nRepeats)
        
        % Draw frame:
        [texMat, frame.next.barPosition_deg] = ...
            makeSphericalBar(tex, settings, timeInCondition_s);
        texPtr = Screen('MakeTexture', screen.win, texMat);
        Screen('DrawTexture', screen.win, texPtr, [], screen.fullRect);
        
        % Advance frame:
        frame.next.frameId = frame.current.frameId + 1;
        frame.next.flipTime_s = Screen('Flip', screen.win);
        timeInCondition_s = frame.next.flipTime_s - t0;
        advance(frame);
        
        % Trigger camera acquisition:
        if ~isDebug
            outputSingleScan(camControl,[1 1 1]) % Trigger
            outputSingleScan(camControl,[1 1 0]) % Reset
        end
        
        % Clean up:
        Screen('Close', texPtr)
        
        if KbCheck
            isExit = true;
            break
        end
    end
    
    if isExit
        break
    end
end

%% Clean up
% Save:
if ~exist(settings.saveDir, 'dir')
    mkdir(settings.saveDir);
end
saveFileName = fullfile(settings.saveDir, ...
    [datestr(now, 'yyyy-mm-dd_HH-MM-SS'), '_', settings.expName]);
save(saveFileName, 'settings', 'screen', 'frame')
fprintf('Retinotopy data saved at %s.\n', saveFileName)

Priority(oldPriority);
Screen('CloseAll');

if ~isDebug
    % Close DAQ:
    outputSingleScan(camControl, [0 0 0])
    delete(camControl)
end


