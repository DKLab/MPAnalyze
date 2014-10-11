function channels_vector = getImageChannels( this )
%GETIMAGECHANNELS Summary of this function goes here
%   Detailed explanation goes here


channel_struct.image = [];
channel_struct.analog = [];

% open the root group
try
    this.gid = H5G.open(this.fid, '/');
catch exception
    this.dispException(exception);
    return;
end

[~, ~, channel_struct] = H5L.iterate(this.gid, 'H5_INDEX_NAME', ...
                         'H5_ITER_NATIVE',0, @getChannel, channel_struct);

% for now, just set the active channel to the first channel in the channels
% vector
this.activeChannel = channel_struct.image(1);

this.channelList= channel_struct.image;
this.analogChannelList = channel_struct.analog;

% this may be redundant (already saved image and anolog channels directly to
% the MpBus)
channels_vector = channel_struct.image;

return;

function [status,dataOut] = getChannel(~, groupName, channel_struct)   
% this function is called by H5L.iterate for every link in the root group.
% parse each link name and see if it's an image channel

% parse groupName, look for groups that start with Image
if ~isempty(regexp(groupName, 'Image', 'once'))
   channel_struct.image(end + 1) = str2double(regexp(groupName, '\d*', 'match'));
end

% do the same for analog channels (just save the analog channel list
% directly to the MpBus)
if ~isempty(regexp(groupName, 'Analog', 'once'))
   channel_struct.analog(end + 1) = str2double(regexp(groupName, '\d*', 'match'));
end


% set values for next iteration
status = 0;
dataOut = channel_struct;
return;