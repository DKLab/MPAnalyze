function [populatedParameterStruct, status] = gui(~, parameterStruct, labelStruct)
%GUI Generates a GUI to allow users to set parameters for a module
%   Takes a paramater struct which has a field for every parameter that the
%   user needs to set for the module. The value of each field is the
%   default value that the user will see in the GUI.
%
%   Once the user fills out the GUI and clicks OK the module will continue
%   executing with the newly populated parameter struct.
%
%   The first output is the populated parameter struct
%   The second output is status -- true or false indicating whether the
%   user hit OK or canceled/exited.

    populatedParameterStruct = parameterStruct;
    status = false;


    parameterNames = fieldnames( parameterStruct );

    if isempty( parameterNames )
        return;
    end

    nParameters = length( parameterNames );
    prompt = cell(nParameters, 4);
    listItems = struct();
    
    for index = 1:nParameters
        name = parameterNames{index};
        value = parameterStruct.(name);
        
        % check if there is a label associated with this parameter
        if isfield(labelStruct, name)
            label = labelStruct.(name);
        else
            label = sprintf('%s:', name);
        end
        
        prompt(index, :) = {label, name, '', ''};
       
        if iscell(value)
            defaults.(name) = 1;
        else
            defaults.(name) = value;
        end
        
        [thisFormat, success] = getFormat(value);
        if success && ~isempty(thisFormat.type)    
            formats(index) = thisFormat;
            % if this format is for a list control (user selects from
            % multiple items) then save a list of those items so that the
            % item chosen can be determined from the user's answer
            if ~isempty(thisFormat.items)
                listItems.(name) = thisFormat.items;
            end
        else
            formats(index) = [];
        end
    end
    
    
    % reshape formats
    divisibleByTwo = ~mod(nParameters, 2);
    divisibleByThree = ~mod(nParameters, 3);
    
    if divisibleByThree
        formats = reshape(formats, 3, []); 
    elseif divisibleByTwo
        formats = reshape(formats, 2, []);
    end

    formats = transpose(formats);
    
   [answer, canceled] = inputsdlg(prompt, 'Parameters', formats, defaults);

    if canceled
        status = false;
    else
        % answers from list boxes will just be the index of the item
        % selected. Use the listItems struct to determine the value of the
        % selected answer (not just the index)
        
        listItemsFields = fieldnames(listItems);
        
        % (listItemsFields must be transposed for this for loop to work
        % correctly)
        for parameter = listItemsFields'
            % replace index with the actual value
            itemIndex = answer.(parameter{1});
            thisList = listItems.(parameter{1});
            answer.(parameter{1}) = thisList{itemIndex};
        end
        
        populatedParameterStruct = answer;
        status = true;
    end

end


function [formatStruct, status] = getFormat(parameterValue)
    pClass = class(parameterValue);
    if iscell(parameterValue)
        pClass = 'cell';
    end

    formatStruct = struct('type', [], ...
                          'format', [], ...
                          'limits', [], ...
                          'items', []);
    type = [];
    format = [];
    limits = [];
    items = [];

    switch pClass
        case 'double'
            type = 'edit';
            format = 'float';
            limits = [-inf inf];
        case 'char'
            type = 'edit';
            format = 'text';
            limits = [0 1];
        case 'logical'
            type = 'check';
            format = 'logical';
            limits = [0 1];
        case 'cell'
            type = 'list';
            items = parameterValue;
            limits = [1 1];
        case 'struct'
           
        otherwise
            status = false;
            return;
    end
    
    formatStruct.type = type;
    formatStruct.format = format;
    formatStruct.limits = limits;
    formatStruct.items = items;
    status = true;
end