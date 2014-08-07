function status = import( this, variableList )
%IMPORT Summary of this function goes here
%   Detailed explanation goes here

    if isempty(variableList)
        status = false;
        return;
    end
    
    % import the variables in variableList from the base workspace
    variableListLength = length(this.variableList);
    for index = 1:length(variableList)
        name = variableList{index};
        value = evalin('base', name);
        
        this.push(name, value);
    end

    status = true;
end

