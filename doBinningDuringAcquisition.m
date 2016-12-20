function doBinningDuringAcquisition(tiffFolder)

% For debugging:
if nargin<1
    tiffFolder = 'E:\scratch\test\raw';
end

% How to run this in a separate instance:
% cmd = sprintf('matlab -nodesktop -nojvm -nosplash -minimize -singleCompThread -r "run(''%s'')" &', ...
%     which('doBinningDuringAcquisition'));
% system(cmd);
    
% Settings:
nBinTemp = 2;
nBinSpat = 2;
    
% Create folder for binned data:
% outFolder = fullfile(tiffFolder, 'binned');
if nargin<1 % Debug
    outFolder = 'E:\scratch\test\binned';
else
%     outFolder = ['D' tiffFolder(2:end)];
    outFolder = ['E:\scratch\intrinsicTest2\binned'];
end
mkdir(outFolder);

% Load first frame to get basic info:
tiffFileMask = fullfile(tiffFolder, '*.tiff');
ls = dir(tiffFileMask);
while isempty(ls)
    disp('Waiting for first frame...')
    pause(1)
    ls = dir(tiffFileMask);
end
img = imread(fullfile(tiffFolder, ls(1).name));
[h, w] = size(img);    
[hBin, wBin] = size(binSpatial(img, nBinSpat));
imgNamePrefix = regexp(ls(1).name, '.+_', 'match', 'once');
[~, ~, imgFileExt] = fileparts(ls(1).name);
nImgFileExt = numel(imgFileExt);
nBytes = ls(1).bytes;

% Prepare loop variables
rtifcArgStruct = struct('index', 1, 'pixelregion', struct([]), 'info', [], ...
    'filename', '');
nOutBuf = 1000;
imgOutBuffer = zeros(hBin, wBin, nOutBuf);
filesToDelete = cell(1, nOutBuf*nBinTemp);
ticLastFileLoaded = tic; 
ticLoopStart = tic;
nextFrameId = 0;
nFilesAvailable = numel(ls);
isExitLoop = false;
isHeadless = ~usejava('desktop');

% Keep looking for new files an process:
while ~isExitLoop
    timeFullLoop = toc(ticLastFileLoaded);
    timeIo = 0;
    
    % Wait for new files:
    if nFilesAvailable < (2*nBinTemp+100)
        disp('Waiting for new frames...')
        if toc(ticLastFileLoaded) > 180
            break
        else
            pause(0.1)
            ls = dir(tiffFileMask);
            nFilesAvailable = numel(ls);
            continue
        end
    else
       ticLastFileLoaded = tic; 
    end
    
    % Load number of frames to be averaged:
    imgOut = zeros(h, w);
    for i = 1:nBinTemp
        nextFrameId = nextFrameId+1;
        nFilesAvailable = nFilesAvailable - 1;
        imgFileNameHere = sprintf('%s%04.0f.tiff', imgNamePrefix, nextFrameId);
        imgFullNameHere = fullfile(tiffFolder, imgFileNameHere);
        
        % Load next image, exit if it fails:
        try
            ticLoad = tic;
            rtifcArgStruct.filename = imgFullNameHere;
            imgOut = imgOut + double(rtifc(rtifcArgStruct));
            filesToDelete{modMax(nextFrameId, nOutBuf*nBinTemp)} = imgFullNameHere;
            timeIo = timeIo + toc(ticLoad);
            fprintf('Loaded file %s\n', imgFileNameHere);
        catch err
            switch err.identifier
                case {'MATLAB:imagesci:imread:fileDoesNotExist', ...
                        'MATLAB:imagesci:tiffmexutils:libtiffError'}
                    fprintf('File %s does not exist. Exiting.\n', imgFileNameHere);
                    isExitLoop = true;
                    break
                otherwise
                    rethrow(err)
            end
        end
        
        % Motion correct:
        % [This will not be fast enough.]
    end
    
    if isExitLoop
        break
    end
        
    % Average spatially:
    imgOut = binSpatial(imgOut, nBinSpat);
    
    % Save as .mat file:
    % (Name corresponds to the LAST file in the temporal bin.)
    iOutBuf = modMax(nextFrameId/nBinTemp, nOutBuf);
    imgOutBuffer(:,:, iOutBuf) = imgOut;
    
    if iOutBuf==nOutBuf
        ticSave = tic;
        save(fullfile(outFolder, imgFileNameHere(1:(end-nImgFileExt))), ...
            'imgOutBuffer', '-v7.3')
        timeIo = timeIo + toc(ticSave);
        fprintf('Saved file %s\n', imgFileNameHere);
        
%         delete(filesToDelete{:})
%         filesToDelete = {};
%         fprintf('Deleted files up to %s\n', imgFileNameHere);
        
        if isHeadless
            % In headless mode, printing to console is slow, so only do it
            % once per chunk:
            fprintf('Loop time: %1.2f ms (%1.2f ms proc, %1.2f ms I/O).\n\n', ...
            timeFullLoop*1e3, (timeFullLoop-timeIo)*1e3, timeIo*1e3);
        end
    end
    
    % Display timing:
%     if ~isHeadless
%         fprintf('Loop time: %1.2f ms (%1.2f ms proc, %1.2f ms I/O).\n\n', ...
%             timeFullLoop*1e3, (timeFullLoop-timeIo)*1e3, timeIo*1e3);
%     end
end

% Save last chunk if it was not evenly dividible by nOutBuf:
if iOutBuf~=nOutBuf
    imgOutBuffer(:,:, (iOutBuf+1):end) = []; %#ok<NASGU>
    save(fullfile(outFolder, imgFileNameHere(1:(end-nImgFileExt))), ...
        'imgOutBuffer', '-v6')
    fprintf('Saved last file %s\n', imgFileNameHere);
    
%     delete(filesToDelete{1:(iOutBuf*nBinTemp)})
%     fprintf('Deleted last batch of files: %s\n', imgFileNameHere);
end

fprintf('Total time: %1.3f ms per frame (%1.1f FPS, %1.1f MB/s).\n', ...
    toc(ticLoopStart)/nextFrameId*1e3, ...
    1000/(toc(ticLoopStart)/nextFrameId*1e3), ...
    nBytes*nextFrameId*1e-6/toc(ticLoopStart))

% Code archive:
% frameNumber = str2double(regexp(ls(1).name, '\d{4,6}(?=.tif)', 'match', 'once'));

% Quit if we're in headless mode:
if isHeadless
%     quit
end
end

function img = binSpatial(img, n)
% img = binSpatial(img, n) averages n elements along the first and second
% dimension of img.

% We first bin along the rows, then along the columnns. If the number
% doesn't divide evenly, we fill up the array with nans and use nanmean.
[h, w, z] = size(img);
hFull = ceil(h/n)*n;
wFull = ceil(w/n)*n;
img((h+1):hFull, :) = nan;
img(:, (w+1):wFull) = nan;

% Average along first dimension:
img = reshape(img, n, hFull/n, wFull, z);
img = squeeze(nansum(img, 1));

% Permute and average along second dimension:
img = permute(img, [2, 1, 3]);
img = reshape(img, n, wFull/n, hFull/n, z);
img = squeeze(nansum(img, 1));
img = ipermute(img, [2, 1, 3]);
end

function fprint(varargin)
end

function b = modMax(a, m)
    % Like mod, but return m instead of zero when dividion is even:
    b = mod(a, m);
    b = b + (b==0)*m;
end