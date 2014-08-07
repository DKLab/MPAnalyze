function data = readHeader( this, groupName )
%READHEADER Summary of this function goes here
%   Detailed explanation goes here

if ~exist('groupName', 'var')
    % default group to get header info is /Config
    groupName = '/Config';
    setHeaderProperties = true;
else
    setHeaderProperties = false;
end

% open the group
try
    gid = H5G.open(this.fid, groupName);
catch exception
    % either the group doesn't exist or the fid isn't valid
    this.dispException(exception);
    data = 0;
    return;
end

% loop through the attributes in the group and get their values
info = H5O.get_info(gid);

for i = 0:info.num_attrs - 1
    attributeID = H5A.open_by_idx(gid, groupName, ...
                                'H5_INDEX_NAME', 'H5_ITER_INC', i); 
    % Define a new filed in data with the same name as the current ...
    % attribute. Then set its value.
    data.(H5A.get_name(attributeID)) = H5A.read(attributeID);
    H5A.close(attributeID);
end

% if this was the /Config group, then set the properties in
% this MPBus object from the attributes now stored in data.
if setHeaderProperties
    this.header = data;
    this.numFrames = data.FrameLimit;
    this.xsize = data.FrameWidthVisible;
    this.ysize = data.FrameHeightFull;
end

% close the group
H5G.close(gid);

% read and store scan data
this.scanData = this.readScanData();
return;

