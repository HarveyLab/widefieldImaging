function tex = prepareSphericalBarTex(screen, settings, direction_deg)
% Pre-computes data for a spherically corrected bar.

tex = struct;
tex.texMatSize = round([screen.height, screen.width]/settings.pixelReductionFactor);

% Get pixel coordinates:
[y, z] = meshgrid(linspace(-0.5, 0.5, tex.texMatSize(2))*screen.width, ...
    linspace(0.5, -0.5, tex.texMatSize(1))*screen.height);
tex.yz = cat(1, y(:)'-settings.screenOri_xyPix(1), ...
    z(:)'+settings.screenOri_xyPix(2));
tex.x = settings.minDistEyeToScreen_mm*screen.pixPerMm;

% Rotate monitor coordinates by oriRad radians:
tex.yz = [cosd(-direction_deg), -sind(-direction_deg); ...
    sind(-direction_deg), cosd(-direction_deg)] * tex.yz;

% Calculate altitude and azimuth for monitor x and y coords:
[tex.azi_deg, tex.alt_deg, ~] = cart2sph(tex.x, tex.yz(1, :), tex.yz(2, :));
tex.azi_deg = rad2deg(tex.azi_deg);
tex.alt_deg = rad2deg(tex.alt_deg);
tex.checkerMask = cos((pi/settings.checkerWidth_deg).*tex.azi_deg);
tex.altLimits_deg = [min(tex.alt_deg), max(tex.alt_deg)];