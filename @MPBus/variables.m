function [ variableNameList, status ] = variables( this )
%VARIABLES List all the variables on the MPBus workspace
%   Detailed explanation goes here

[variableList, success] = this.workspace.getVariables();

if success
    variableNameList = fieldnames(variableList);
else
    variableNameList = {};
end

status = success;
