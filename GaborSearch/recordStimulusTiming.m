function recordStimulusTiming(filename, subNo, practice, run, block, trial, ...
    onsetTime, offsetTime, duration, frameCount, responseDetected)
% Append one trial's stimulus presentation timing to a CSV file.

    if any(~isfinite([subNo, practice, run, block, trial, onsetTime, ...
            offsetTime, duration, frameCount])) || duration < 0 || frameCount < 1
        error('recordStimulusTiming:InvalidTiming', ...
            'Trial timing values must be finite, with nonnegative duration and at least one frame.');
    end

    fileInfo = dir(filename);
    writeHeader = isempty(fileInfo) || fileInfo(1).bytes == 0;
    [fid, message] = fopen(filename, 'a');
    if fid == -1
        error('recordStimulusTiming:FileOpenFailed', ...
            'Cannot open stimulus timing file "%s": %s', filename, message);
    end
    fileCleanup = onCleanup(@() fclose(fid));

    if writeHeader
        fprintf(fid, ['subNo,practice,run,block,trial,onsetGetSecs,' ...
            'offsetGetSecs,durationSeconds,displayedFrames,responseDetected\n']);
    end
    fprintf(fid, '%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,%.15g,%d\n', ...
        subNo, practice, run, block, trial, onsetTime, offsetTime, ...
        duration, frameCount, logical(responseDetected));
end
