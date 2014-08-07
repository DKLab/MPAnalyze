function [inputs, outputs] = readSignature(filepath, filename)
    inputs = {};
    outputs = {};
    
    if MPBus.verifyFile([filepath filename], '.m')
        % read in the first line of the function to get the signature
        try
            fid = fopen([filepath filename]);    
        catch
            % silently return if file couldn't be opened
            return;
        end
        
        % determine which line the main function signature is on
        callsString = mlintmex('-calls', [filepath filename]);
        
        % the output from calls will indicate what line the main function
        % signature is on with 'M0 #' where # is the line number.
        signatureLine = regexp(callsString, 'M0 \d*', 'match');
        
        % remove the 'M0 ' and now we're left with the line number
        signatureLine = str2double(strrep(signatureLine, 'M0 ', ''));
        
        % make sure signatureLine is a number
        if isnan(signatureLine)
            % silently return
            return;
        end
        
        fileLines = textscan(fid, '%s','delimiter', '\n');     
        signature = fileLines{1}{signatureLine};
        
        % now parse the signature to determine the inputs and outputs to
        % this module
        try
            startInputs = regexp(signature, '(') + 1;
            endInputs = regexp(signature, ')') - 1;

            inputsList = signature(startInputs:endInputs);
        catch
            % this may not be the correct function signature, return
            % silently
            return;
        end
        
        % check if the outputs are contained in brackets or not
        startOutputs = regexp(signature, '[');
        endOutputs = regexp(signature, ']');
        equalSignIndex = regexp(signature, '=');
        
        if isempty(startOutputs)
            % only 1 output
            outputsList = signature(1 : equalSignIndex - 1);
            
            % remove 'function ' from the list so that only 1 word is
            % returned (the name of the output argument)
            outputsList = strrep(outputsList, 'function ', '');
            
        else
            outputsList = signature(startOutputs + 1 : endOutputs - 1);
        end
    
        % now we have a string of inputs that are guarenteed to be
        % delineated by commas, and a string of outputs that may or may not
        % be delineated by commas (could just be seperated by spaces)
        inputs = strtrim(strsplit(inputsList, ','));
        
        % turn commas into whitespace then split the string
        outputsList = strtrim(strrep(outputsList, ',', ' ')); 
        outputs = strtrim(strsplit(outputsList));
    end

end
