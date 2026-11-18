function circle = makeCircle(diameter, thickness)
%MAKECIRCLE Create a black circular ring with a transparent background.

if ~isnumeric(diameter) || ~isscalar(diameter) || ~isfinite(diameter) || ...
        diameter < 3 || diameter ~= floor(diameter)
    error('makeCircle:InvalidDiameter', ...
        'Diameter must be an integer greater than or equal to 3.');
end

if ~isnumeric(thickness) || ~isscalar(thickness) || ~isfinite(thickness) || ...
        thickness < 1 || thickness ~= floor(thickness) || ...
        thickness > floor((diameter - 1) / 2)
    error('makeCircle:InvalidThickness', ...
        'Thickness must be a positive integer smaller than the radius.');
end

center = (diameter + 1) / 2;
[x, y] = meshgrid(1:diameter, 1:diameter);
radius = (diameter - 1) / 2;
distance = sqrt((x - center).^2 + (y - center).^2);
ringMask = distance <= radius & distance > radius - thickness;

circle = zeros(diameter, diameter, 4, 'uint8');
circle(:, :, 4) = uint8(ringMask) * 255;
end