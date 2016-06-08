%% Load data:
p = '\\intrinsicScope\D\Data\Matthias';
load(fullfile(p, '2016-06-07_19-24-25_somatotopy_MM101_retino_gain15_rgb100_results.mat'));
meta = load(fullfile(p, '2016-06-07_19-24-25_somatotopy_MM101_retino_gain15_rgb100.mat'));

%% Get response phase:
nCond = numel(retino);

% Create working copy of response:
for i = 1:nCond
    retino(i).tuningCorr = retino(i).tuning;
end

for i = 1:nCond
    for ii = 1:size(retino(i).tuning, 3)
        % Normalize by each frame's brightness:
        retino(i).tuningCorr(:,:,ii) = retino(i).tuningCorr(:,:,ii) ...
            ./ mean(col(retino(i).tuningCorr(:,:,ii)));
        
        % Apply smoothing:
%         retino(i).tuningCorr(:,:,ii) = imgaussfilt(retino(i).tuningCorr(:,:,ii), 10);
    end
end

for i = 1:nCond
    % Convert the blank frames to nan to exclude from averaging:
    retino(i).tuningCorr(retino(i).tuning==0) = nan;
    
    % Calculate dR:
    mn = nanmean(retino(i).tuningCorr, 3);
    retino(i).tuningCorr = bsxfun(@minus, retino(i).tuningCorr, mn);
    retino(i).tuningCorr = nan2zero(retino(i).tuningCorr);
    
    % Get FFT at first non-DC frequency:
    tmp = fft(retino(i).tuningCorr, [], 3);
    % We multiply by -1 to rotate the complex angle by 180 deg so that the
    % center of the trial (center of visual field) corresponds to zero
    % angle:
    retino(i).fft = tmp(:,:,2) * -1;
end

% Get added and subtracted phase field as described in Kalatsky and
% Stryker:
for i = 1:2
    retino(i).add = retino(i).fft .* retino(i+2).fft;
    retino(i).subt = retino(i).fft ./ retino(i+2).fft;
end

%% Plot
isBackwards = 1;

figure(1)
clf

subplot(2, 3, 1);
imagesc(wrapToPi(angle(retino(1+2*isBackwards).fft)), [-pi pi])
colormap(gca, jet)
colorbar
axis equal
title('Vertical single condition')

subplot(2, 3, 4);
imagesc(-wrapToPi(angle(retino(2+2*isBackwards).fft)), [-pi pi])
colormap(gca, jet)
colorbar
axis equal
title('Horizontal single condition')

subplot(2, 3, 2);
meanVerti = -wrapToPi((angle(retino(1).fft)-angle(retino(3).fft))/2);
imagesc(meanVerti, [-pi pi])
colormap(gca, jet)
colorbar
axis equal
title('Vertical mean (more positive = higher altitude)')
colorbar

subplot(2, 3, 5);
meanHori = wrapToPi((angle(retino(2).fft)-angle(retino(4).fft))/2);
imagesc(meanHori, [-pi pi])
colormap(gca, jet)
colorbar
axis equal
title('Horizontal mean (more positive = more temporal)')
colorbar

subplot(2, 3, 3);
imagesc(log(abs(retino(1).fft)) ...
    + log(abs(retino(3).fft)) ...
    + log(abs(retino(2).fft)) ...
    + log(abs(retino(4).fft)), ...
    [-19 -6])
colormap(gca, jet)
axis equal
title('Combined power')

subplot(2, 3, 6);
smoothRad = 5;
[~, Gdir1] = imgradient(imgaussfilt(meanVerti, smoothRad));
[~, Gdir2] = imgradient(imgaussfilt(meanHori, smoothRad));
fieldSign = sind(Gdir1 - Gdir2);
imagesc(imgaussfilt(fieldSign, smoothRad))
colormap(gca, jet)
title('Field sign')
axis equal

%% Get delay:
% subplot(2, 3, 6);
% h = impoly;
% isV1 = createMask(h);
% delay = angle(median(retino(2).subt(isV1)))/2;

for i = 1:2
    retino(i).angleNoDelay = angle(retino(i).fft) - delay ;
end

for i = 3:4
    retino(i).angleNoDelay = angle(retino(i).fft) - delay;
end

%% Plot after subtracting delay:
% figure(11101)
% imagesc(wrapToPi(retino(2).angleNoDelay), [-pi pi])
% colormap(hsv)
% axis equal

subplot(2, 3, 2);
meanHori = -wrapToPi((retino(1).angleNoDelay-retino(3).angleNoDelay)/2);
imagesc(meanHori, [-pi pi])
colormap(gca, jet)
title('Vertical mean (more positive = higher altitude)')
colorbar
axis equal

subplot(2, 3, 5);
meanVerti = wrapToPi((retino(2).angleNoDelay-retino(4).angleNoDelay)/2);
imagesc(meanVerti, [-pi pi])
colormap(gca, jet)
title('Horizontal mean (more positive = more temporal)')
colorbar
axis equal

subplot(2, 3, 6);
smoothRad = 5;
[~, Gdir1] = imgradient(imgaussfilt(meanVerti, smoothRad));
[~, Gdir2] = imgradient(imgaussfilt(meanHori, smoothRad));
fieldSign = sind(Gdir2 - Gdir1);
imagesc(imgaussfilt(fieldSign, smoothRad))
colormap(gca, jet)
axis equal
