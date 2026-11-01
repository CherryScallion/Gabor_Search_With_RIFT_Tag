function RIFTTag = makeGaborRIFT(gaborpat, colorBG, freqRIFT, frames, ratio, isvalid)

%========== RIFT settings ======================================

% default 480hz when ('SetPropixxDlpSequenceProgram', 2);

modulation = 1 + 1.0 * sin(2 * pi * frames / freqRIFT); % modulation

%========== parameters ==================================
size = gaborpat.size * 2 ;
r = ones(size, size) * colorBG(1);
g = ones(size, size) * colorBG(2);
b = ones(size, size) * colorBG(3);

%========== make evelope ======================================

[x,y] = meshgrid(-(size-1)/2:(size-1)/2, -(size-1)/2:(size-1)/2);

%========== make circular mask ==========================

radius = (size - 1) / 2 * ratio;
mask = (x.^2 + y.^2) <= radius^2;
mask2 = (x.^2 + y.^2) >= (radius/2)^2;

%========== make RIFTTag ======================================
RIFTTag = uint8(cat(3,r * modulation, g *modulation, b * modulation)); 
if isvalid == 0
    alpha = uint8((mask & mask2) * 255);
end
if isvalid == 1
    alpha = uint8((mask) * 255);
end
RIFTTag = cat(3, RIFTTag, alpha);

%gabor = uint8(cat(3,r,g,b));
%imwrite(gabor, sprintf('gabor.tif'), 'writemode', 'overwrite');


