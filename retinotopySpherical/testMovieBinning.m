%% Create fake movie that will make it clear if binning works:
mov = zeros(128, 128, 15001);
[h, w, z] = size(mov);
% step = max(primes(floor(h*w/z)));
step = 1;
mov(1:(h*w+step):end) = 1;
% tiffWrite(mov, 'testMov.tiff', 'E:\scratch\test\')

for i = 1:z
    i
    nm = sprintf('E:\\scratch\\test\\raw\\file_%04.0f.tiff', i);
	imwrite(mov(:,:,i), nm);
end


%% Run binning with debug settings:
doBinningDuringAcquisition

%% Read and display results

movBinned = [];

ls = dir('E:\scratch\test\binned\*.mat');
[~, order] = sort([ls.datenum]);
ls = ls(order);

for i = 1:numel(ls)
    dat = load(['E:\scratch\test\binned\', ls(i).name]);
    movBinned = cat(3, movBinned, dat.imgOutBuffer);
end

for i = 1:size(movBinned, 3)
    i
    nm = sprintf('E:\\scratch\\test\\binnedTiff\\file_%06.0f.tiff', i);
	imwrite(movBinned(:,:,i), nm);
end

% ijPlay(movBinned)