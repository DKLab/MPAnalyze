function data = readAnalog( this, channel, frameRange )
%READANALOG Summary of this function goes here
%   Detailed explanation goes here

% read in the first frame of analog data
% then initialize chData (allocate memory) and read in
% all the frames in frameRange.

if ~exist('frameRange', 'var')
    frameRange = 1 : this.numFrames;
end

% initial dataset name
datasetName = sprintf('/AnalogCh%d/%08d', channel, 1);
try
    tempData = h5read(this.fullFileName, datasetName);
catch exception
    this.dispException(exception);
    data = 0;
    return;
end

frameSize = size(tempData,1);
nFrames = size(frameRange,2);

if this.verbose
    fprintf('%d frames with frame size = %d.\n', nFrames,frameSize);
end

% allocate empty data matrix
data = zeros(frameSize * nFrames,1,'int16');

% open the group
try
    gid = H5G.open(this.fid, sprintf('/AnalogCh%d',channel));
catch exception
    this.dispException(exception);
    data = 0;
    return;
end

% using low level hdf5 functions to so that the file and group don't have
% to be reopened for each iteration of the for loop.
for frame_idx = frameRange
    datasetName = sprintf('%08d', frame_idx);
    try
        % open the dataset
        datasetID = H5D.open(gid, datasetName);
        % read in the entire dataset
        data((frame_idx - 1) * frameSize + 1: frame_idx * frameSize) = ...
            H5D.read(datasetID);
        % close the dataset
        H5D.close(datasetID);
    catch exception
        % close the group
        H5G.close(gid);
        this.dispException(exception);
        data = 0;
        return;
    end
end

H5G.close(gid);

return;
