function status = populateModuleList( this )
%POPULATEMODULELIST Summary of this function goes here
%   Detailed explanation goes here

% open the config file and get the modules struct
try
    mods = load(this.MODULE_FILE, 'modules');
catch exception
    if strcmp(exception.identifier, 'MATLAB:load:couldNotReadFile')
        % couldn't find the config file, create a new one
        fprintf('Unable to locate the configuration file %s.\n', this.MODULE_FILE);
        disp('This file is used to locate installed modules -- all modules will need to be reinstalled.');
        modules = [];
        mods = struct('modules', modules);
        save(this.MODULE_FILE, 'modules');
    end
end
    
this.modules = mods.modules;
status = true;

end

