function data = readLines(this, range )

if this.verbose
   fprintf('Reading data from lines %d to %d\n', ...
                range(1), range(end));
end

% store ysize in a local variable and change its name so that it's more
% clear what it will be used for.
nLinesPerFrame = this.ysize;

% determine how many total lines were requested
nLines = size(range,2);

frames = ceil(range ./ nLinesPerFrame);  % indices of desired frames
firstFrame = frames(1);          % index of first frame to cut
lastFrame = frames(end);         % index of last frame to cut
frameCount = lastFrame - firstFrame + 1;

% will contain data from relevant frames, in a 2d matrix
data = zeros(nLines, this.xsize, 'uint16');    

% the range may not start on line 1 or frame 1
% localStartingLine is the line number relative to the frame
localStartingLine = mod(range(1), nLinesPerFrame);
localFinishLine = mod(range(end), nLinesPerFrame);
% line 0 is meaningless, change to nLinesPerFrame if mod returned 0
if localStartingLine == 0
    localStartingLine = nLinesPerFrame;
end
if localFinishLine == 0
    localFinishLine = nLinesPerFrame;
end


% handle the first and last frame seperately
datasetName = sprintf('/ImageCh%d/%08d',this.activeChannel, firstFrame);
if firstFrame == lastFrame
    % special case: only one frame is being read from
    try 
    data = transpose(h5read( ...
               this.fullFileName, datasetName, [1, localStartingLine], ...
               [Inf, nLines]));     
    catch exception
        this.dispException(exception);
        data = 0;
        return;
    end
    % no more data needs to be read in.
    return;
end

%-------------------------------------------------------
% the rest of this function only runs when reading data from more than one
% frame. 

% read the first frame
firstFrameLines = nLinesPerFrame - localStartingLine + 1;
try
    data(1:firstFrameLines,:) = transpose(h5read( ...
           this.fullFileName, datasetName, [1, localStartingLine], ...
           [Inf, Inf])); 
catch exception
    this.dispException(exception);
    data = 0;
    return;
end

% now read the last frame
% lastFrameRange is the range in chLineData that will contain the data
% from the last frame.
lastFrameRange = [nLinesPerFrame * (frameCount - 1) - localStartingLine + 2, ...
                  nLinesPerFrame * (frameCount - 1) - localStartingLine + 1 ...
                  + localFinishLine];
datasetName = sprintf('/ImageCh%d/%08d',this.activeChannel, lastFrame);
try
    data(lastFrameRange(1):lastFrameRange(2),:) = transpose(h5read( ...
           this.fullFileName, datasetName, [1, 1], ...
           [Inf, localFinishLine]));
catch exception
    this.dispException(exception);
    data = 0;
    return;
end

% now read in the middle frames
% Using low level hdf5 functions so that the file and group don't
% have to be reopened for every iteration of the for loop.
try
    % storing gid as a local variable -- will close group at the end of
    % this function
    gid = H5G.open(this.fid, sprintf('/ImageCh%d',this.activeChannel));
catch exception
    this.dispException(exception);
    data = 0;
    return;
end

for frame_idx = 1:(frameCount - 2)
    datasetName = sprintf('%08d', frame_idx + firstFrame);
   
    % offset gives the location in data where this frame should
    % be written to.
    offset = nLinesPerFrame * (frame_idx - 1) + firstFrameLines + 1;
    
    try
        % open the dataset
        datasetID = H5D.open(gid, datasetName);
        % read from the dataset
        data(offset:offset + nLinesPerFrame - 1,:) = ...
                                transpose(H5D.read(datasetID));
        % close the dataset
        H5D.close(datasetID);
    catch exception
        this.dispException(exception);
        data = 0;
        return;
    end
end

H5G.close(gid);

return;
