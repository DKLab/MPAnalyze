function channels_vector = getImageChannels( this )
%GETIMAGECHANNELS Summary of this function goes here
%   Detailed explanation goes here

channels_vector = [];

% open the root group
try
    this.gid = H5G.open(this.fid, '/');
catch exception
    this.dispException(exception);
    return;
end

[~, ~, channels_vector] = H5L.iterate(this.gid, 'H5_INDEX_NAME', ...
                         'H5_ITER_NATIVE',0, @getChannel, channels_vector);

% for now, just set the active channel to the first channel in the channels
% vector
this.activeChannel = channels_vector(1);
return;

function [status,dataOut] = getChannel(~, groupName, channels_vector)   
% this function is called by H5L.iterate for every link in the root group.
% parse each link name and see if it's an image channel

% parse groupName, look for groups that start with Image
if ~isempty(regexp(groupName, 'Image', 'once'))
   channels_vector(end + 1) = str2double(regexp(groupName, '\d*', 'match'));
end

% set values for next iteration
status = 0;
dataOut = channels_vector;
return;