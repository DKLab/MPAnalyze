function calculatorWrapper( savedCalculation, varargin )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    mpbus = varargin{1};
    
    if isa(mpbus, 'MPBus')
        % create a new field in the MPBus' scanData struct
        % calculator() will check for this first
        mpbus.scanData.savedCalculation = savedCalculation;
        
        calculator(mpbus);
    end
end

