function somatotopyVibrationMotors

% Next time:
% error('Make vibration stronger')
% error('Try longer trials, maybe 1s on, 1s off')
% error('Do "neck" further down on back...avoid vibrating head plate')
% error('Don''t do audio, A1 is probably not visible after all')
% error('Ensure that foot is really solidly in contact with stimulator (maybe bind it with string or so)')

% error('Ensure that no motor, esp. neck, makes a loud sound when vibrating. maybe use plastic rod to transmit vibration, rather than using motor directly on fur')
% error('use motor vibrating against something close to right ear to map aud cx')
% error('don''t use flank -- no clear signal')
% error('raise the foot so that it dangles freely and the motor only touches the foot, not the whole leg/flank')
% error('convert these errors to warnings or so, so that I see them every time')
% error('Maybe remove offTime and do many more faster trials. There is a clear singal after 0.4 s and the singal is almost gone 1 s after the stimulus offset. maybe do 0.4 on/0.4 off and many more trials

%% User settings:
isDebug = false;
settings = struct;
settings.saveDir = 'D:\Data\Matthias';
settings.expName = char(inputdlg('Experiment Name? '));
% 20 Reps was OK but go higher if there's time
settings.nRepeats = 150; % How often the whole set of conditions is repreated.
settings.onTime_s = 1; % How long each motor is on
settings.offTime_s = 1; % Off-time in betwee stimuli

% Audio must come at s the last "motor" and must be called "audio"
settings.motorPositionName = {'snout', 'neck', 'hindpaw'};
settings.motorSequence = getMinimumRepetitionSequence(...
    numel(settings.motorPositionName), ...
    numel(settings.motorPositionName)*settings.nRepeats);

settings.fps = 60; % jmTarget display/acquisition rate. Max is 120 Hz (monitor refresh)

% Show estimated experiment duration:
expDur = settings.nRepeats * (settings.onTime_s + settings.offTime_s) * numel(settings.motorPositionName);
button = questdlg(sprintf('Experiment will take about %1.1f minutes. Click YES to start.', ...
    expDur/60));
if ~strcmp(button, 'Yes')
    return
end

%% Take snapshot of taskScheduleFun so that it can be reconstructed later:
% (display with fprintf('%s', sn.meta.fileTaskSchedule);
fid = fopen([mfilename('fullpath'), '.m'], 'rt');
settings.experimentCodeFile = fread(fid, inf, '*char');
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

%% Initialize sound:
soundFile = load('ripple_sound.mat');
soundDur = settings.onTime_s;
audioObject = audioplayer(soundFile.ripple(1:round(soundFile.Fs*soundDur)), ...
    soundFile.Fs, 16);

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
outputSingleScan(camControl,[1 1 0]) % LEDs on.

nCond = numel(settings.motorPositionName);
ticFrame = tic;
ticSession = tic;

iTrial = 0;

for iRep = 1:settings.nRepeats
    for iCond = 1:nCond
        ticCond = tic;
        iTrial = iTrial+1;
        condHere = settings.motorSequence(iTrial);
        fprintf('Repeat %d/%d, conditon %d: %s\n', ...
            iRep, settings.nRepeats, condHere, ...
            settings.motorPositionName{condHere});
        
        % Switch stimulus on:
        frame.next.motorState = condHere;
        isAudio = condHere==nCond && strcmp(settings.motorPositionName{condHere}, 'audio');
        
        if isAudio
            if audioObject.isplaying
                stop(audioObject)
            end
            play(audioObject)
        else
            fwrite(arduinoSerialObject, condHere, 'uint8')
        end
        
        % Record stimulus response:
        while ~isUserAbort && toc(ticCond) < settings.onTime_s
            flipFrame;
        end
        
        % Switch stimulus off:
        frame.next.motorState = 0;
        if ~isAudio
            fwrite(arduinoSerialObject, 0, 'uint8')
        end
        
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
    [datestr(now, 'yyyymmdd_HHMMSS'), '_somatotopy_', settings.expName]);

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