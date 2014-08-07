classdef MPWorkspace < handle
    %MPWORKSPACE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        variableList;   % a struct with the following fields:
                            % name
                            % value         
                            % type
                            % image
        
        activeIndex;
    end
    
    methods
        status = import(this, variableList);
        status = export(this, variableListRequest);
        
        status = push(this, variableName, variableValue);
        variableValue = pop(this, variableName);
        
        [variableInfo, status] = getVariableInfo(this, variableName);
        [variableList, status] = getVariables(this, variableListRequest);
        
    end
    
    
    methods(Static = true)
        function [ newName, status ] = resolveNameConflict(conflictingName)
            
            prompt = sprintf(...
                'The variable "%s" already exists, please choose a new name:', ...
                conflictingName);
            title = 'Variable Already Exists';
            nLines = 1;
            default = { conflictingName };
            
            response = inputdlg(prompt,title,nLines,default);
            if ~isempty(response)
                newName = response{1};
            else
                newName = '';
            end
            % if the user's response is a valid variable name and isn't
            % just the same conflicting name then this name resolution is a
            % success.
            if isvarname(newName) && ~strcmp(newName, conflictingName)
                status = true;
            else
                status = false;
            end
                
        end
    end
    
    
end

