function status = call( this, mpbus )
%CALL Summary of this function goes here
%   Detailed explanation goes here

    % IMPORTANT: the function path is added to MATLAB's search paths when
    % this MPDispatch object is initially created
    
    
    
    % build the input list
    [requestedInputNames, signatureInputNames] = this.getInputList();
    [requestedOutputNames, signatureOutputNames] = this.getOutputList(); 
    % if any of the requested variable names are empty, this call is a
    % failure (return false)
    emptyCells = cellfun('isempty', requestedInputNames);
    
    if find(emptyCells, 1)
        % for now just return if any input arguments weren't defined
        % TODO: in the future, check if this argument was optional
        
    end
    
    % workspace.getVariables will return a struct with field names that
    % corespond the the variable's name, and field value coresponding to the
    % variable's value.
    inputVariables = mpbus.workspace.getVariables(requestedInputNames);
    
    % build a cell array of variable values in the order as determined by
    % the module's function signature
    inputValues = cell(length(requestedInputNames), 1);
    
    for index = 1 : length(requestedInputNames)
        inputVarName = requestedInputNames{index};
        
        if strcmp(inputVarName, 'MPBus')
            inputValues{index} = mpbus;
        elseif ~isempty(inputVarName)
            inputValues{index} = inputVariables.(requestedInputNames{index});
        else
            inputValues{index} = [];
        end
    end
    
    % determine how many output arguments there are
    nOutputs = size(signatureOutputNames, 2);
    

    [output, status] = tryFeval( this.module.functionName, inputValues, ...
                                                                nOutputs );
    
              
    % save the output as fields on the MPBus buffer where the field name
    % for each variable is the requested output name (the variable name
    % that the user specified)
    for index = 1 : length(output)
        varName = signatureOutputNames{index};
        mpbus.pushBuffer( varName, output{index} );
    end

end

function [output, status] = tryFeval( functionName, inputValues, nOutputs, ...
                               callWithInputs, callWithOutputs )

    if ~exist('callWithInputs', 'var')
        callWithInputs = true;
    end
    
    if ~exist('callWithOutputs', 'var')
        callWithOutputs = true;
    end
    
    output = {};
    
    try
        if callWithInputs && callWithOutputs
            [varargout{1:nOutputs}] = ...
                                feval( functionName, inputValues{:} );
            output = varargout;
        elseif callWithInputs && ~callWithOutputs
            feval( functionName, inputValues{:} );

        elseif ~callWithInputs && callWithOutputs
            [varargout{1:nOutputs}] = feval( functionName );
            output = varargout;
        elseif ~callWithInputs && ~callWithOutputs
             feval( functionName );
        end
        
        % no errors have occured
        status = true;
    catch exception
        switch exception.identifier
            case 'MATLAB:UndefinedFunction'
                % if this results in an undefined function error, 
                % try again with no inputs if this wasn't already tried
                % before

                if callWithInputs
                    [output, status] = tryFeval( functionName, inputValues, ...
                                        nOutputs, false, callWithOutputs );
                else
                    dispException(exception);
                    status = false;
                end
            case 'MATLAB:TooManyOutputs'
                % try without any outputs
                 [output, status] = tryFeval( functionName, inputValues, ...
                                         nOutputs, callWithInputs, false );
            otherwise
                
                dispException(exception);
                status = false;
                return;
        end
     end

end

function dispException(exception)
    exceptionMessage = getReport(exception, 'extended', 'hyperlinks', 'on');
    disp('--------------------------------------------------------');
    disp(exceptionMessage);
    disp('--------------------------------------------------------');
end
