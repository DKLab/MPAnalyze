function status = output( this, variableName, variableValue )
%OUTPUT Send a variable to the MPBus from a GUI
%   A GUI module can use this function to send variables to the MPBus's
%   buffer.

    % uses pushBuffer to prepare the variable to get put on the
    % MPWorkspace.
    % Or, if there isn't an MPWorkspace just push the variable to the base
    % workspace
    if this.workspaceIsBase
        assignin('base', variableName, variableValue);
        status = true;
    else
        status = this.pushBuffer(variableName, variableValue);
    end
end

