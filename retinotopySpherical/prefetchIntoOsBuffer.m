function prefetchIntoOsBuffer
% This function simply loads the files specified in the text file at PATH.
% This accelerates loading of the same files in other Matlab instances
% because the files are somehow buffered by the operating system.

memmapPath = 'T:\retinoMemmap2.bin';
% imgBasePath = 'C:\scratch\MM109_161217_retino\mov\acA1920-155um__21840556__20161217_161842721_';
imgBasePath = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\widefield\KB019\KB019_161219_retino\mov\acA1920-155um__21840556__20161219_183655966_';
nFetchAhead = 200;

maxFrameLoaded = 0;
lastIFrame = 0;
fps = 0;
while true
    fid = fopen(memmapPath, 'r');
    iFrame = fread(fid, 'double');
    fclose(fid);
    
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
            for i = 1:nFetchAhead
                maxFrameLoaded = iFrame + i;
                filename = sprintf('%s%04.0f.tiff', imgBasePath, maxFrameLoaded);
                im = imread(filename);
                fprintf('Loaded %s (%1.1f fps)\n', filename, fps)
            end
            tIo = toc(ticIo);
            fps = nFetchAhead/tIo;
        end
    catch err
        warning(err.message)
    end
end
    
    