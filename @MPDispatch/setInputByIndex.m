function  status = setInputByIndex(this, workspaceVar, signatureIndex)
%SETINPUT Summary of this function goes here
%   Detailed explanation goes here

    this.inputs(signatureIndex).workspace = workspaceVar;
    
    status = true;
end

