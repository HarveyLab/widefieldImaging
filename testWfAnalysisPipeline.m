%% Create fake data:
h = 256;
w = 256;
mapHori = distMat(h, w, [100, 150]);
mapHori = mapHori / max(mapHori(:)) * range(frame.past.barPosition_deg(frame.past.barDirection_deg==0));
mapHori = mapHori + min(frame.past.barPosition_deg(frame.past.barDirection_deg==0));

mapVerti = distMat(h, w, [100, 75]);
mapVerti = mapVerti / max(mapVerti(:)) * range(frame.past.barPosition_deg(frame.past.barDirection_deg==90));
mapVerti = mapVerti + min(frame.past.barPosition_deg(frame.past.barDirection_deg==90));

%%
for f = 1:numel(frame.past.frameId)
    f
    posHere = frame.past.barPosition_deg(f);
    
    switch frame.past.barDirection_deg(f)
        case 0
            imgHere = mapHori > (posHere-1) & mapHori < (posHere+1);
        case 90
            imgHere = mapVerti > (posHere-1) & mapVerti < (posHere+1);
        case 180
            imgHere = -mapHori > (posHere-1) & -mapHori < (posHere+1);
        case 270
            imgHere = -mapVerti > (posHere-1) & -mapVerti < (posHere+1);
    end
    
    imgHere = imgaussfilt(double(imgHere), 4);
    
    fname = sprintf('E:\\scratch\\intrinsicTest2\\mov\\pipelineTestData_%04.0f.tiff', f);
    imwrite(mat2gray(imgHere), fname)
end

%% Do binning
doBinningDuringAcquisition('E:\scratch\intrinsicTest2\mov')
