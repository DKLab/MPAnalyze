function status = open(this, fullFileName )
% Opens an hdf5 file and returns a flag indicating success.
% If open() is called with no arguments then a uigetfile
% dialog box is displayed for the user to select a file.

if ~exist('fullFileName','var')
    if isempty(this.fullFileName)
        % open the uigetfile dialog box
        [filename,fileDirectory] = uigetfile('*.h5','open HDF5 file (*.h5)');
        fullFileName = [fileDirectory filename];
    else
        fullFileName = this.fullFileName;
    end
end

if ~MPBus.verifyFile(fullFileName, '.h5')
    % couldn't find correct hdf5 file
    status = false;
    return;
end

% set properties
try
    this.fid = H5F.open(fullFileName);
catch exception
    % there was a problem opening the file
    this.dispException(exception);
    status = false;
    return;
end

this.fullFileName = fullFileName;

% read in the Header info. By default this info is held in the /Config
% group.
this.readHeader();

% check what image channels are present
this.channelList = this.getImageChannels();

% the file has changed, update any open GUIs by dispatching refresh
this.dispatchRefresh();

status = true;
return;