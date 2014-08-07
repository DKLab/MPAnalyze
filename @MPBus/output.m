function status = output( this, variableName, variableValue )
%OUTPUT Send a variable to the MPBus from a GUI
%   A GUI module can use this function to send variables to the MPBus's
%   buffer.

    % pushBuffer already accomplishes this task. 'output' is just an easier
    % name to use/remember.
    this.pushBuffer(variableName, variableValue);
end

