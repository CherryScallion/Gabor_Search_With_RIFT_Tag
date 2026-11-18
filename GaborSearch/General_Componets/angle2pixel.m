function sizePx = angle2pixel(angleDeg, screenWidthPx, params)
% Convert a visual angle in degrees to a size in pixels.

%% Load viewing geometry when not supplied
if nargin < 3
    params = defineParameters();
end
viewDist = params.distance;
screenWidth = params.screenWidth;

%% Convert to pixels and round to the nearest integer
sizePx = round(tan(angleDeg * pi / 360) * 2 * viewDist ...
    * screenWidthPx / screenWidth);
end
