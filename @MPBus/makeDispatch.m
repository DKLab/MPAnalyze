function mpdispatch = makeDispatch(this, moduleName)
%MAKEDISPATCH Summary of this function goes here
%   Detailed explanation goes here

    % check to see if an MPDispatch for this module already exists
    
    % TODO: But for now, just make a new dispatch
    mod = this.getModule(moduleName);
    mpdispatch = MPDispatch(mod);
    
end

