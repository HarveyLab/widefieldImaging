%% Load averaged movie:
p = '\\intrinsicScope\D\Data\Matthias';
mov = tiffRead(fullfile(p, '2016-06-07_19-47-44_somatotopy_MM101_somato_avgMov.tif'));
[height, width, nFrames] = size(mov);

%% Settings:
nChunksOn = 2;
nChunksOff = 18;
nCond = 4;
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
stimChunks = 3; % For MM101, there is a weird vessel artefact in frames 1:2 of the flank stim. Frame 3 looks better.
blankChunks = (4:5) + 4;

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
figure(3)
imagesc(movAvg(:,:,5))
colormap(jet)

%% Show differences between two conditions:
hindlimb = movAvg(:,:,3) - movAvg(:,:,5);
hindlimb = imgaussfilt(hindlimb, 10);
figure(1)
imagesc(hindlimb, prctile(hindlimb(:), [0.1 99.9]))
colormap(french)

title({'Left-right forelimb response', ...
    '(Note that response is negative-going.', ...
    'Left lowers reflectance in right cortex.'})