function RIFTTag = makeRIFTtag(gaborpat, colorBG, freqRIFT, frames, ratio, isvalid)

%========== RIFT settings ======================================

% default 480hz when ('SetPropixxDlpSequenceProgram', 2);
modulation = 1 + 1 * sin(2 * pi * frames / freqRIFT);


%========== Gaussian edge parameters ==========================

% Gaussian transition width (pixels)

sigma_outer = 5;
sigma_inner = 5;

% Transparent padding around the stimulus

padding = ceil(4 * max(sigma_inner, sigma_outer));


%========== parameters =========================================

stimSize = gaborpat.size * 2;

canvasSize = stimSize + 2 * padding;

r = ones(canvasSize, canvasSize) * colorBG(1);
g = ones(canvasSize, canvasSize) * colorBG(2);
b = ones(canvasSize, canvasSize) * colorBG(3);


%========== make coordinate grid ==============================

[x, y] = meshgrid( ...
    -(canvasSize-1)/2:(canvasSize-1)/2, ...
    -(canvasSize-1)/2:(canvasSize-1)/2);


%========== make circular mask =================================

% Keep original stimulus radius

radius = (stimSize - 1) / 2 * ratio;
innerRadius = radius *1.2 / 2;

radialDist = sqrt(x.^2 + y.^2);


%========== Gaussian outer edge ================================

outerMask = 0.5 * (1 + erf( ...
    (radius - radialDist) ./ (sqrt(2) * sigma_outer)));


%========== Gaussian inner edge ================================

if isvalid == 0
    innerMask = 0.5 * (1 + erf( ...
        (radialDist - innerRadius) ./ (sqrt(2) * sigma_inner)));
    alpha =outerMask .* innerMask;%
elseif isvalid == 1
    alpha = outerMask;
else

    error('isvalid must be either 0 or 1.');

end
%========== apply alpha mask ===================================
alpha = uint8(255 * alpha);
%========== make RIFT Tag ======================================
RIFTTag = uint8(cat(3, ...
    r * modulation, ...
    g * modulation, ...
    b * modulation, ...
    alpha));
end
