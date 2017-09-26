function somatotopyVibrationMotorsAE
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

isDebug = false;
settings = struct;
settings.saveDir = 'E:\Data\Alan';
settings.expName = char(inputdlg('Experiment Name? '));

settings.nRepeats = 150; % How often the whole set of conditions is repeated.
settings.onTime_s = 0.5; % How long each motor is on
settings.offTime_s = 1.5; %off-time in between stimuli

settings.motorPositionName = {'rightHindpaw', 'leftHindpaw', 'leftBack'};
settings.motorSequence = getMinimumRepetitionSequence(...
    numel(settings.motorPositionName), ...
    numel(settings.motorPositionName)*settings.nRepeats);

settings.fps = 60; % acquisition rate

% Show estimated experiment duration:

expDur = settings.nRepeats * (settings.onTime_s + settings.offTime_s) * numel(settings.motorPositionName);
button = questdlg(sprintf('Experient will take about %1.1f minutes. Click YES to start.', ...
    expDur/60));
if ~strcmp(button, 'Yes')
    return
end

%% Take snapshot of taskScheduleFun so that it can be reconstructed later:
% (display with fprintf('%s', sn.meta.fileTaskSchedule);
fid = fopen([mfilename('fullpath'), '.m'], 'rt'); % open file in read-only text mode
settings.experimentCodeFile = fread(fid, inf, '*char'); %assign text to setting structure
fclose(fid);

%% Initialize DAQ and data logging
if ~isDebug
    camControl = daq.createSession('ni');
    addDigitalChannel(camControl,'Dev1','Port0/Line0:2','OutputOnly');
end

%% Initialize Teensy:
arduinoSerialObject = serial('COM3', 'BaudRate', 9600);
if isDebug
    global isMonitorArduino %#ok<UNRCH,TLEV,NUSED>
    isMonitorArduino = 0;
    arduinoSerialObject.BytesAvailableFcn = @cbArduinoDataAvailable;
end


fopen(arduinoSerialObject);

%% Initialize sync data storage:
frameStruct = struct;
frameStruct.frameId = 0;
frameStruct.flipTime_s = 0;
frameStruct.motorState = 0;
frame = eventSeries(frameStruct);


%% Display and Acquisition Loop
isUserAbort = 0;

% Make sure all buttons are released before continuing:
while KbCheck
end

if ~isDebug
    outputSingleScan(camControl,[1 1 0]) % LEDs on.
end

nCond = numel(settings.motorPositionName);
ticFrame = tic;
ticSession = tic;

iTrial = 0;

for iRep = 1:settings.nRepeats
    for iCond = 1:nCond
        ticCond = tic;
        iTrial = iTrial + 1;
        condHere = settings.motorSequence(iTrial);
        fprintf('Repeat %d/%d, condition %d: %s\n', ...
            iRep, settings.nRepeats, condHere, ...
            settings.motorPositionName{condHere});
        
        % Switch stimulus on:
        frame.next.motorState = condHere;
        fwrite(arduinoSerialObject, condHere, 'uint8')
        
        % Record stimulus response:
        while ~isUserAbort && toc(ticCond) < settings.onTime_s
            flipFrame;
        end
        
        % Switch stimulus off:
        frame.next.motorState = 0;
        fwrite(arduinoSerialObject, 0, 'uint8')
        
        % Record inter-stimulus interval:
        while ~isUserAbort && toc(ticCond) < (settings.offTime_s + settings.onTime_s)
            flipFrame;
        end
    end
end

function flipFrame
    frameLagCorrection = 0.0017; % Time it takes for the singleScan to be executed;
    
    frame.next.frameId = frame.current.frameId + 1;
    
    while toc(ticFrame) < (1/settings.fps)-frameLagCorrection
        % Wait until it is time to acquire the frame.
    end
    if ~isDebug
        outputSingleScan(camControl,[1 1 1]) % Trigger
        ticFrame = tic;
        frame.next.flipTime_s = toc(ticSession);
        outputSingleScan(camControl,[1 1 0]) % Reset
    end
    
    advance(frame);
    isUserAbort = KbCheck;
end

%% Clean up
% Save:

if ~isDebug
    if ~exist(settings.saveDir, 'dir')
        mkdir(settings.saveDir);
    end
    saveFileName = fullfile(settings.saveDir, ...
        [datestr(now, 'yyyymmdd_HHMMSS'), '_somatotopy_', settings.expName]);

    mfile = fileread(which(mfilename));
    save(saveFileName, 'settings', 'frame', 'mfile')
    fprintf('Somatotopy data saved at %s.\n', saveFileName)

    assignin('base', 'settings', settings);
    assignin('base', 'frame', frame);
    assignin('base', 'mfile', mfile);

    % Close DAQ:
    outputSingleScan(camControl, [0 0 0])
    delete(camControl)
end

% Close Arduino:
fclose(arduinoSerialObject);

end

