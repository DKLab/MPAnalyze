function [workspaceVars, signatureVars] = getOutputList(this)
%GETINPUTLIST Summary of this function goes here
%   Detailed explanation goes here

    workspaceVars = { this.outputs.workspace };
    signatureVars = { this.outputs.signature };

end
