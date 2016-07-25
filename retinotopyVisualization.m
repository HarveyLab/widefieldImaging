%% Load data:
% p = '\\intrinsicScope\D\Data\Matthias';
p = 'T:\';
load(fullfile(p, '20160718_182703_retinotopy_MM102_160718_results160718.mat'));
meta = load(fullfile(p, '20160718_182703_retinotopy_MM102_160718.mat'));
% p = 'T:\ltt\';
% load(fullfile(p, '20160719_133126_retinotopy_lightTightTest_results160719.mat'));
% meta = load(fullfile(p, '20160719_133126_retinotopy_lightTightTest.mat'));

% Check if bar position record is incorrect, i.e. flipped for 90 and 180
% degrees (this happened because I didn't take into account a rotation
% during the generation of visual stimuli):
isBarPositionSignIncorrect = meta.frame.past.barPosition_deg(...
    find(meta.frame.past.barDirection_deg == 90, 1, 'first')) < 0;

%% Get response phase:
nCond = numel(results);
conds = unique(meta.frame.past.barDirection_deg);

% Create working copy of response:
for i = 1:nCond
    results(i).tuningCorr = results(i).tuning;
    
    if isBarPositionSignIncorrect && (conds(i)==90 || conds(i)==180)
        results(i).tuningCorr = results(i).tuningCorr(:,:,end:-1:1);
    end
    
    results(i).isGoodFrame = results(i).nInBin>0;
end

% for i = 1:nCond
%     for ii = 1:size(results(i).tuning, 3)
%         % Normalize by each frame's brightness:
%         results(i).tuningCorr(:,:,ii) = results(i).tuningCorr(:,:,ii) ...
%             ./ mean(col(results(i).tuningCorr(:,:,ii)));
%         
%         % Apply smoothing:
% %         results(i).tuningCorr(:,:,ii) = imgaussfilt(results(i).tuningCorr(:,:,ii), 10);
%     end
% end

for i = 1:nCond
    % Subtract out screen light contamination (improve that!):
%     mnScreenCont = zeros(2, 2, size(results(i).tuningCorr, 3));
%     mnScreenCont(1, 1, :) = mean(mean(results(i).tuningCorr(1:50, 1:50, :), 1), 2);
%     mnScreenCont(1, 2, :) = mean(mean(results(i).tuningCorr(1:50, end-51:end, :), 1), 2);
%     mnScreenCont(2, 1, :) = mean(mean(results(i).tuningCorr(end-51:end, 1:50, :), 1), 2);
%     mnScreenCont(2, 2, :) = mean(mean(results(i).tuningCorr(end-51:end, end-51:end, :), 1), 2);
%     mnScreenContFull = zeros(size(results(i).tuningCorr));
%     for ii = 1:size(results(i).tuningCorr, 3)
%         mnScreenContFull(:,:,ii) = imresize(mnScreenCont(:,:,ii), ...
%             [size(results(i).tuningCorr, 1), size(results(i).tuningCorr, 2)]);
%     end
%     
%     results(i).tuningCorr = results(i).tuningCorr - mnScreenContFull;

    mnScreenContam = mean(mean(results(i).tuningCorr(1:200, :, :), 1), 2);
    results(i).tuningCorr = bsxfun(@minus, results(i).tuningCorr, mnScreenContam);
    
    % Calculate dR:
%     mn = mean(results(i).tuningCorr(:,:,results(i).isGoodFrame), 3);
%     results(i).tuningCorr = bsxfun(@minus, results(i).tuningCorr, mn);
    
    % Get FFT at first non-DC frequency:
    tmp = fft(results(i).tuningCorr(:,:,results(i).isGoodFrame), [], 3);
    % We multiply by -1 to rotate the complex angle by 180 deg so that the
    % center of the trial (center of visual field) corresponds to zero
    % angle:
    results(i).fft = tmp(:,:,2) * -1;
end

% Get added and subtracted phase field as described in Kalatsky and
% Stryker:
for i = 1:2
    results(i).add = results(i).fft .* results(i+2).fft;
    results(i).subt = results(i).fft ./ results(i+2).fft;
end

%% Play movies for visual inspection:
for i = 1:nCond
    ijPlay(results(i).tuningCorr(:,:,results(i).isGoodFrame), sprintf('Condition %d', i));
end

%% Plot
isBackwards = 0;

figure(1)
clf

subplot(2, 3, 1);
imagesc(wrapToPi(angle(results(1+2*isBackwards).fft)), [-pi pi])
% imagesc(wrapToPi(angle(results(4).fft)), [-pi pi])
colormap(gca, jet)
colorbar
axis equal
title('Vertical single condition')

subplot(2, 3, 4);
imagesc(-wrapToPi(angle(results(2+2*isBackwards).fft)), [-pi pi])
colormap(gca, jet)
colorbar
axis equal
title('Horizontal single condition')

subplot(2, 3, 2);
% meanVerti = -wrapToPi((angle(results(1).fft)-angle(results(3).fft))/2);
meanVerti = wrapToPi(angle(results(1+2*isBackwards).fft));
imagesc(meanVerti, [-pi pi])
colormap(gca, jet)
colorbar
axis equal
title('Vertical mean (more positive = higher altitude)')
colorbar

subplot(2, 3, 5);
% meanHori = wrapToPi((angle(results(2).fft)-angle(results(4).fft))/2);
meanHori = wrapToPi(angle(results(2+2*isBackwards).fft));
imagesc(meanHori, [-pi pi])
colormap(gca, jet)
colorbar
axis equal
title('Horizontal mean (more positive = more temporal)')
colorbar

subplot(2, 3, 3);
% imagesc(log(abs(results(1).fft)) ...
%     + log(abs(results(3).fft)) ...
%     + log(abs(results(2).fft)) ...
%     + log(abs(results(4).fft)), ...
%     [-19 -6])
imagesc(log(abs(results(1).fft)) ...
    + log(abs(results(2).fft)))
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

%% Ssve field sign:
p = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield\MM102\map';
n = 'MM102_160718_overview';
imwrite(ceil(mat2gray(imgaussfilt(fieldSign, smoothRad))*255), jet(255), fullfile(p, [n '_fieldsign.png']))

%% Get delay:
% subplot(2, 3, 6);
% h = impoly;
% isV1 = createMask(h);
% delay = angle(median(results(2).subt(isV1)))/2;

for i = 1:2
    results(i).angleNoDelay = angle(results(i).fft) - delay ;
end

for i = 3:4
    results(i).angleNoDelay = angle(results(i).fft) - delay;
end

%% Plot after subtracting delay:
% figure(11101)
% imagesc(wrapToPi(results(2).angleNoDelay), [-pi pi])
% colormap(hsv)
% axis equal

subplot(2, 3, 2);
meanHori = -wrapToPi((results(1).angleNoDelay-results(3).angleNoDelay)/2);
imagesc(meanHori, [-pi pi])
colormap(gca, jet)
title('Vertical mean (more positive = higher altitude)')
colorbar
axis equal

subplot(2, 3, 5);
meanVerti = wrapToPi((results(2).angleNoDelay-results(4).angleNoDelay)/2);
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
