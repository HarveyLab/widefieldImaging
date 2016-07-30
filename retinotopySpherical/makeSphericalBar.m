function [texMat, barPos_deg] = makeSphericalBar(tex, settings, time_s, ...
    barDirection_deg)

% Define grating stimulus in altitude (spherical) space:
barPos_deg = mod(time_s*settings.barSpeed_dps, range(tex.altLimits_deg)) + tex.altLimits_deg(1);
texMat = (pi/settings.barWidth_deg).*(tex.alt_deg - barPos_deg);
texMat(abs(texMat) > pi) = nan; % Setting to nan is faster than pi because cos() is slow and skips nans.
texMat = cos(texMat);

% Mask with checker:
texMat = (texMat>0) .* (tex.checkerMask*sign(cos(time_s*settings.checkerBlink_hz*2*pi))>0) ...
    + ~(texMat>0)*0.5;

% Scale and reshape:
texMat = texMat * 255;
texMat = reshape(texMat, tex.texMatSize);

% Correct barPosition sign: When the bar is starting at the bottom or left,
% the barPosition should be increasing (the default). When it starts at the
% top or right, it should be decreasing:
if barDirection_deg==90 || barDirection_deg==180
    barPos_deg = -barPos_deg;
end
        