function initProPixx(isopen)
    isConnected = Datapixx('isReady');
    if ~isConnected
        Datapixx('Open');
    end
    if isopen == 1 %open
    Datapixx('SetPropixxDlpSequenceProgram', 2);        %Set Propixx to 480Hz refresh (also known as Quad4x)
    Datapixx('RegWrRd');     %Push command to device register
    end                           

    if isopen == 0 %close
    Datapixx('SetPropixxDlpSequenceProgram', 0);         %Revert to standard 120Hz refresh rate
    Datapixx('RegWrRd');
    Datapixx('Close');
    end