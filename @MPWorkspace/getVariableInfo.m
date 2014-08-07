function [variableInfo, status] = getVariableInfo(this, variableName)
%GETVARIABLEINFO Summary of this function goes here
%   Detailed explanation goes here

    variableInfo = [];      % default ouput (on failure)

    if isempty(this.variableList)
        % no variables to get, just return
        status = false;
        return;
    end
    variableIndex = find(strcmp(variableName, {this.variableList.name}), 1);
    
    variableInfo = this.variableList(variableIndex);
    
    status = true;
end

