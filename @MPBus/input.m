function [variableValue, status] = input(this, variableName)
%INPUT Summary of this function goes here
%   Detailed explanation goes here

[variableStruct, status] = this.workspace.getVariables({variableName});

variableValue = variableStruct.(variableName);

end

