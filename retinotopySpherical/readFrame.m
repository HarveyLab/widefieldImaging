function img = readFrame(iFrame, movFolder, lst, isPreprocessed, nBinTemp)
% img = readFrame(iFrame, movFolder, lst, isPreprocessed) - Read frame,
% either from tiff file, or from a pre-processed

if nargin < 5
    nBinTemp = 1;
end

persistent dat map

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
        fprintf('Could not find frame %d. End of movie?\n', iFrame);
        img = [];
        return
    end
else
%     if mod(iFrame, 100)==1
%         % Create file that indicates what the current frame is, for
%         % prefetching:
%         [fid, err] = fopen('T:\retinoMemmap2.bin', 'w');
%         fwrite(fid, iFrame, 'double');
%         fclose(fid);
%     end
    
    if iFrame <= numel(lst)
        fileNameHere = fullfile(movFolder, lst(iFrame).name);
        try
            img = double(imread(fileNameHere));
        catch err
            switch err.identifier
                case 'MATLAB:imagesci:imread:fileDoesNotExist'
                    fileNameHere = '';
                otherwise
                    warning('Error while reading file. Entering debug mode.');
                    keyboard
            end
        end
    else
        fileNameHere = '';
    end
    
    if strcmp(fileNameHere, '')
        fprintf('Could not find frame %d. End of movie?\n', iFrame);
        img = [];
    end
end