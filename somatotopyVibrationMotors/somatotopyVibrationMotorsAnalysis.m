function avgMov = somatotopyVibrationMotorsAnalysis

%% Settings:
movFolder = 'D:\Data\Matthias\MM101_retino';
datFile = 'D:\Data\Matthias\2016-06-07_19-47-44_somatotopy_MM101_somato.mat';
chunkDur_s = 0.5;

%% Get movie metadata:
dat = load(datFile);

% Extract numbers from file name and sort accordingly:
lst = dir(fullfile(movFolder, '*.tiff'));
nFiles = numel(lst);
fileNameNumber = zeros(nFiles, 1);
for iFile = 1:nFiles
    str = regexp(lst(iFile).name, '(?<=_)()\d{4,5}(?=\.)', 'match', 'once');
    fileNameNumber(iFile) = str2double(str);
end
nFramesInSyncStruct = numel(dat.frame.past.frameId);
[~, order] = sort(fileNameNumber);
lst = lst(order);
% lst = lst(1:nFramesInSyncStruct);
lst = lst((end-nFramesInSyncStruct+1):end); % Fix for accidentally recording retino and somato in a row.

img = imread(fullfile(movFolder, lst(1).name));
dat.mov.height = size(img, 1);
dat.mov.width = size(img, 2);
dat.mov.nFrames = nFramesInSyncStruct;
dat.mov.nPixPerFrame = dat.mov.height * dat.mov.width;

%% Get chunk indices:
% Go through condition boundaries and chop up the intervening time into
% chunks:
nStimChunks = round(dat.settings.onTime_s/chunkDur_s);
nBlankChunks = round(dat.settings.offTime_s/chunkDur_s);
iFirstInCond = [1, find(diff(dat.frame.past.motorState))+1];
iFirstInCond(end+1) = numel(dat.frame.past.frameId)+1; % One past the last frame.

chunkOfFrame = zeros(size(dat.frame.past.frameId));
for i = 1:(numel(iFirstInCond)-1)
    s = iFirstInCond(i);
    e = iFirstInCond(i+1) - 1;
    if dat.frame.past.motorState(s) > 0
        chunkInc = linspace(eps, nStimChunks, e-s+1);
    else
        chunkInc = linspace(eps, nBlankChunks, e-s+1);
    end
    chunkInc = ceil(chunkInc);
    chunkOfFrame(s:e) = max(chunkOfFrame) + chunkInc;
end

%% Create average movie:
% Go through frames and accumulate chunk averages:
nChunks = max(chunkOfFrame);
avgMov = zeros(dat.mov.height, dat.mov.width, nChunks);
nInChunk = accumarray(chunkOfFrame', ones(size(chunkOfFrame)));
for iFrame = 1:nFramesInSyncStruct
    imgHere = double(imread(fullfile(movFolder, lst(iFrame).name)));
    imgHere(imgHere<1000) = imgHere(imgHere<1000) + 2^16; % Fix overflow
    iChunkHere = chunkOfFrame(iFrame);
    avgMov(:,:,iChunkHere) = ...
        avgMov(:,:,iChunkHere) + imgHere/nInChunk(iChunkHere);    
    fprintf('Processing frame % 6.0f/% 6.0f\n', ...
        iFrame, nFramesInSyncStruct);
end

%% Save:
[p, f, ~] = fileparts(datFile);
tiffWrite(avgMov, [f, '_avgMov'], p);
