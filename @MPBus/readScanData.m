function data = readScanData( this )
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

% scan data is always in the /ArbScanPath group
groupName = '/ArbScanPath';

% get all attributes from /ArbScanPath
try
    gid = H5G.open(this.fid, groupName);
    info = H5O.get_info(gid);
catch exception
    this.dispException(exception);
    data = 0;
    return;
end

% not all attributes in /ArbScanPath are scan coords,
% so put that attributes that have 'scanCoords' in its name
% into a scanCoords struct.
data.scanCoords = struct('scanShape','', ...
                    'startPoint',[0,0], ... 
                    'endPoint',[0,0], ... 
                    'nLines',0, ... 
                    'orientation',0, ...
                    'name','');
                
for i = 0:info.num_attrs - 1
    try
        attributeID = H5A.open_by_idx(gid, groupName, ...
                            'H5_INDEX_NAME', 'H5_ITER_INC', i); 
        % Define a new filed in data with the same name as the current ...
        % attribute.
        attributeName = H5A.get_name(attributeID);
    catch exception
        % the group is still open (close it)
        H5G.close(gid);
        this.dispException(exception);
        data = 0;
        return;
    end
    % check if this attribute is scanCoords by finding the 
    % pattern 'scanCoords' in the attribute name.
    % If strfind returns an empty vector then scanCoords wasn't found
    if size(strfind(attributeName,'scanCoords')) == 0
        try
            data.(attributeName) = H5A.read(attributeID);
        catch exception
            H5A.close(attributeID);
            this.dispException(exception);
            data = 0;
            return;
        end
    else
        % this attribute is a scanCoords attribute
        % add it to the scanCoords struct.
        
        % parse the attribute name
        periodLocation = strfind(attributeName,'.');
        sc_idx = str2double(attributeName(periodLocation - 8 : ...
                                            periodLocation - 1));
        sc_field = attributeName(periodLocation + 1 : end);
        
        % then create a new field in scanCoords and read in the attribute
        % value
        try
            data.scanCoords(sc_idx).(sc_field) = ...
                transpose(H5A.read(attributeID));
        catch exception
            H5A.close(attributeID);
            this.dispException(exception);
            data = 0;
            return;
        end
    end
    H5A.close(attributeID);
end % end for loop

% now load all the datasets in /ArbScanPath
try
    [~, ~, data] = H5L.iterate(gid, 'H5_INDEX_NAME', ...
                            'H5_ITER_NATIVE',0, @getDataset, data); 
catch exception
    this.dispException(exception);
    data = 0;
    return;
end

return;

% getDataset is called by H5L.iterate
function [status,dataOut] = getDataset(gid, datasetName, data)
% get a struct from this dataset and add it to data
try
    datasetID = H5D.open(gid, datasetName);
    data.(datasetName) = H5D.read(datasetID);
    H5D.close(datasetID);
catch exception
    this.dispException(exception);
    % indicate to H5L.iterate that there was an error and that
    % it should stop iterating
    status = -1;
    try
        % attempt to close the dataset
        H5D.close(datasetID);
    catch
        % no need to display another error message
    end
    return;
end


% set status to 0 to tell H5L.iterate to continue iterating.
status = 0;
% dataOut will be the dataIn for the next iteration
dataOut = data;
return;


