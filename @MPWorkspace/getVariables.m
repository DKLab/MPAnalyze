function [ variableList, status ] = getVariables( this, variableListRequest )
% GETVARIABLES Returns a struct with fields corresponding to the variables
% requested in variableRequestList
% Can be called with no arguments
%   Detailed explanation goes here

    if isempty(this.variableList)
        % no variables to get
        variableList = [];
        status = false;
        return;
    end

% return all variables if a request list wasn't provided
    if ~exist('variableListRequest', 'var')
        variableListRequest = { this.variableList.name };
    elseif isempty(variableListRequest{1})
        variableListRequest = { this.variableList.name };
    end    

    % TODO Check that this is working
    [~, exportIndices] = ismember(variableListRequest, { this.variableList.name });
    
    variableList = struct();
    for index = exportIndices
        if index > 0
            variableName = this.variableList(index).name;
            variableList.(variableName) = this.variableList(index).value;
        end
    end

    status = true;
end
