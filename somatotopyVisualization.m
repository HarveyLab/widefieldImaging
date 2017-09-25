%% Load averaged movie:
% p = '\\intrinsicScope\D\Data\Matthias';
% p = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield';
% p = 'T:\';
base = fullfile('C:\DATA\');

%select file for average movie
[movFile, movPath, ~] = uigetfile([base '*.tif']);
mov = tiffRead(fullfile(movPath,movFile));

%select file containing metadata and settings
[metaFile, metaPath, ~] = uigetfile([base '*.mat']);
meta = load(fullfile(metaPath,metaFile));

% MM102:
% mov = tiffRead(fullfile(p, '20160718_184127_somatotopy_MM102_160718_avgMov160719.tif')); % No mtion corr.
% meta = load(fullfile(p, '20160718_184127_somatotopy_MM102_160718.mat'));

% % Alan's 2 GU t8 actual:
% mov = single(tiffRead(fullfile(p, '20170824_164215_somatotopy_actual_avgMov170825.tif')));
% meta = load(fullfile(p, '20170824_164215_somatotopy_actual.mat'));

% % Alan's 2 GU t8 actual2:
% mov = single(tiffRead(fullfile(p, '20170824_174902_somatotopy_actual2_avgMov170826.tif')));
% meta = load(fullfile(p, '20170824_174902_somatotopy_actual2.mat'));

% % Lumbar corticospinal 20170828:
% mov = single(tiffRead(fullfile(p, '20170828_164154_somatotopy_one_avgMov170828.tif')));
% meta = load(fullfile(p, '20170828_164154_somatotopy_one.mat'));

[height, width, nFrames] = size(mov);

% for i = 1:nFrames
%     i
%     movDetrend(:,:,i) = imgaussfilt(movDetrend(:,:,i), 5);
% end
% mn = mean(mean(movDetrend, 1), 2);
% movDetrend = bsxfun(@rdivide, bsxfun(@minus, movDetrend, mn), mn);

%% Settings:
nChunksOn = meta.settings.onTime_s/0.25;
nChunksOff = meta.settings.offTime_s/0.25;
nCond = numel(meta.settings.motorPositionName);
nChunksPerTrial = nChunksOn + nChunksOff;

%% (Get mean trace for ROI:)
% iRow = 53:90;
% iCol = 343:391;
% trace = squeeze(mean(mean(mov(iRow, iCol, :), 1), 2));
% figure(1)
% clf
% hold on
% plot(trace)
% onFrames = 1:(nChunksOn+nChunksOff):numel(trace);
% onFrames = cat(2, onFrames, onFrames+1);
% plot(onFrames, trace(onFrames), '.r')

%% Create DF movie:
movDiff = mov;
for i = nChunksPerTrial:nChunksPerTrial:(nFrames-nChunksPerTrial)
    i
    movDiff(:,:,i+(1:nChunksPerTrial)) = ...
        bsxfun(@minus, mov(:,:,i+(1:nChunksPerTrial)), mov(:,:,i));
end
movDiff(:,:,[1:nChunksPerTrial (end-nChunksPerTrial+1):end]) = nan;

%% For each condition, average all repeats:
avgMov = zeros(height, width, (nChunksOn+nChunksOff)*nCond);
chunkId = repmat(1:(nChunksOn+nChunksOff), 1, meta.settings.nRepeats*nCond);
condId = repelem(meta.settings.motorSequence', (nChunksOn+nChunksOff));

for i = 1:size(avgMov, 3)
    i
    condHere = ceil(i/(nChunksOn+nChunksOff));  % is ceiling here correct??
    chunkHere = mod(i, nChunksOn+nChunksOff);
    if chunkHere==0
        chunkHere = nChunksOn+nChunksOff;
    end
    
    % Calculate difference between current condition and other conditions:
%     avgMov(:,:,i) = nanmean(movDiff(:,:,chunkId==chunkHere & condId==condHere), 3) - ...
%        nanmean(movDiff(:,:,chunkId==chunkHere & condId~=condHere), 3);
    avgMov(:,:,i) = nanmean(movDiff(:,:,chunkId==chunkHere & condId==condHere), 3);
end

avgMov = bsxfun(@minus, avgMov, mean(avgMov, 3));
ijPlay(avgMov)

%% Subtract mean of blank and average:
% Select which chunks (out of nChunksOn+Off) go torwards the stim and blank
% averages:
stimChunks = 1:2;
blankChunks = 3:8;

% Subtract mean of blank for each chunk:
movSub = zeros(height, width, nFrames/nChunksPerTrial);
for i = 0:nChunksPerTrial:(nFrames-nChunksPerTrial)
    % Average the chunks containing the response:
    stim = mean(mov(:,:,stimChunks+i), 3);
    
    % Average the chunks used as the baseline:
    baseline = mean(mov(:,:,blankChunks+i), 3);
    
    % Calculate dR/R:
    movSub(:,:,(i+nChunksPerTrial)/nChunksPerTrial) = (stim-baseline) ./ baseline;
end

% Average repeats:
movAvg = zeros(height, width, nCond);
for i = 1:nCond
    movAvg(:,:,i) = mean(movSub(:,:,i:nCond:end), 3);
    movAvg(:,:,i) = imgaussfilt(movAvg(:,:,i), 3);
end
ijPlay(movAvg)

%% Show individual conditions:
figure(2)
imagesc(movAvg(:,:,1),[0,0.0025])
pbaspect([1 1 1])
colorbar
title(meta.settings.motorPositionName{1})
xticks([])
yticks([])
colormap(parula)

figure(3)
imagesc(movAvg(:,:,2),[-0.0025,0.0025])
pbaspect([1 1 1])
title(meta.settings.motorPositionName{2})
colormap(parula)
xticks([])
yticks([])

figure(4)
imagesc(movAvg(:,:,3),[0, 0.0025])
title(meta.settings.motorPositionName{3})
colormap(parula)
pbaspect([1 1 1])
xticks([])
yticks([])

%% Show activation relative to mean:
movRel = movAvg(:,:,[1, 2, 3]);
movRel = bsxfun(@rdivide, movRel, mean(mean(movRel, 1), 2));
movRel = bsxfun(@minus, movRel, mean(movRel, 3));
ijPlay(movRel)

%% Show differences between two conditions:

hindlimb = movAvg(:,:,2) - movAvg(:,:,1);
hindlimb = imgaussfilt(hindlimb, 10);
figure(5)
imagesc(hindlimb, prctile(hindlimb(:), [0.1 99.9]))
colormap(parula)
title('hindlimb-back response')
pbaspect([1 1 1])
xticks([])
yticks([])