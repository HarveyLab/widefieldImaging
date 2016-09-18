function results = mjlmRetinotopyAnalysisFramewise

%% Settings:
% base = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield';
base = 'D:\Data\Matthias';
movFolder = fullfile(base, 'MM102_160907_retino');
datFile = fullfile(base, '20160907_203252_retinotopy_MM102.mat');

%% Get movie metadata:
dat = load(datFile);

% Extract numbers from file name and sort accordingly:
p = fullfile(movFolder, '*.tiff');
list = sort(strsplit(regexprep(evalc('dir(p)'), '\s{2,}', '\n'), '\n')); % Sort is necessary because evalc is not sorted alphabetically.

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

assert(abs(sum(dat.frame.past.isCamTriggerFrame)-dat.mov.nFramesCam)<=1, ...
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
ref_fft = zeros(size(ref, 1), size(ref, 2), 3);
ref_fft(:,:,1) = fft2(ref);
ref_fft(:,:,2) = fftshift(ref_fft(:,:,1));
ref_fft(:,:,3) = conj(ref_fft(:,:,1));

ticProc = tic;
nFilesProcessed = 0;
for iCond = 1:nCond
    
    % Get index of all STIMULUS frames for this condition:
    thisCondFrameInd = find(dat.frame.past.barDirection_deg==results(iCond).dir);
    
    for iFrame = thisCondFrameInd
        % Skip the stimulus frames on which no image was triggered:
        if ~dat.frame.past.isCamTriggerFrame(iFrame)
            continue
        else
            iFile = sum(dat.frame.past.isCamTriggerFrame(1:iFrame));
        end
        
        % Load frame:
        imgHere = double(imread(fullfile(movFolder, lst(iFile).name)));
        imgHere(imgHere<1000) = imgHere(imgHere<1000) + 2^16; % Fix occasional overflow
        
        % Correct motion:
        [imgHere, dat.mov.shifts.x(iFile), dat.mov.shifts.y(iFile)] = ...
            correct_translation_singleframe(imgHere, ref_fft, 1);
        
        % Add current frame to the appropriate bin:
        iBin = barPosBinned(iFrame);
        results(iCond).tuning(:,:,iBin) = results(iCond).tuning(:,:,iBin) ...
            + imgHere ./ results(iCond).nInBin(iBin);
        
        nFilesProcessed = nFilesProcessed+1;
        fprintf('Processing file % 6.0f/% 1.0f (%1.1f minutes left)\n', ...
            nFilesProcessed, dat.mov.nFramesCam, (toc(ticProc)/(60*nFilesProcessed)) * ...
            (dat.mov.nFramesCam-nFilesProcessed));
    end
end

dat.mov.ref = ref;

%% Save:
[p, f, ~] = fileparts(datFile);
f = sprintf('%s_results%s', f, datestr(now, 'yymmdd'));
dat.results = results;
save(fullfile(p, f), '-struct', 'dat');