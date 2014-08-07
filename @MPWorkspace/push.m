function status = push(this, variableName, variableValue)
%PUSH Summary of this function goes here
%   Detailed explanation goes here
    global MPBusRoot;   % defined by MPBus as the present working directory
                        % when the MPBus is created.
    
    % check for name conflicts -- variables must have unique names
    for existingVariable = this.variableList;
        if strcmp(variableName, existingVariable.name)
            % name conflict
            [newVariableName, success] = ...
                            MPWorkspace.resolveNameConflict(variableName);
           
            if success
                % call push again with the new variable name
                % (calling again to make sure the new name doesn't conflict
                % with a different variable on the workspace)
                status = this.push(newVariableName, variableValue);
                return;
            else
                % check to see if the user just wants to replace the
                % existing variable with the new variable of the same name
                prompt = sprintf(...
                    'Replace the existing variable "%s" with the new one?', ...
                    variableName);
                title = 'Replace Existing Variable';
                default = 'Yes';
                answer = questdlg(prompt,title,default);
                
                switch answer
                    case 'Yes'
                        % remove the existing variable first, then continue
                        % this push()
                        this.pop(variableName);
                    otherwise
                        % cancel this push()
                        status = false;
                        return;
                end
            end
        
        end
    end
                        
    pushIndex = length(this.variableList) + 1;
    
    this.variableList(pushIndex).name = variableName;
    this.variableList(pushIndex).value = variableValue;
    
    variableType = class(variableValue);
    this.variableList(pushIndex).type = variableType;
    
    % determine which icon to use based on result from class()
    
    switch variableType
        case 'cell'
            imageFile = 'variable_cell.png';
        case 'logical'
            imageFile = 'variable_logic.png';     
        case 'char'
            imageFile = 'variable_string.png';
        case 'struct'
            imageFile = 'variable_struct.png';

        otherwise
            if isnumeric(variableValue)
                imageFile = 'variable_matrix.png';
            else
                imageFile = 'variable_object.png';
            end
    end
            
    
    imageSource = ['file:/' MPBusRoot 'Images\' imageFile];

    this.variableList(pushIndex).image = imageSource;
    
    status = true;

end
