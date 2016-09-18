function avgMov = somatotopyVibrationMotorsAnalysis

%% Settings:
% base = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield';

base = 'E:\scratch\';
movFolder = fullfile(base, 'MM102_160718', 'somato');
datFile = fullfile(base, '20160718_184127_somatotopy_MM102_160718.mat');
chunkDur_s = 0.2;

%% Get movie metadata:
dat = load(datFile);

% Extract numbers from file name and sort accordingly:
p = fullfile(movFolder, '*.tiff'); %#ok<NASGU>
list = sort(...
    strsplit(...
    regexprep(evalc('dir(p)'), '\s{2,}', '\n'), ...
    '\n')); % Sort is necessary because evalc is not sorted alphabetically.
% list = list(3:end); % Remove . and ..
% lst = dir(fullfile(movFolder, '*.tiff'));

nFiles = numel(list);
lst = struct;
for i = 1:nFiles
    lst(i).name = list{i};
end

fileNameNumber = zeros(nFiles, 1);
for iFile = 1:nFiles
    str = regexp(lst(iFile).name, '(?<=_)()\d{4,5}(?=\.)', 'match', 'once');
    fileNameNumber(iFile) = str2double(str);
end
nFramesInSyncStruct = numel(dat.frame.past.frameId);
assert(nFramesInSyncStruct==nFiles, 'Number of image files does not match number of frames recorded in sync struct!')
[~, order] = sort(fileNameNumber);
lst = lst(order);
% lst = lst(1:nFramesInSyncStruct); % Fix for accidentally recording retino and somato in a row.

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

% For motion correction, use center frame as reference:
% (SNR is good enough to just use one frame.)
ref = double(imread(fullfile(movFolder, lst(round(nFramesInSyncStruct/2)).name)));
ref(ref<1000) = ref(ref<1000) + 2^16; % Fix overflow

% Pre-calculate reference FFT:
ref_fft = zeros(size(ref, 1), size(ref, 2), 3);
ref_fft(:,:,1) = fft2(ref);
ref_fft(:,:,2) = fftshift(ref_fft(:,:,1));
ref_fft(:,:,3) = conj(ref_fft(:,:,1));

ticProc = tic;
for iFrame = 1:nFramesInSyncStruct
    % Load frame:
    imgHere = double(imread(fullfile(movFolder, lst(iFrame).name)));
    imgHere(imgHere<1000) = imgHere(imgHere<1000) + 2^16; % Fix overflow
    
    % Correct motion:
    [imgHere, dat.mov.shifts.x(iFrame), dat.mov.shifts.y(iFrame)] = ...
        correct_translation_singleframe(imgHere, ref_fft, 1);
    
    iChunkHere = chunkOfFrame(iFrame);
    avgMov(:,:,iChunkHere) = ...
        avgMov(:,:,iChunkHere) + imgHere/nInChunk(iChunkHere);
    
    fprintf('Processing frame % 6.0f/% 1.0f (%1.1f minutes left)\n', ...
        iFrame, nFramesInSyncStruct, (toc(ticProc)/(60*iFrame)) * (nFramesInSyncStruct-iFrame));
end

dat.mov.ref = ref;

%% Save:
[p, f, ~] = fileparts(datFile);
f = sprintf('%s_avgMov%s', f, datestr(now, 'yymmdd'));
tiffWrite(avgMov, f, p);
save(fullfile(p, f), '-struct', 'dat');
