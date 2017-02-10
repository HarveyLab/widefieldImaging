function prefetchIntoOsBuffer(acqName, start, step)
% This function simply loads the files specified in the text file at PATH.
% This accelerates loading of the same files in other Matlab instances
% because the files are somehow buffered by the operating system.

if nargin < 3
    start = 1;
    step = 1;
end

pInfo = ['T:\' acqName '.txt'];


nFetchAhead = 200;

maxFrameLoaded = 0;
lastIFrame = 0;
fps = 0;
while true
    fid = fopen(pInfo, 'rt');
    currentFilePath = fread(fid, 'int8=>char')';
    fclose(fid);
    [numStr, basePath] = strtok(currentFilePath(end:-1:1), '_');
    imgBasePath = basePath(end:-1:1);
    iFrame = str2double(strtok(numStr(end:-1:1), '.'));
    
    % Reset counters when iFrame jumps back:
    if iFrame < lastIFrame
        maxFrameLoaded = 0;
    end
    lastIFrame = iFrame;
    
    try
        if maxFrameLoaded > (iFrame+50)
            pause(0.2);
        else
            ticIo = tic;
            for i = start:step:nFetchAhead
                maxFrameLoaded = iFrame + i;
                filename = sprintf('%s%04.0f.tiff', imgBasePath, maxFrameLoaded);
                im = imread(filename);
            end
            tIo = toc(ticIo);
            fps = nFetchAhead/tIo;
            fprintf('Loaded %s (%1.1f fps)\n', filename, fps)
        end
    catch err
        warning(err.message)
    end
end
    
    