function MEGTrigger(triggerCode)
if triggerCode == 0
    clear device
    device_found = 0;
    device = [];
    ports = serialportlist("available");
    for p = 1:length(ports)
        try
            temp_dev = serialport(ports(p), 9600, "Timeout", 1);
            temp_dev.flush();

            write(temp_dev, "_c1", "char");
            query_return = read(temp_dev, 5, "char");
            display(query_return);

            if ~isempty(query_return) && query_return == "_xid0"
                device = temp_dev;
                device_found = 1;
                fprintf('XID Device found on port: %s\n', ports(p));
                break;
            else
                clear temp_dev;
            end

        catch
            continue;
        end
    end

    if ~device_found
        error(['CRITICAL ERROR: XID Device not found. ' ...
               'For formal data collection, the trigger device is required. ' ...
               'Check connection or set is_debug=1.']);

    setPulseDuration(device, 30);

    else
        warning('DEBUG MODE: experiment will continue without XID triggers.');
        device = [];
    end

else
    write(device, sprintf("mh%c%c", triggerCode, 0), "char");
    %% I haven't decided number of pulses yet '
    % perhaps 1 for start trial, 2 for start stimulus, 3 for right answer, 4 for wrong answer, etc.
    %
    %
end