function somatotopyVibrationMotors
%% User settings:
isDebug = false;
settings = struct;
settings.saveDir = 'D:\Data\Matthias';
settings.expName = char(inputdlg('Experiment Name? '));
% 20 Reps was OK but go higher if there's time
settings.nRepeats = 40; % How often the whole set of conditions is repreated.
settings.onTime_s = 1; % How long each motor is on
settings.offTime_s = 4; % Off-time in betwee stimuli
settings.motorOrder = 1:5;
settings.motorPositionName = {'snout', ...
    'upper flank', 'lower flank', 'hindpaw', 'neck'};
settings.fps = 60; % jmTarget display/acquisition rate. Max is 120 Hz (monitor refresh)

% Show estimated experiment duration:
expDur = settings.nRepeats * (settings.onTime_s + settings.offTime_s) * numel(settings.motorOrder);
button = questdlg(sprintf('Experiment will take about %1.1f minutes. Click YES to start.', ...
    expDur/60));
if ~strcmp(button, 'Yes')
    return
end

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

nCond = numel(settings.motorOrder);
ticFrame = tic;
ticSession = tic;

for iRep = 1:settings.nRepeats
    for iCond = settings.motorOrder
        ticCond = tic;
        fprintf('Repeat %d/%d, conditon %d/%d.\n', ...
            iRep, settings.nRepeats, iCond, nCond);
        
        % Switch motor on:
        frame.next.motorState = iCond;
        fwrite(arduinoSerialObject, iCond, 'uint8')
        
        % Record stimulus response:
        while ~isUserAbort && toc(ticCond) < settings.onTime_s
            flipFrame;
        end
        
        % Switch motor off:
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
if ~exist(settings.saveDir, 'dir')
    mkdir(settings.saveDir);
end
saveFileName = fullfile(settings.saveDir, ...
    [datestr(now, 'yyyy-mm-dd_HH-MM-SS'), '_somatotopy_', settings.expName]);

mfile = fileread(which(mfilename));
save(saveFileName, 'settings', 'frame', 'mfile')
fprintf('Somatotopy data saved at %s.\n', saveFileName)

assignin('base', 'settings', settings);
assignin('base', 'frame', frame);
assignin('base', 'mfile', mfile);

if ~isDebug
    % Close DAQ:
    outputSingleScan(camControl, [0 0 0])
    delete(camControl)
end

% Close Arduino:
fclose(arduinoSerialObject);

end