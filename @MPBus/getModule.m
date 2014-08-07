function  module = getModule( this, moduleName )
%GETMODULE Summary of this function goes here
%   Detailed explanation goes here

    if isempty(this.modules)
        this.populateModuleList();
    end
    
    % search for the index in modules using the moduleName
    moduleIndex = 0;
    for index = 1 : length(this.modules)
        if strcmp(this.modules(index).moduleName, moduleName)
            moduleIndex = index;
            break;
        end
    end
    
    module = this.modules(moduleIndex);
end

