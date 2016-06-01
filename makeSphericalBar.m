function [texMat, barPos_deg] = makeSphericalBar(tex, settings, time_s)

% Define grating stimulus in altitude (spherical) space:
barPos_deg = mod(time_s*settings.barSpeed_dps, range(tex.altLimits_deg)) + tex.altLimits_deg(1);
texMat = 2*(pi/settings.barWidth_deg).*(tex.alt_deg - barPos_deg);
texMat(abs(texMat) > pi) = nan; % Setting to nan is faster than pi because cos() is slow and skips nans.
texMat = cos(texMat);

% Mask with checker:
texMat = (texMat>0) .* (tex.checkerMask*sign(cos(time_s*settings.checkerBlink_hz*2*pi))>0);

% Scale and reshape:
texMat = (texMat+1) / 2;
texMat = texMat * 255;
texMat = reshape(texMat, tex.texMatSize);

