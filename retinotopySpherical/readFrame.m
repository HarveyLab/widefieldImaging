function img = readFrame(iFrame, movFolder, lst, isPreprocessed, nBinTemp)
% img = readFrame(iFrame, movFolder, lst, isPreprocessed) - Read frame,
% either from tiff file, or from a pre-processed 

if nargin < 5
    nBinTemp = 1;
end

persistent dat

if isPreprocessed
    if ~isfield(dat, 'lst') || ~isequal(dat.lst, lst)
        dat.lastFrameInFile_preBin = cellfun(@(c) str2double(...
            regexp(c, '(?<=_)\d+(?=\.mat)', 'match', 'once')), ...
            {lst.name});
        assert(issorted(dat.lastFrameInFile_preBin), 'file names are not sorted properly!');
    end
    
    iFileHere = find((dat.lastFrameInFile_preBin/nBinTemp)>=iFrame, 1, 'first');
    
    if isempty(iFileHere)
        fprintf('Could not find frame %d. End of movie?\n');
        img = [];
        return
    end
    
    if ~isfield(dat, 'iLoadedFile') || dat.iLoadedFile ~= iFileHere
        % Load file
        dat.iLoadedFile = iFileHere;
        dat.mov = load(fullfile(movFolder, lst(iFileHere).name));
        dat.mov = dat.mov.(char(fieldnames(dat.mov)));
        dat.size = size(dat.mov);
        
        if iFileHere==1
            dat.firstFrameInFile_postBin = 1;
        else
            dat.firstFrameInFile_postBin = (dat.lastFrameInFile_preBin(iFileHere-1)/nBinTemp)+1;
        end
        fprintf('Loaded file %s.\n',  lst(iFileHere).name)
    end
    
    % Retrieve correct frame from file:
    iInFile = iFrame - dat.firstFrameInFile_postBin + 1;
    
    if iInFile <= dat.size(3)
        img = dat.mov(:,:,iInFile);
    else
        fprintf('Could not find frame %d. End of movie?\n');
        img = [];
        return
    end
else
    error('to do: make this compatible with tiff files')
%     iFile = sum(dat.frame.past.isCamTriggerFrame(1:iFrame));
%     fileNameHere = sprintf('%s%04.0f.tiff', movNamePrefix, iFile);
%     fileNameHere = fullfile(movFolder, fileNameHere);
%     
%     if exist(fileNameHere, 'file')
%         try
%             %                 imgHere = double(imread(fileNameHere));
%         catch
%             break
%         end
%     else
%         imgHere = nan; %#ok<NASGU> % Suppresses warning about non-existing variable in parfor loop.
%         warning('Could not find file %s.\n This should not happen during online processing, but can happen at the end of an acquisition if the last frame was saved incompletely. Check what''s going on!', ...
%             fileNameHere);
%         break
%     end
%     
%     img = imread(fullfile(movFolder, lst(iFrame).name));
end