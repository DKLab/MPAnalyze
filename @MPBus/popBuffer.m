function [variableName, variableValue, newBufferSize, status] = popBuffer(this)
%POPBUFFER remove the last variable in the buffer and return its name and
%value
%   Detailed explanation goes here
    nameList = fieldnames(this.buffer);
    if ~isempty(nameList)
        variableNameCell = nameList(end);
        variableName = variableNameCell{1};

        variableValue = this.buffer.(variableName);

        % then remove this element
        this.buffer = rmfield(this.buffer, variableName);

        newBufferSize = size(nameList, 1) - 1;
        status = true;
    else
        variableName = '';
        variableValue = [];
        newBufferSize = 0;
        status = false;
    end
end


