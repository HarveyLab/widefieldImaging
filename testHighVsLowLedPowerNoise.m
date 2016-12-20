% Data was acquired at high frame rate (~500Hz) at two different LED power
% settings (the exposure time was adjusted so that the pixel intensity
% values are similar in each case).

%% Get low power data
ls = dir('\\intrinsicScope\e\Data\Matthias\noise test\low led setting\*.tiff');
lowPower = zeros(10, 8, numel(ls));

for i = 1:numel(ls)
   i
   lowPower(:,:,i) = imread(fullfile('\\intrinsicScope\e\Data\Matthias\noise test\low led setting\', ...
       ls(i).name));
end

%% Get low power data
ls = dir('\\intrinsicScope\e\Data\Matthias\noise test\high led setting\*.tiff');
highPower = zeros(10, 8, numel(ls));

for i = 1:numel(ls)
   i
   highPower(:,:,i) = imread(fullfile('\\intrinsicScope\e\Data\Matthias\noise test\high led setting\', ...
       ls(i).name));
end

%% Look at correlations between pixels:
% The idea is that there are (at least) two noise sources: LED light
% fluctuations and pixel shot noise. To dissociate them, we can look at the
% correlation of the timeseries of a pixel with all other pixels. If there
% is shared noise from LED fluctuations, this would result in a positive
% average correlation.

% All pixels along one line share common noise due to the chip layout. So
% we create a mask that excludes pixel pairs that are on the same line, so
% that we get a nice unimodal distribution of correlations:
mask = full(spdiags(ones(80, 17), -80:10:80, 80, 80));

cmatHigh = corr(reshape(highPower, [], 6500)');
cmatLow = corr(reshape(lowPower, [], 6500)');

figure(88213)
clf
hold on

histogram(cmatHigh(mask~=1))
histogram(cmatLow(mask~=1))
plot([0 0], ylim, 'k')

title(sprintf('Mean corr: High power = %1.1e, Low power = %1.1e', ...
    mean(cmatHigh(mask~=1)), mean(cmatLow(mask~=1))))