function arcFixation(w, x, y, ppd, loc, parameters)
% define positions and angles
d1 = parameters.d1*ppd;
d2 = parameters.d2*ppd;
colorOval = parameters.colorOval;
colorCue = parameters.colorCue;
positionOfMainCircle = [x+(d2/2)-((d1-d2)/2) y-(d2/2)-((d1-d2)/2) x+(d2/2)+((d1-d2)/2) y-(d2/2)+((d1-d2)/2);
    x-(d2/2)-((d1-d2)/2) y-(d2/2)-((d1-d2)/2) x-(d2/2)+((d1-d2)/2) y-(d2/2)+((d1-d2)/2);
    x-(d2/2)-((d1-d2)/2) y+(d2/2)-((d1-d2)/2) x-(d2/2)+((d1-d2)/2) y+(d2/2)+((d1-d2)/2);
    x+(d2/2)-((d1-d2)/2) y+(d2/2)-((d1-d2)/2) x+(d2/2)+((d1-d2)/2) y+(d2/2)+((d1-d2)/2)];
startAngle = [0 270 180 90];
sizeAngle  = [90 90 90 90];

% Draw filled arcs:
for i = 1:size(startAngle, 2)
    if loc == 99 
        Screen('FillArc', w, colorOval, positionOfMainCircle(i,:), startAngle(i), sizeAngle(i));
        Screen('FillOval', w, colorOval, [x-d2/2, y-d2/2, x+d2/2, y+d2/2], d2);
    elseif loc == 0
        Screen('FillArc', w, colorOval, positionOfMainCircle(i,:), startAngle(i), sizeAngle(i));
        Screen('FillOval', w, colorCue, [x-d2/2, y-d2/2, x+d2/2, y+d2/2], d2);
    else
        if i == loc
            Screen('FillArc', w, colorCue, positionOfMainCircle(i,:), startAngle(i), sizeAngle(i));
        else
            Screen('FillArc', w, colorOval, positionOfMainCircle(i,:), startAngle(i), sizeAngle(i));
        end
    end
end
