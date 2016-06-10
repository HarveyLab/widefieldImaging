%% Load averaged movie:
% p = '\\intrinsicScope\D\Data\Matthias';
p = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield';
% p = 'T:\';
mov = tiffRead(fullfile(p, '2016-06-08_18-41-10_somatotopy_MM102_somato_avgMov160609.tif'));
load();
[height, width, nFrames] = size(mov);

movDetrend = mov;
for i = 1:nFrames
    i
%     movDetrend(:,:,i) = imgaussfilt(movDetrend(:,:,i), 5);
end
mn = mean(mean(movDetrend, 1), 2);
movDetrend = bsxfun(@rdivide, bsxfun(@minus, movDetrend, mn), mn);

%% Settings:
nChunksOn = settings.onTime_s*2;
nChunksOff = settings.offTime_s*2;
nCond = numel(settings.motorOrder);
nChunksPerTrial = nChunksOn + nChunksOff;

%% Get mean trace for ROI:
iRow = 53:90;
iCol = 343:391;
trace = squeeze(mean(mean(mov(iRow, iCol, :), 1), 2));
figure(1)
clf
hold on
plot(trace)
onFrames = 1:(nChunksOn+nChunksOff):numel(trace);
onFrames = cat(2, onFrames, onFrames+1);
plot(onFrames, trace(onFrames), '.r')

%% Subtract mean of blank and average:
% Select which chunks (out of nChunksOn+Off) go torwards the stim and blank
% averages:
% stimChunks = 1:2;
stimChunks = 1:2; % For MM101, there is a weird vessel artefact in frames 1:2 of the flank stim. Frame 3 looks better.
blankChunks = 3:10;

% Subtract mean of blank for each chunk:
movSub = zeros(height, width, nFrames/nChunksPerTrial);
for i = 0:nChunksPerTrial:(nFrames-nChunksPerTrial)
    % Average the chunks containing the response:
    stim = mean(movDetrend(:,:,stimChunks+i), 3);
    
    % Average the chunks used as the baseline:
    baseline = mean(movDetrend(:,:,blankChunks+i), 3);
    
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
figure(3)
imagesc(movAvg(:,:,5))
colormap(jet)

%% Show activation relative to mean:
movRel = movAvg(:,:,[1,  4, 5]);
movRel = bsxfun(@rdivide, movRel, mean(mean(movRel, 1), 2));
movRel = bsxfun(@minus, movRel, mean(movRel, 3));
ijPlay(movRel)

%% Show differences between two conditions:
hindlimb = movAvg(:,:,3) - movAvg(:,:,5);
hindlimb = imgaussfilt(hindlimb, 10);
figure(1)
imagesc(hindlimb, prctile(hindlimb(:), [0.1 99.9]))
colormap(french)

title({'Left-right forelimb response', ...
    '(Note that response is negative-going.', ...
    'Left lowers reflectance in right cortex.'})