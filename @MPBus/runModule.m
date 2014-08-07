function status = runModule( this, moduleName )
% DISCONTINUED -- THIS FUNCTIONALITY IS HANDLED ENTIRELY BY MPDISPATCH.CALL
%RUNMODULE Summary of this function goes here
%   Detailed explanation goes here

% runModule will call the function associated with moduleName
% this MPBus object and busIn will be passed to the function
% busOut will contain the output.

% start off with status = false, when the mod is found status will be 
% changed to 1
status = false;

% move anything on the output bus to the input bus, then zero the output
% bus
this.busIn = this.busOut;
this.busOut = [];

% first, find the module
for mod = this.modules
   if strcmp(mod.moduleName, moduleName);
       % module was found
       % add the module path to MATLAB's searchpath
       try
            addpath(mod.functionPath);
            % call the function and pass this MPBus object as well as the
            % input bus on this MPBus object. The output will be returned
            % to the output bus.
            this.busOut = feval(mod.functionName, this, this.busIn);
       catch exception
           this.dispException(exception);
           status = false;
           return;
       end
       % no need to continue looping
       status = true;
       return;
   end
end

return;

