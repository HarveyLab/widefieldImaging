%% Set up camera:

% CREATE CAMERA OBJECT: The adaptorname and deviceId (first and second
% argument) might be different, use IMAQHWINFO to find which ones are
% available. The availabel formats (third argument) can be found using
% IMAQTOOL. Tip: I find that calling VIDEOINPUT to connect to a Basler
% camera often causes Matlab to crash. The crash might be prevented by
% calling IMAQRESET first, then waiting ~30 s, then calling VIDEOINPUT.
cam = videoinput('winvideo', 1, 'Y800_640x480');

% CAMERA SETTINGS: If TRIGGERCONFIG is set to Manual, the user has to
% trigger each frame by calling TRIGGER. To have the camera acquire frames
% as fast as possible, set TRIGGERCONFIG to Immediate. Frames will then be
% stored by the camera frame buffer until retrieved using GETDATA (see
% below).
set(cam, 'ReturnedColorSpace', 'grayscale');
set(cam, 'FramesPerTrigger', 1);
set(cam, 'TriggerRepeat', inf);
triggerconfig(cam, 'Manual');

src = getselectedsource(cam);
set(src, 'Exposure', -7); % Max for 120 Hz is -7 (for Basler acA640-120um).
set(src, 'Gain', 1023); % Max is 1023.

% ARM CAMERA (starts listening for triggers, or starts acquiring frames if
% trigger is set to Immediate):
start(cam);

%% EXAMPLE: ACQUIRE A SINGLE FRAME
% Cam must be started using start(cam) before this point.
trigger(cam);
img = getdata(cam, 1, 'double');
figure
imagesc(img);

%% EXAMPLE: REAL-TIME PROCESSING
% Cam must be started using start(cam) before this point.

% Set up across-session data sharing:
% sharedMemObj = shmobject('mySharedMem1', 0);

% Trigger first frame:
trigger(cam);

% Real-time processing loop:
while true % Break out of the loop with Ctrl+C
    
    % GETDATA retrieves the previously triggered frame from the camera. If
    % the frame is not yet available (e.g. because the exposure time has
    % not yet passed), then GETDATA will halt execution until the the frame
    % is available. Tip: Get data in native uint8. It's faster to do
    % double() separately.
    img = getdata(cam, 1, 'uint8');
    
    % Trigger the next frame BEFORE the main image processing code.
    % Thereby, the next image will be acquired at the same time as the
    % previous image is processed. If TRIGGER were called immediately before
    % GETDATA, GETDATA would halt execution for the entire exposure time.
    % If the frame is already available in the camera buffer, GETDATA will
    % only take a few hundred microseconds. Of course, if the processing
    % code below takes a long time, then the latest frame might be outdated
    % by the time it is retreived, so a different order might be necessary
    % then.
    trigger(cam);
   
    % Many image processing functions work best on the double data type, so
    % convert image data. This is faster if done separately rather than in
    % GETDATA.
    img = double(img);
    
    % IMAGE PROCESSING CODE:
    % After GETDATA and TRIGGER, extract whatever information you want:
    imgMean = mean(img(:));
    fprintf('Mean intensity: % 6.3f\n', imgMean);
    
    % MAKE DATA AVAILABLE TO OTHER MATLAB SESSIONS:
%     delete(sharedMemObj); % Need to delete old object first.
%     sharedMemObj = shmobject('mySharedMem1', imgMean);
end

%% CLEAN UP:
stop(cam)
delete(cam)
clear cam
    