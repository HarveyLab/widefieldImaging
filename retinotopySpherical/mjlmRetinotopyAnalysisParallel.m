function results = mjlmRetinotopyAnalysisParallel

%% Settings:
mouseName = 'MM303';
dateStr = '161001';

base = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield';
movFolder = fullfile(base, mouseName, [mouseName '_' dateStr '_retino']);

ls = dir(fullfile(movFolder, ['*_retinotopy_' mouseName '.mat']));
if numel(ls) ~=1
    error('Found either none or several dat files. Check!')
end
datFile = fullfile(movFolder, ls.name);

%% Get movie metadata:
dat = load(datFile);

% Extract numbers from file name and sort accordingly:
p = fullfile(movFolder, '*.tiff');
list = sort(strsplit(regexprep(evalc('dir(p)'), '\s{2,}', '\n'), '\n')); % Sort is necessary because evalc is not sorted alphabetically.
list = list(3:end); % Remove current and parent dir, which are not removed when using evalc.

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
[~, order] = sort(fileNameNumber);
lst = lst(order);

img = imread(fullfile(movFolder, lst(1).name));
dat.mov.height = size(img, 1);
dat.mov.width = size(img, 2);
dat.mov.nFramesStim = numel(dat.frame.past.frameId);
dat.mov.nFramesCam = numel(lst);
dat.mov.nPixPerFrame = dat.mov.height * dat.mov.width;
temporalDownSampling = 1;

% There is sometimes an additional frame in the end, which is black, so
% it's OK to have one extra frame.
assert(sum(dat.frame.past.isCamTriggerFrame)-dat.mov.nFramesCam<0, ...
    'Recorded number of images does not match sync data!')

%% Get condition data:
uniqueDir = unique(dat.frame.past.barDirection_deg);
nCond = numel(uniqueDir);

% For non-fft analysis:
maxEccentricity = ceil(max(abs(dat.frame.past.barPosition_deg))/10)*10;
edges = -maxEccentricity:2:maxEccentricity;
nBins = numel(edges)-1;
barPosBinned = discretize(dat.frame.past.barPosition_deg, edges);

results = struct;
for iCond = 1:nCond
    results(iCond).dir = uniqueDir(iCond);
    isFrameThisCond = dat.frame.past.barDirection_deg==results(iCond).dir;
    results(iCond).nFrames = sum(isFrameThisCond);
    results(iCond).nReps = sum(abs(diff(dat.frame.past.barPosition_deg) .* isFrameThisCond(max(temporalDownSampling, 2):end))>10);
    if iCond==1
        results(iCond).nReps = results(iCond).nReps+1;
    end
    results(iCond).period = results(iCond).nFrames / results(iCond).nReps;
    
    barPosBinnedHere = barPosBinned(dat.frame.past.barDirection_deg==results(iCond).dir);
    camTriggersHere = dat.frame.past.isCamTriggerFrame(dat.frame.past.barDirection_deg==results(iCond).dir);
    results(iCond).uniqueBins = unique(barPosBinnedHere);
    results(iCond).nInBin = accumarray(barPosBinnedHere', camTriggersHere');
    results(iCond).nActuallySummed = results(iCond).nInBin*0;
    results(iCond).tuning = zeros(dat.mov.height, dat.mov.width, nBins);
end

%% Retinotopy extraction algorithm:

% Go through data frame by frame. Bin data by bar positon. Keep a running
% average for baseline subtraction.

% For motion correction, use center frame as reference:
% (SNR is good enough to just use one frame.)
ref = double(imread(fullfile(movFolder, lst(round(dat.mov.nFramesCam/2)).name)));
ref(ref<1000) = ref(ref<1000) + 2^16; % Fix overflow

% Pre-calculate reference FFT:
% Crop to image center to make motion correction faster. Probably won't
% reduce precision much.
refCrop = ref(151:450, 151:450);
ref_fft = zeros(size(refCrop, 1), size(refCrop, 2), 3);
ref_fft(:,:,1) = fft2(refCrop);
ref_fft(:,:,2) = fftshift(ref_fft(:,:,1));
ref_fft(:,:,3) = conj(ref_fft(:,:,1));

ticProc = tic;
nFilesProcessed = 0;
barDirection_deg = dat.frame.past.barDirection_deg;
isCamTriggerFrame = dat.frame.past.isCamTriggerFrame;
nFramesCam = dat.mov.nFramesCam;
startTime = now;

parfor iCond = 1:nCond
    
    % Get index of all STIMULUS frames for this condition:
    thisCondFrameInd = find(barDirection_deg==results(iCond).dir);
    
    for iFrame = thisCondFrameInd
        % Skip the stimulus frames on which no image was triggered:
        if ~isCamTriggerFrame(iFrame)
            continue
        end
        
%         % Limit number of frames analyzed to see if the beginnin of the
%         % session looks better:
%         if iFrame > 30000
%             continue
%         end
        
        iFile = sum(isCamTriggerFrame(1:iFrame));
        
        % Load frame:
        imgHere = double(imread(fullfile(movFolder, lst(iFile).name)));
        imgHere(imgHere<1000) = imgHere(imgHere<1000) + 2^16; % Fix occasional overflow
        
        % Correct motion:
        [imgHere, ~, ~] = ...
            correct_translation_singleframe(imgHere(151:450, 151:450), ...
            ref_fft, 1, imgHere);
        
        % normalize
        imgHere = imgHere ./ mean(col(imgHere(151:450, 151:450)));
        
        % Add current frame to the appropriate bin:
        iBin = barPosBinned(iFrame);
        results(iCond).tuning(:,:,iBin) = results(iCond).tuning(:,:,iBin) ...
            + imgHere ./ results(iCond).nInBin(iBin);
        results(iCond).nActuallySummed(iBin) = results(iCond).nActuallySummed(iBin) + 1;
        
        
        fractionDone = find(thisCondFrameInd==iFrame)/numel(thisCondFrameInd);
        secondsElapsed = (now-startTime) * 24 * 3600;
        totalDuration = secondsElapsed/fractionDone;
        secondsRemaining = totalDuration - secondsElapsed;
        fprintf('Processing file % 6.0f/% 1.0f (%1.1f min remaining)\n', ...
            iFile, nFramesCam, secondsRemaining/60);
    end
end

dat.mov.ref = ref;

%% Save:
[p, f, ~] = fileparts(datFile);
f = sprintf('%s_results%s', f, datestr(now, 'yymmdd'));
dat.results = results;
save(fullfile(p, f), '-struct', 'dat');