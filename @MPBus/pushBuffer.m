function status = pushBuffer(this, variableName, variableValue)
%PUSHBUFFER Summary of this function goes here
%   Detailed explanation goes here

    % resolve name conflicts -- usually don't want to overwrite data on the
    % buffer
    
    if isfield(this.buffer, variableName)
        disp('name conflict');
        % TODO: get new var name
    end
    
    this.buffer.(variableName) = variableValue;
    

    status = true;

end

