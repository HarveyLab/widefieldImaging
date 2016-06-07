%% Get file list:
p = 'D:\Data\Matthias\SkullcapMouse1';
lst = dir(fullfile(p, '*.tiff'));
nFiles = numel(lst);

%% Extract numbers from file name and sort accordingly:
fileNameNumber = zeros(nFiles, 1);
for i = 1:nFiles
    str = regexp(lst(i).name, '(?<=_)()\d{4,5}(?=\.)', 'match', 'once');
    fileNameNumber(i) = str2double(str);
end
nFramesInSyncStruct = numel(frame.past.frameId);

[~, order] = sort(fileNameNumber);
lst = lst(order);
lst = lst(1:nFramesInSyncStruct);
nFiles = numel(lst);

%% Do tiff to bin conversion:

binFileName = [p, '_binMovie_correctOrder.bin'];
fid = fopen(binFileName, 'A');

t = TIFFStack(fullfile(p, lst(1).name));
frameSize = size(t);
nCol = frameSize(2);
dataType = getDataClass(t);

totalMovSizeBytes = prod([frameSize, nFiles]) * 16 / 8;
[~, mem] = memory;
maxReasonableArrayBytes = mem.PhysicalMemory.Total/3;
maxNColsPerStrip = max(floor(maxReasonableArrayBytes/(totalMovSizeBytes/nCol)), 1);
stripIndex = ceil((1:nCol)/maxNColsPerStrip);
nStrips = max(stripIndex);

tTotal = tic;
for iStrip = 1:nStrips
    % Pre-allocate current column:
    currentCol = zeros(frameSize(1), sum(stripIndex==iStrip), nFiles, dataType);
    
    % Read current column from all files:
    for iFile = 1:nFiles
        t = imread(fullfile(p, lst(iFile).name));
        currentCol(:, :, iFile) = t(:, stripIndex==iStrip);
    end
    
    % Permute such that frame index changes fastest:
    currentCol = permute(currentCol, [3, 1, 2]);
    
    tWrite = tic;
    fwrite(fid, currentCol, dataType);
    fprintf('Wrote column %d: %1.3f\n', iStrip, toc(tWrite));
end

fprintf('Done saving binary movie. Total time per frame: %1.3f\n', toc(tTotal)/nFiles);
fclose(fid);