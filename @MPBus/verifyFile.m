 function verified = verifyFile(fullFileName, extension)
    % verify that the file exists and has the correct extension
    if ~ischar(fullFileName)
        verified = false;
        return;
    end

    if exist(fullFileName,'file') == 2
        % exist returns 2 for files (as opposed to 7 for folders)
        [~,~,ext] = fileparts(fullFileName);
        if ~strcmp(ext, extension)    
            verified = false;
        else
            verified = true;
        end
    else
        verified = false;
    end
 end 
        