function status = registerModule( this, moduleName, functionPath, functionName, parameters )
%REGISTERMODULE Summary of this function goes here
%   Detailed explanation goes here

% adds a new element to the modules struct.
% moduleName is just an identifier that runModule() will use to find the
% appropriate path and function name of the module.

% check if this moduleName already exists
for mod = this.modules
    if strcmp(mod.moduleName, moduleName)
        % module name exists
        qstring1 = sprintf('The module "%s" already exists and is registered to "%s".\n\n', ...
                            moduleName, mod.functionName);
        qstring2 = sprintf('Replace with "%s" on the path "%s"?', ...
                            functionName, functionPath);
        answer = questdlg([qstring1 qstring2],'Module Already Exists','Yes');
        
        switch answer
            case 'Yes'
                if this.verbose
                    
                end
            otherwise
                status = false;
                return;
        end
    end
end

% if this function is within the MPAnalyze directory then turn the path
% into a local path relative to the MPAnalyze directory.
searchPattern = sprintf('\\%s\\', this.ROOT_FOLDER);
patternIndex = regexp(functionPath, searchPattern);
if patternIndex > 0
    sliceIndex = patternIndex + length(this.ROOT_FOLDER) + 1;
    
    localFunctionPath = functionPath(sliceIndex : end);
else
    localFunctionPath = functionPath;
end
fprintf('function name: %s\n function path: %s\n', functionName, localFunctionPath);

% register this module
index = size(this.modules,2) + 1;
this.modules(index).moduleName = moduleName;
this.modules(index).functionName = functionName;
this.modules(index).functionPath = localFunctionPath;
this.modules(index).parameters = parameters;



% save to the config file
modules = this.modules; %#ok<NASGU>
save(this.MODULE_FILE, 'modules', '-append');
status = true;
return;
