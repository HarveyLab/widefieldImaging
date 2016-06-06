%% User settings:
isDebug = true;
settings = struct;
settings.saveDir = 'D:\Data\Matthias';
settings.expName = char(inputdlg('Experiment Name? '));
settings.nRepeats = 2; % How often the whole set of conditions is repreated.
settings.onTime_s = 1; % How long each motor is on
settings.offTime_s = 2; % Off-time in betwee stimuli
settings.motorOrder = 1:6;
settings.motorPositionName = {'right hindpaw', '', '', '', '', ''};
settings.fps = 60; % Target display/acquisition rate. Max is 120 Hz (monitor refresh)

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
arduinoSerialObject = serial('COM6', 'BaudRate', 9600);
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

for iRep = 1:settings.nRepeats
    for iCond = settings.motorOrder
        ticCond = tic;
        
        % Switch motor on:
        fwrite(arduinoSerialObject, iCond, 'uint8')
        fprintf('Repeat %d/%d, conditon %d/%d.\n', ...
            iRep, settings.nRepeats, iCond, nCond);
        
        % Record stimulus response:
        while ~isUserAbort && toc(ticCond) < settings.onTime_s
            while toc(ticFrame) < (1/settings.fps)
                % Wait until it is time to acquire the frame.
            end
            if ~isDebug
                outputSingleScan(camControl,[1 1 1]) % Trigger
                outputSingleScan(camControl,[1 1 0]) % Reset
            end
            isUserAbort = KbCheck;
        end
        
        % Switch motor off:
        fwrite(arduinoSerialObject, 0, 'uint8')
        
        % Record inter-stimulus interval:
        while ~isUserAbort && toc(ticCond) < settings.offTime_s
            while toc(ticFrame) < (1/settings.fps)
                % Wait until it is time to acquire the frame.
            end
            if ~isDebug
                outputSingleScan(camControl,[1 1 1]) % Trigger
                outputSingleScan(camControl,[1 1 0]) % Reset
            end
            isUserAbort = KbCheck;
        end
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
save(saveFileName, 'settings', 'frame', 'mfile')
fprintf('Somatotopy data saved at %s.\n', saveFileName)

if ~isDebug
    % Close DAQ:
    outputSingleScan(camControl, [0 0 0])
    delete(camControl)
end

% Close Arduino:
fclose(arduinoSerialObject);
