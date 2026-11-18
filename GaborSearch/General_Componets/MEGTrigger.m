function MEGTrigger(device, triggerCode)
    write(device, sprintf("mh%c%c", triggerCode, 0), "char");
    %% I haven't decided number of pulses yet '
    % perhaps 1 for start trial, 2 for start stimulus, 3 for right answer, 4 for wrong answer, etc.
    %
    %
end