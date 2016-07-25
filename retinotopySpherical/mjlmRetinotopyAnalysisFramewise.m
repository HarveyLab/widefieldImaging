function results = mjlmRetinotopyAnalysisFramewise

%% Settings:
% base = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield';
base = 'D:\Data\Matthias';
movFolder = fullfile(base, 'lightTightTest');
datFile = fullfile(base, '20160719_133126_retinotopy_lightTightTest.mat');
isSubtractBaseline = false;

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
nFramesInSyncStruct = numel(dat.frame.past.frameId);
[~, order] = sort(fileNameNumber);
lst = lst(order);
lst = lst(1:nFramesInSyncStruct);

img = imread(fullfile(movFolder, lst(1).name));
dat.mov.height = size(img, 1);
dat.mov.width = size(img, 2);
dat.mov.nFrames = nFramesInSyncStruct;
dat.mov.nPixPerFrame = dat.mov.height * dat.mov.width;
temporalDownSampling = 1;

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
    results(iCond).iStart = find(isFrameThisCond(1:temporalDownSampling:end), 1, 'first');
    results(iCond).iEnd = find(isFrameThisCond(1:temporalDownSampling:end), 1, 'last');
    results(iCond).nFrames = sum(isFrameThisCond(1:temporalDownSampling:end));
    results(iCond).nReps = sum(abs(diff(dat.frame.past.barPosition_deg) .* isFrameThisCond(max(temporalDownSampling, 2):end))>10);
    if iCond==1
        results(iCond).nReps = results(iCond).nReps+1;
    end
    results(iCond).period = results(iCond).nFrames / results(iCond).nReps;
    
    barPosBinnedHere = barPosBinned(dat.frame.past.barDirection_deg==results(iCond).dir);
    results(iCond).uniqueBins = unique(barPosBinnedHere);
    results(iCond).nInBin = accumarray(barPosBinnedHere', ones(size(barPosBinnedHere')));
    results(iCond).tuning = zeros(dat.mov.height, dat.mov.width, nBins);
end

%% Retinotopy extraction algorithm:
if isSubtractBaseline
    % Go through data frame by frame. Bin data by bar positon. Keep a running
    % average for baseline subtraction.

    for iCond = 1:nCond
        baselineWin = round(results(iCond).period * 2);
        baselineLead = round(baselineWin/2);
        iBaselineStack = 0;
        baselineStack = [];

    %     Pre-load the frames needed for the baseline:
        for iBaselineStack = 1:baselineWin
            iFrameForBaseline = results(iCond).iStart - baselineLead + iBaselineStack;
            iFrameForBaseline = min(max(iFrameForBaseline, 1), nFramesInSyncStruct);

            imgHere = double(imread(fullfile(movFolder, lst(iFrameForBaseline).name)));
            imgHere(imgHere<1000) = imgHere(imgHere<1000) + 2^16; % Fix overflow

            if isempty(baselineStack)
                baselineStack = repmat(imgHere, 1, 1, baselineWin);
            else
                baselineStack(:,:,iBaselineStack) = imgHere; %#ok<AGROW>
            end
        end
        baseline = mean(baselineStack, 3);

        for iFrame = results(iCond).iStart : results(iCond).iEnd
            % iBaselineStack keeps track of the current frame in the baseline
            % stack. The stack is a circular buffer and we don't want to use
            % circshift for speed reasons.
            iBaselineStack = mod(iBaselineStack, baselineWin) + 1;

            % Store newest frame in baseline stack:
            iFrameForBaseline = iFrame + baselineLead;

            if iFrameForBaseline <= nFramesInSyncStruct
                % Subtract oldest frame from baseline:
                baseline = baseline - baselineStack(:,:,iBaselineStack)./baselineWin;

                imgHere = double(imread(fullfile(movFolder, lst(iFrameForBaseline).name)));
                imgHere(imgHere<1000) = imgHere(imgHere<1000) + 2^16; % Fix overflow
                baselineStack(:,:,iBaselineStack) = imgHere; %#ok<AGROW>

                % Add newest frame to baseline:
                baseline = baseline + baselineStack(:,:,iBaselineStack) ./ baselineWin;
            end

            % The currently analyzed frame lags behind the most recent baseline
            % frame because the baseline window is supposed to be centered on
            % the currently analyzed frame. So we get the currently analyzed
            % frame from the baseline stack. We then correct current frame by
            % subtractidng the baseline, scaled so that the overall weight of
            % the baseline is 1:
            iForAnalysis = mod(iBaselineStack-baselineLead-1, baselineWin)+1;
            imgForAnalysis = baselineStack(:, :, iForAnalysis);
            imgForAnalysis = imgForAnalysis - baseline;

            % Add current frame to the appropriate bin:
            iBin = barPosBinned(iFrame);

            results(iCond).tuning(:,:,iBin) = results(iCond).tuning(:,:,iBin) ...
                + imgForAnalysis ./ results(iCond).nInBin(iBin);

    %         cond(iCond).tuning(:,:,iBin) = cond(iCond).tuning(:,:,iBin) ...
    %             + double(imread(fullfile(movFolder, lst(iFrame).name))) ...
    %             ./ cond(iCond).nInBin(iBin);

            % For debugging:
            %         figure(1)
            %         imagesc(baseline)
            %
            %         figure(2)
            %         imagesc(imgHere)
            %
            %         figure(3)
            %         imagesc(cond(i).tuning(:,:,iBin))
            %         1;

            fprintf('Processing frame % 6.0f/% 6.0f\n', ...
                iFrame, nFramesInSyncStruct);
        end
    end

else
    % Go through data frame by frame. Bin data by bar positon. Keep a running
    % average for baseline subtraction.

    % For motion correction, use center frame as reference:
    ref = double(imread(fullfile(movFolder, lst(round(nFramesInSyncStruct/2)).name)));
    ref(ref<1000) = ref(ref<1000) + 2^16; % Fix overflow
    
    % Pre-calculate reference FFT:
    ref_fft = zeros(size(ref, 1), size(ref, 2), 3);
    ref_fft(:,:,1) = fft2(ref);
    ref_fft(:,:,2) = fftshift(ref_fft(:,:,1));
    ref_fft(:,:,3) = conj(ref_fft(:,:,1));

    ticProc = tic;
    for iCond = 1:nCond
        for iFrame = results(iCond).iStart : results(iCond).iEnd
            % Load frame:
            imgHere = double(imread(fullfile(movFolder, lst(iFrame).name)));
            imgHere(imgHere<1000) = imgHere(imgHere<1000) + 2^16; % Fix occasional overflow

            % Correct motion:
            [imgHere, dat.mov.shifts.x(iFrame), dat.mov.shifts.y(iFrame)] = ...
                correct_translation_singleframe(imgHere, ref_fft, 1);
    
            % Add current frame to the appropriate bin:
            iBin = barPosBinned(iFrame);
            results(iCond).tuning(:,:,iBin) = results(iCond).tuning(:,:,iBin) ...
                + imgHere ./ results(iCond).nInBin(iBin);
            
            fprintf('Processing frame % 6.0f/% 1.0f (%1.1f minutes left)\n', ...
                iFrame, nFramesInSyncStruct, (toc(ticProc)/(60*iFrame)) * (nFramesInSyncStruct-iFrame));
        end
    end 
end

dat.mov.ref = ref;

%% Save:
[p, f, ~] = fileparts(datFile);
f = sprintf('%s_results%s', f, datestr(now, 'yymmdd'));
dat.results = results;
save(fullfile(p, f), '-struct', 'dat');