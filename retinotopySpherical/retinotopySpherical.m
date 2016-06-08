%% User settings:
isDebug = false;
settings = struct;
settings.saveDir = 'D:\Data\Matthias';
settings.expName = char(inputdlg('Experiment Name? '));
% 10 reps was not enough with transgenic. Try 20.
settings.nRepeats = 10; % How often each direction is repeated, i.e. there will be 4 times as many sweeps.
settings.barWidth_deg = 10; % Marshel uses 20
settings.barSpeed_dps = 9; % Marshel uses 8.5-9.5 dps
settings.checkerBlink_hz = 6; % Marshel uses 6 Hz
settings.minDistEyeToScreen_mm = 130;
settings.screenOri_xyPix = [-34, 45];
settings.pixelReductionFactor = 5; % How much the texture is downsampled...affects frame rate.
settings.fps = 60; % Target display/acquisition rate. Max is 120 Hz (monitor refresh)

% Empirical duration for Marshel settings:
expDur = settings.nRepeats * 2 * (11.6182 + 14.6516);
button = questdlg(sprintf('Experiment will take about %1.1f minutes. Click YES to start.', ...
    expDur/60));
if ~strcmp(button, 'Yes')
    return
end

%% Run this to find the screen origin:
if false
    screenId = 2; %#ok<UNRCH>
    res = Screen('Resolution', screenId);
    while KbCheck 
    end

    while ~KbCheck
        [x, y] = GetMouse(screenId);
        fprintf('Mouse pos x: %1.0f, y:%1.0f\n', x-res.width/2, y-res.height/2)
        pause(0.3)
    end
end

%% Initialize DAQ and data logging
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
    blackOutWin = Screen('OpenWindow', 1, 0);
end

Screen('Preference', 'VisualDebugLevel', 1); % Suppress white intro screen.
screen.win = PsychImaging('OpenWindow',  screen.id, 0, [], [], [], [], screen.isAntiAliasing);
screen.fullRect = Screen('Rect', screen.win);

%% Display and Acquisition Loop

%Draw first streen to ensure functions are all loaded:
tex = prepareSphericalBarTex(screen, settings, frame.next.barDirection_deg);
texMat = makeSphericalBar(tex, settings, 0);
texPtr = Screen('MakeTexture', screen.win, texMat);
Screen('DrawTexture', screen.win, texPtr, [], screen.fullRect);
Screen('Flip', screen.win, 0);
Screen('Close', texPtr)
        
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
    disp(repeatDuration_s)
    if frame.next.frameId == 0
        timeFirstFrame_s = Screen('Flip', screen.win, 0);
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
        frame.next.flipTime_s = Screen('Flip', screen.win, ...
            frame.current.flipTime_s+(0.75/settings.fps));
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
    [datestr(now, 'yyyy-mm-dd_HH-MM-SS'), '_somatotopy_', settings.expName]);

mfile = fileread(which(mfilename));
save(saveFileName, 'settings', 'screen', 'frame', 'mfile')
fprintf('Retinotopy data saved at %s.\n', saveFileName)

Priority(oldPriority);
Screen('CloseAll');

if ~isDebug
    % Close DAQ:
    outputSingleScan(camControl, [0 0 0])
    delete(camControl)
end


warning('To do: save mfile')
