function status = output( this, variableName, variableValue, moduleName )
%OUTPUT Send a variable to the MPBus from a GUI
%   A GUI module can use this function to send variables to the MPBus's
%   workspace.

    % NEW: don't use the mpbus buffer anymore. Instead, just access the
    % MPWorkspace directly.
    % Or, if there isn't an MPWorkspace just push the variable to the base
    % workspace
    
    if ~exist('moduleName', 'var')
        moduleName = 'A module';
    end
    
    if this.workspaceIsBase
        assignin('base', variableName, variableValue);
        status = true;
    else
        % dont send varargout to the workspace -- this is a special variable
        % name and usually contains a handle to the GUI that returned it
        if ~strcmp(variableName, 'varargout')
            % alert user that a new variable is being grabbed from the
            % MPBus buffer
            prompt = sprintf('%s has returned the variable "%s".', ...
                              moduleName, variableName);
            default = 'Keep';
            choice = questdlg(prompt, variableName, 'Keep', 'Rename', 'Discard', default);

            
            switch choice
                case 'Keep'
                    this.workspace.push(variableName, variableValue);
                case 'Rename'
                    prompt = sprintf('Rename variable "%s"', variableName);
                    newName = inputdlg(prompt, variableName, 1, {variableName});
                    if ~isempty(newName)
                        this.workspace.push(newName{1}, variableValue);
                    end
                otherwise
            end
        end
        
        
    end
end

