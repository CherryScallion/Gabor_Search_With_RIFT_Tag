function gabor = makeGabor(gaborpat, orientation, color1, color2, colorBG)

%========== gabor parameters ==================================
size = gaborpat.size;
sd = gaborpat.sd;
spFreq = gaborpat.spFreq;
phase = gaborpat.phase;
contrast = gaborpat.contrast;

orient = (orientation/180)*pi; % Orientation is measured from vertical, as in the cue.

%========== make the Gaussian kernel ==========================
kernel = mkGaussKernel(size, sd);
kernel = kernel./max(kernel(:));

%========== make sinpat =======================================
[x,y] = meshgrid(-(size-1)/2:(size-1)/2, -(size-1)/2:(size-1)/2);

u = cos(orient)*x + sin(orient)*y;
img = cos(2*pi*(spFreq/size*u) + phase);

%========== make color modulation =============================
meanColor = (color1 + color2) / 2;
colorDiff = (color1 - color2) / 2; 

r = colorBG(1) + kernel .* ((meanColor(1)-colorBG(1)) + contrast*colorDiff(1).*img); % r = contrast*(r.*kernel + colorBG(1)*(1-kernel))
g = colorBG(2) + kernel .* ((meanColor(2)-colorBG(2)) + contrast*colorDiff(2).*img); % g = contrast*(g.*kernel + colorBG(2)*(1-kernel))
b = colorBG(3) + kernel .* ((meanColor(3)-colorBG(3)) + contrast*colorDiff(3).*img); % b = contrast*(b.*kernel + colorBG(3)*(1-kernel))

%========== make envelope ======================================
rawr = sqrt(x.^2 + y.^2);
out = find(rawr>size/2);
r(out) = colorBG(1);
g(out) = colorBG(2);
b(out) = colorBG(3);

%========== make circular mask ==========================
radius = (size - 1) / 2;
mask = (x.^2 + y.^2) <= radius^2;

%========== make gabor with alpha channel ===============
gabor = uint8(cat(3, r, g, b));

alpha = uint8(mask * 255);

gabor = cat(3, gabor, alpha);

%========== make gabor ======================================
%gabor = uint8(cat(3,r,g,b));
%imwrite(gabor, sprintf('gabor.tif'), 'writemode', 'overwrite');

end