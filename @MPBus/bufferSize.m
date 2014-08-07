function nVariables = bufferSize( this )
%BUFFERSIZE Summary of this function goes here
%   Detailed explanation goes here

    nVariables = 0;
    if ~isempty(this.buffer)
        varList = fieldnames(this.buffer);
        if ~isempty(varList)
            nVariables = size(varList, 2);
        end
    end
end

