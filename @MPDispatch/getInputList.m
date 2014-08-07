function [workspaceVars, signatureVars] = getInputList(this)
%GETINPUTLIST Summary of this function goes here
%   Detailed explanation goes here

    workspaceVars = { this.inputs.workspace };
    signatureVars = { this.inputs.signature };

end

