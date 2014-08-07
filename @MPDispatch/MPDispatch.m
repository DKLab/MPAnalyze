classdef MPDispatch < handle
    %MPDISPATCH Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        module;
        
        inputs;
        outputs;
    end
    
    methods
        status = call(this, mpbus);
        
        [workspaceVars, signatureVars] = getInputList(this);
        [workspaceVars, signatureVars] = getOutputList(this);
        
        status = setInputByIndex(this, workspaceVar, signatureIndex);
        stauts = setOutputByIndex(this, workspaceVar, signatureIndex);
        
        
        % constructor
        function this = MPDispatch(module)
            % only the NAMES of the input and output variables are saved in
            % the dispatch. When the function actually gets called from .call()
            % then an MPBus object is passed in which contains the variable
            % values.
           
            this.module = module;
            
            % if a dispatch is being created for this module then it is
            % likely to be run soon, so add its function path to MATLAB's
            % search path
            addpath(this.module.functionPath);
            
            % build the input and output structs
            this.inputs = struct(...
                'signature', [], ...
                'workspace', [], ...
                'class', []);
            
            this.outputs = struct(...
                'signature', [], ...
                'workspace', [], ...
                'class', []);
            
            filepath = [ this.module.functionPath '\' ];
            filename = [ this.module.functionName '.m' ];
            
            % ensure that we are reading the most up to date signature
            [ signatureInputs, signatureOutputs ] = ...
                MPBus.readSignature( filepath, filename );
           
            this.module.parameters.inputs = signatureInputs;
            this.module.parameters.outputs = signatureOutputs;
            
            
            for index = 1 : length(signatureInputs)
                signatureVar = signatureInputs(index);
                this.inputs(index).signature = signatureVar{1};          
            end
            
            for index = 1 : length(signatureOutputs)
                signatureVar = signatureOutputs(index);
                this.outputs(index).signature = signatureVar{1};
            end
            
        end
    end
    
end

