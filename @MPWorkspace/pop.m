function variableValue = pop(this, variableName)
%POP Summary of this function goes here
%   Detailed explanation goes here

    variableValue = [];     % default return value (on failure)
    
    variableIndex = find(strcmp(variableName, {this.variableList.name}), 1);

    
    if ~isempty(variableIndex)
        variableValue = this.variableList(variableIndex).value;
        
        % the variable also needs to be removed from variableList
        this.variableList(variableIndex) = [];
    end

end

