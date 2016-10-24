%% Load data:
p = '\\intrinsicScope\D\Data\Shin';

load(fullfile(p, '20161007_124046_retinotopy_LT009_results161007'));
meta = load(fullfile(p, '20161007_124046_retinotopy_LT009.mat'));

%% Get response phase:
nCond = numel(results);
conds = unique(meta.frame.past.barDirection_deg);

% Create working copy of response:
for i = 1:nCond
    results(i).tuningCorr = results(i).tuning;    
    results(i).isGoodFrame = results(i).nInBin>0;
end

for i = 1:nCond
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
    movHere = results(i).tuning(:,:,results(i).isGoodFrame);
    ijPlay(movHere, ...
        sprintf('Condition %d', i));
end

%% Plot
isBackwards = 0;

figure(1)
clf

subplot(2, 3, 1);
imagesc(wrapToPi(angle(results(1+2*isBackwards).fft)), [-pi pi])
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
meanVerti = wrapToPi((angle(results(1).fft)+angle(results(3).fft))/2);
imagesc(meanVerti, [-pi pi])
colormap(gca, jet)
colorbar
axis equal
title('Vertical mean (more positive = higher altitude)')
colorbar

subplot(2, 3, 5);
meanHori = wrapToPi((angle(results(2).fft)+angle(results(4).fft))/2);
imagesc(meanHori, [-pi pi])
colormap(gca, jet)
colorbar
axis equal
title('Horizontal mean (more positive = more temporal)')
colorbar

subplot(2, 3, 3);
powerCombined = abs(results(1).fft) ...
    + abs(results(3).fft) ...
    + abs(results(2).fft) ...
    + abs(results(4).fft);
imagesc(powerCombined, prctile(powerCombined(:), [0.5 99.5]))
colormap(gca, jet)
axis equal
title('Combined power')

subplot(2, 3, 6);
smoothRad = 5;
[Gmag, Gdir1] = imgradient(imgaussfilt(meanVerti, smoothRad));
[~, Gdir2] = imgradient(imgaussfilt(meanHori, smoothRad));
fieldSign = sind(Gdir1 - Gdir2);
imagesc(imgaussfilt(fieldSign, smoothRad))
colormap(gca, jet)
title('Field sign')
axis equal

return

%% Save field sign:
p = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield\MM110\map';
n = 'MM110_160922_overview';
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
meanHori = wrapToPi((results(1).angleNoDelay+results(3).angleNoDelay)/2);
imagesc(meanHori, [-pi pi]/1.5)
colormap(gca, jet)
title('Vertical mean (more positive = higher altitude)')
colorbar
axis equal

subplot(2, 3, 5);
meanVerti = wrapToPi((results(2).angleNoDelay+results(4).angleNoDelay)/2);
imagesc(meanVerti, [-pi pi]/1.5)
colormap(gca, jet)
title('Horizontal mean (more positive = more temporal)')
colorbar
axis equal

% Note: Field sign is not affected by subtractind delay.
subplot(2, 3, 6);
[~, Gdir1] = imgradient(imgaussfilt(meanVerti, smoothRad));
[~, Gdir2] = imgradient(imgaussfilt(meanHori, smoothRad));
fieldSign = sind(Gdir2 - Gdir1);
fieldSign = imgaussfilt(fieldSign, smoothRad);
imagesc(fieldSign)
colormap(gca, jet)
title('Field sign')
axis equal

%% Save data:
wfDir = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield\';
mapDir = fullfile(wfDir, 'MM104\map');
if ~exist(mapDir, 'dir')
    mkdir(mapDir);
end

fname = [meta.settings.expName '_retino'];

imInd = gray2ind(mat2gray(powerCombined), 255);
imwrite(imInd, jet(255), fullfile(mapDir, [fname, '_power.png']));

imInd = gray2ind(mat2gray(fieldSign), 255);
imwrite(imInd, jet(255), fullfile(mapDir, [fname, '_fieldSign.png']));
