function results = mjlmRetinotopyAnalysisOnline

%% Settings:
mouseName = 'MM105';
dateStr = '161017';

widefieldBase = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield\';
datFolder = fullfile(widefieldBase, mouseName, [mouseName '_' dateStr '_retino']);
% movFolder = fullfile(datFolder, 'mov');
movFolder = '\\intrinsicScope\D\Data\Matthias\MM106';

ls = dir(fullfile(datFolder, ['*_retinotopy_' mouseName '.mat']));
if numel(ls) ~=1
    error('Found either none or several dat files. Check!')
end
datFile = fullfile(datFolder, ls.name);

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
movNamePrefix = regexp(lst(1).name, '.+_', 'match');
movNamePrefix = movNamePrefix{:};

dat.mov.height = size(img, 1);
dat.mov.width = size(img, 2);
% dat.mov.nFramesStim = numel(dat.frame.past.frameId);
% dat.mov.nFramesCam = numel(lst);
% dat.mov.nPixPerFrame = dat.mov.height * dat.mov.width;
temporalDownSampling = 1;
% 
% % There is sometimes an additional frame in the end, which is black, so
% % it's OK to have one extra frame.
% assert(abs(sum(dat.frame.past.isCamTriggerFrame)-dat.mov.nFramesCam)<=1, ...
%     'Recorded number of images does not match sync data!')

%% Get condition data:
uniqueDir = unique(dat.frame.past.barDirection_deg);
nCond = numel(uniqueDir);

% For non-fft analysis:
% maxEccentricity = ceil(max(abs(dat.frame.past.barPosition_deg))/10)*10;
maxEccentricity = 70;
edges = -maxEccentricity:2:maxEccentricity;
nBins = numel(edges)-1;
edges(1) = -inf;
edges(end)=inf;

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
    results(iCond).uniqueBins = nBins;
    results(iCond).nInBin = zeros(nBins, 1); % We don't know this during online analysis and add it up later.
    results(iCond).tuning = zeros(dat.mov.height, dat.mov.width, nBins);
    results(iCond).xShift = [];
    results(iCond).yShift = [];
end

%% Retinotopy extraction algorithm:
% Go through data frame by frame. Bin data by bar positon. Keep a running
% average for baseline subtraction.

% For motion correction, use first frame as reference, so that we can do
% analysis online: (SNR is good enough to just use one frame.)
ref = double(imread(fullfile(movFolder, lst(1).name)));

% Filter images for motion correction: We use a cross-shaped mask to filter
% the fourier spectrum. This has two effects: The center of the cross
% suppresses low frequencies (e.g. fluctuations due to whole image
% brightness or cortical responses). The arms of the cross suppress excess
% power at the cardinal directions from the pixel grid.
fftFiltWinH = gausswin(dat.mov.height, round(dat.mov.height/10));
fftFiltWinW = gausswin(dat.mov.width, round(dat.mov.width/10))';
fftFiltWin = max((fftFiltWinH./max(fftFiltWinH)), (fftFiltWinW./max(fftFiltWinW))); % Cross
ref = ifft2(ifftshift(fftshift(fft2(ref)) .* (1-fftFiltWin)));

% Pre-calculate reference FFT:
% Crop to image to avoid the part that contains the visual response,
% because that can throw off the motion correction.
refCrop = ref;
ref_fft = zeros(size(refCrop, 1), size(refCrop, 2), 3);
ref_fft(:,:,1) = fft2(refCrop);
ref_fft(:,:,2) = fftshift(ref_fft(:,:,1));
ref_fft(:,:,3) = conj(ref_fft(:,:,1));

parfor iCond = 1:nCond
    
    % Load metadat file
    dat = load(datFile);
    nStimFramesDisplayed = max(dat.frame.past.frameId);
    iFrame = 0;
    isSessionOver = 0;
    nFramesProcessedThisCond = 0;
    ticStartThisCond = tic;
    isOnline = isfield(dat.settings, 'isSessionRunning') && dat.settings.isSessionRunning;

    % Processing loop:
    while true
        iFrame = iFrame + 1;
        ticLoopStart = tic;
        while iFrame > nStimFramesDisplayed
            fprintf('Cond %d: Have been waiting for new frames for %1.0f seconds.\n', ...
                iCond, toc(ticLoopStart));
            
            if (toc(ticLoopStart) > 180) || ~isOnline
                % If no new data was saved for 3 minutes, assume session is
                % over:
                isSessionOver = 1;
                break
            end
            
            pause(10)
            try
                dat = load(datFile);
                % Flag indicating if session is running right now:
                isOnline = isfield(dat.settings, 'isSessionRunning') && dat.settings.isSessionRunning;
            catch err
                warning(err.Message)
                disp('Will try again in 10 seconds...')
                continue
            end
            nStimFramesDisplayed = max(dat.frame.past.frameId);
        end
        
        if isSessionOver
            break
        end
        
        % Skip the stimulus frames on which no image was triggered:
        if ~dat.frame.past.isCamTriggerFrame(iFrame)
            continue
        end
        
        % Skip frames that are not the right condition:
        if dat.frame.past.barDirection_deg(iFrame)~=results(iCond).dir
            continue
        end
        
        % Load frame:
        iFile = sum(dat.frame.past.isCamTriggerFrame(1:iFrame));
        fileNameHere = sprintf('%s%04.0f.tiff', movNamePrefix, iFile);
        fileNameHere = fullfile(movFolder, fileNameHere);
        
        if exist(fileNameHere, 'file')
            try
                imgHere = double(imread(fileNameHere));
            catch
                break
            end
        else
            imgHere = nan; %#ok<NASGU> % Suppresses warning about non-existing variable in parfor loop.
            warning('Could not find file %s.\n This should not happen during online processing, but can happen at the end of an acquisition if the last frame was saved incompletely. Check what''s going on!', ...
                fileNameHere);
            break
        end

        % Correct motion:
        imgHereGpu = gpuArray(single(imgHere));
        imgHereMc = ifft2(ifftshift(fftshift(fft2(imgHere)) .* (1-fftFiltWin))); % Filter image as described above (where ref is calculated).
        [imgHereGpu, results(iCond).xShift(iFrame), results(iCond).yShift(iFrame)] = ...
            correct_translation_singleframe(imgHereMc, ...
            ref_fft, 1, imgHereGpu);
        
        % Spatial high-pass filter with large kernel to remove global
        % fluctuations:
        imgHere = double(gather(imgHereGpu - imgaussfilt(imgHereGpu, 100, 'pad', 'symm')));
        
        % Add current frame to the appropriate bin:
        iBin = discretize(dat.frame.past.barPosition_deg(iFrame), edges);
        results(iCond).tuning(:,:,iBin) = results(iCond).tuning(:,:,iBin) ...
            + imgHere;
        results(iCond).nInBin(iBin) = results(iCond).nInBin(iBin)+1;
        
        if true %iCond==1
            fprintf('Cond %d: Processing file % 6.0f (%1.1f FPS in total)\n', ...
                iCond, iFile, nCond * nFramesProcessedThisCond/toc(ticStartThisCond));
        end
        
        nFramesProcessedThisCond = nFramesProcessedThisCond+1;
        
        if ~mod(nFramesProcessedThisCond, 1000)            
            tuningHere = bsxfun(@rdivide, results(iCond).tuning, ...
                permute(results(iCond).nInBin(:), [3 2 1]));
            
            isGoodFrame = results(iCond).nInBin > 0;
            tuningHere = tuningHere(:,:,isGoodFrame);
            tiffWrite(scaleArray(tuningHere)*2^16, sprintf('tuning_cond%d.tif', ...
                iCond), 'T:\');
            
            % For debugging, store intermediate 1000 frame blocks:
%             tiffWrite(scaleArray(tuningHere)*2^16, sprintf('tuning_cond%d_block%d.tif', ...
%                 iCond, nFramesProcessedThisCond/1000), 'T:\');
%             results(iCond).tuning = results(iCond).tuning.*0;
%             results(iCond).nInBin = results(iCond).nInBin.*0;
            
        end
    end
end

% dat.mov.ref = ref;

%% Save:
[p, f, ~] = fileparts(datFile);
f = sprintf('%s_results%s', f, datestr(now, 'yymmdd'));
dat = load(datFile);
dat.results = results;
save(fullfile(p, f), '-struct', 'dat');

% keyboard