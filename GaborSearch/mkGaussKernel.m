function kernel = mkGaussKernel(kernelSize, sd)
%  kernel = mkGaussKernel(kernelSize,sd)
%
%   Create a Gaussian kernel using the standard Gaussian formula.
%   sd corresponds to the standard deviation sigma in pixels.

if length(kernelSize) == 1
    kernel = zeros(kernelSize,kernelSize);

    x = 1:kernelSize;
    g = exp(-0.5 * ((x - (kernelSize/2) - 0.5) ./ sd).^2); % exp(- ((x - (kernelSize/2) - 0.5) ./ sd) .^ 2)
    kernel = g'*g; %'

elseif length(kernelSize) == 2
    if length(sd) ~= 2
        error('We need 2 sd terms for this kernel')
    end

    kernel = zeros(kernelSize(1),kernelSize(2));

    x = 1:kernelSize(1);
    g1 = exp(-0.5 * ((x - (kernelSize(1)/2) - 0.5) ./ sd(1)).^2); % exp(- ((x - (kernelSize(1)/2) - 0.5) ./ sd(1)) .^ 2)

    x = 1:kernelSize(2);
    g2 = exp(-0.5 * ((x - (kernelSize(2)/2) - 0.5) ./ sd(2)).^2); % exp(- ((x - (kernelSize(2)/2) - 0.5) ./ sd(2)) .^ 2)

    kernel = g1'*g2;
end

end