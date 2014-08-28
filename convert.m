function [ h5Filename, success ] = convert( mpdFilename )
%CONVERT Summary of this function goes here
%   Detailed explanation goes here

    OVERWRITE = false;
    success = false;
    h5Filename = '';
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% This section of code was taken from MpMatSuite.m %%%%%%%%%%%%%%%%
    [thisDir, thisFileName, ~] = fileparts(mpdFilename);
    h5Filename = fullfile(thisDir,[thisFileName,'.h5']);
    
    
    if exist(h5Filename,'file') && ~OVERWRITE,
        success = false;
        return;
    end
    
    mpContent = mpdRead(mpdFilename,'header');
    header = mpContent.Header;
    h5ConfigStruct = [];
    h5ConfigStruct.FrameHeightFull = str2double(header.Frame_Height);
    h5ConfigStruct.FrameHeightRaster = str2double(header.Frame_Height);
    h5ConfigStruct.FrameLimit = str2double(header.Frame_Count);
    h5ConfigStruct.FrameRate = str2double(header.Frame_Rate);
    h5ConfigStruct.FrameWidthVisible = str2double(header.Frame_Width);
    h5ConfigStruct.InputScaleCh1_V = str2num(header.Input_Range1(2:end-1));
    h5ConfigStruct.InputScaleCh2_V = str2num(header.Input_Range2(2:end-1));
    h5ConfigStruct.InputScaleCh3_V = str2num(header.Input_Range3(2:end-1));
    h5ConfigStruct.InputScaleCh4_V = str2num(header.Input_Range4(2:end-1));
    h5ConfigStruct.RotationAngle = str2double(header.Rotation);
    h5ConfigStruct.ScannerDelayX = str2double(header.X_Frame_Offset);
    h5ConfigStruct.ScannerDelayY = str2double(header.Y_Frame_Offset);
    h5ConfigStruct.StackStepSize = str2double(header.Z_Interval);
    h5ConfigStruct.StagePosX = str2double(header.X_Position);
    h5ConfigStruct.StagePosY = str2double(header.Y_Position);
    h5ConfigStruct.StagePosZ =str2double( header.Z_Position);
    h5ConfigStruct.ZoomValue = str2num(header.Magnification(2:end));
    chNumToRead = [];
    
    
    if strcmpi(header.Enabled1,'True'), chNumToRead = [chNumToRead ; 1]; end
    if strcmpi(header.Enabled2,'True'), chNumToRead = [chNumToRead ; 2]; end
    if strcmpi(header.Enabled3,'True'), chNumToRead = [chNumToRead ; 3]; end
    if strcmpi(header.Enabled4,'True'), chNumToRead = [chNumToRead ; 4]; end
    
    PixelClockSecs = header.PixelClockSecs;
    
    
    if ~isempty(PixelClockSecs)
        if ischar(PixelClockSecs)
            PixelClockSecs = str2double(PixelClockSecs);
        end
        
        h5ConfigStruct.PixelRate_Hz = 1/PixelClockSecs;
    else
        h5ConfigStruct.PixelRate_Hz = 0;
    end
    
    scanMode = header.Scan_Mode;
    switch lower(scanMode)
        case {'movie'}
            h5ConfigStruct.ScanMode = 'Movie';
            h5ConfigStruct.FrameFractionActive = 0.8;
        case {'arbscan','arbitraryscan','arbitrary scan'};
            h5ConfigStruct.ScanMode = 'ArbScan';
            h5ConfigStruct.FrameFractionActive = 1.0;
        case {'stack'}
            h5ConfigStruct.ScanMode = 'StackStage';
            h5ConfigStruct.FrameFractionActive = 0.8;
        case {'line','linescan'}
            h5ConfigStruct.ScanMode = 'LineScan';
            h5ConfigStruct.FrameFractionActive = 0.8;
        otherwise
            h5ConfigStruct.ScanMode = 'Movie';
            h5ConfigStruct.FrameFractionActive = 0.8;
            %config.ScanMode = 'StackPiezo';
            %config.ScanMode = 'InterlaceScan';
    end
    
    fieldValue = 0;
    for chIter = 1:4,
        fieldName = ['Enabled',num2str(chIter)];
        if strcmpi(header.(fieldName),'True'),
            fieldValue = fieldValue * 10 + chIter;
        end
    end
    
    h5ConfigStruct.MainBoardChEnabled = fieldValue;
    h5ConfigStruct.MainBoardChUseForImaging = 1234; 
    h5ConfigStruct.AuxAnaRate = 0.0;
    h5ConfigStruct.InterlaceLineScans = 0.0;
    h5ConfigStruct.LaserPower = 0.0;
    h5ConfigStruct.LaserPowerDoubleEveryZ = 0.0;
    h5ConfigStruct.LaserRefPos = 0.0;
    h5ConfigStruct.LaserRefPower = 0.0;
    h5ConfigStruct.MirrorVoltageOffsetX_V = 0.0;
    h5ConfigStruct.MirrorVoltageOffsetY_V = 0.0;
    h5ConfigStruct.PhotonCountingChEnabled = 0.0;
    h5ConfigStruct.ScannerAccArbscan = 0.0;
    h5ConfigStruct.ScannerAccRaster = 0.0;
    h5ConfigStruct.ScannerAmpX_V = 0.0;
    
    if isempty(h5ConfigStruct.FrameRate),
        switch lower(header.Scan_Mode)
            case {'movie','stack','line','linescan'}
                h5ConfigStruct.FrameRate = 0.8 * h5ConfigStruct.PixelRate_Hz ...
                    / (h5ConfigStruct.FrameHeightRaster * h5ConfigStruct.FrameWidthVisible);
            case {'arbscan','arbitraryscan','arbitrary_scan'}
                h5ConfigStruct.FrameRate = 1.0 * h5ConfigStruct.PixelRate_Hz ...
                    / (h5ConfigStruct.FrameHeightRaster * h5ConfigStruct.FrameWidthVisible);
        end
    end
    
    
    
    %if this is an arbscan file, ask user to locate the
    %pathGUI .mat file that hold the path information
    pathFilePresent = false;
    if isequal(h5ConfigStruct.ScanMode,'ArbScan')
        
        titleString = ['Find the pathGUI .mat file associated with : ',thisFileName];
        [arbScanFileName, arbScanPathName] = uigetfile('*.mat', titleString);
        fullArbScanFileName = fullfile(arbScanPathName,arbScanFileName);
        
        if ~isequal(arbScanFileName,0) && exist(fullArbScanFileName,'file')
            pathFilePresent = true;
        end
    end
    
    
    MpWriteHDF5Config(h5ConfigStruct,h5Filename);
    MpWriteHDF5Config(mpContent.Header,h5Filename,'mpdHeader');
    if pathFilePresent == true
        
        load(fullArbScanFileName,'scanData');
        MpWriteHDF5Config(scanData,h5Filename,'ArbScanPath',{'CM_MPSCOPE'});
    end
    
    fileattrib(h5Filename,'+w');
    fid = H5F.open(h5Filename,'H5F_ACC_RDWR','H5P_DEFAULT');
    
    %Run mpdRead one time with "opened" input variable set to false.
    %This creates a new activeX window variable on the base space
    chEnabledString = num2str(round(h5ConfigStruct.MainBoardChEnabled));
    junkData = mpdRead(mpdFilename,'frames',str2num(chEnabledString(1)),1,false,'int16');
    frameSize = [h5ConfigStruct.FrameHeightRaster,h5ConfigStruct.FrameWidthVisible];
    frameSizeForH5 = [h5ConfigStruct.FrameWidthVisible,h5ConfigStruct.FrameHeightRaster]; %transposed for hdf5 indexing
    msg = msgbox('Beginning MPD to HDF5 Conversion...                      .','Opening File to Convert.');
    msg_g1 = get(msg);
    msg_a1 = msg_g1.CurrentAxes;
    msg_g2 = get(msg_a1);
    msg_c2 = msg_g2.Children;
    %msg_g3 = get(msg_c2);
    
    
    for chIter = 1:4,
        %update the status messagebox title
        if ishandle(msg),
            titleString = ['Converting Ch ',num2str(chIter)];
            set(msg,'Name',titleString);
        end%if ishandle(msg)
        if ~isempty(strfind(chEnabledString,num2str(chIter)));
            checkFrame = mpdRead(mpdFilename,'frames',chIter,1,true,'int16');
            if strcmpi(checkFrame.error,'Not an Imaging Channel'),
                %Analog Data Channel
                plist = 'H5P_DEFAULT';
                gid = H5G.create(fid,['AnalogCh',num2str(chIter)],plist,plist,plist);
                for frameIter = 1:h5ConfigStruct.FrameLimit;
                    mpdData = mpdRead(mpdFilename,'frames',chIter,frameIter,true,'int16');
                    frameData = mpdData.(['Ch',num2str(chIter)]);
                    frameName = ['/AnalogCh',num2str(chIter),'/',num2str(frameIter,'%08d')];
                    h5create(h5Filename,frameName,numel(frameData),'DataType','int16');%,'ChunkSize',[5 5]);
                    h5write(h5Filename,frameName,frameData');
                    %update the status messagebox
                    if ishandle(msg),
                        msgString = ['Analog Frame ',num2str(frameIter),' of ',num2str(h5ConfigStruct.FrameLimit)];
                        set(msg_c2,'String',msgString);
                        pause(0.001);
                    end%if ishandle(msg);
                end%for frameIter...
                H5G.close(gid);
            else%if strcmpi(checkFrame.error,'Not an Imaging Channel'),
                %Imaging Data Channel
                plist = 'H5P_DEFAULT';
                gid = H5G.create(fid,['ImageCh',num2str(chIter)],plist,plist,plist);
                for frameIter = 1:h5ConfigStruct.FrameLimit;
                    mpdData = mpdRead(mpdFilename,'frames',chIter,frameIter,true,'int16');
                    if isempty(mpdData.error),
                        frameData = mpdData.(['Ch',num2str(chIter)]);
                        frameName = ['/ImageCh',num2str(chIter),'/',num2str(frameIter,'%08d')];
                        h5create(h5Filename,frameName,frameSizeForH5,'DataType','int16');%,'ChunkSize',[5 5]);
                        h5write(h5Filename,frameName,frameData'); %Transposed to match standard C# indexing notation.
                        %update the status messagebox
                        if ishandle(msg),
                            msgString = ['Frame ',num2str(frameIter),' of ',num2str(h5ConfigStruct.FrameLimit)];
                            set(msg_c2,'String',msgString);
                            pause(0.001);
                        end%if ishandle(msg);
                    end%if isempty(mpdData.error)
                end%for frameIter...
                H5G.close(gid);
            end%if strcmpi(checkFrame.error,'Not an Imaging Channel'),
        end% if ~isempty
    end%for chIter ...
    if ishandle(msg),
        close(msg);
    end%if ishandle(msg);
    H5F.close(fid);
    fileattrib(h5Filename,'-w');
    
    success = true;
                
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% End of code from MpMatSuite.m %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


end

function [success] = MpWriteHDF5Config(configStruct,h5FileName,configGroupName,ignoreAttributeFields)
%[success] = MpWriteHDF5Config(configStruct,h5FileName,[configGroupName],[ignoreAttributeFields])
%
%Creates a new hdf5 file with the filename given by h5FileName
%and writes the fields in configStruct as attributes in the Config group
%If file already exists, it will rename the existing file as:
%(OriginalName)_backup_(datestring)
%Providing an optional configGroupName (default = 'Config') will append if
%file exists
%
%Created by Philbert Tsai  01/22/2014

% h5FileName = 'newData.h5';
% configStruct = config;
    success = false;

    newFileFlag = 0;
    if ~exist('configGroupName','var');
        configGroupName = '/Config';
        newFileFlag = 1;
    end%if isempty(configGroupName),

    if ~exist('ignoreAttributeFields','var');
        ignoreAttributeFields = {};
    end%if isempty(configGroupName),

    configFieldNameList = fieldnames(configStruct);
    numAttributes = numel(configFieldNameList);


    %Check for (and add) .h5 extension
    [pathStr,fileName,ext] = fileparts(h5FileName);
    if isempty(ext),
        h5FileName = [h5FileName,'.h5'];
    end%if isempty(ext),

    %If file already exists, do rename existing file

    switch newFileFlag
        case 0,
            fid = H5F.open(h5FileName, 'H5F_ACC_RDWR','H5P_DEFAULT');
        case 1,
            if exist(h5FileName,'file'),
                backupFileName = fullfile(pathStr,[fileName,'_backup_',datestr(now,'mmddyy_hhMMSS'),'.h5']);
                [moveSuccess,msg,msgID] = movefile(h5FileName,backupFileName);
            end% if exist(h5FileName,'file'),
            fid = H5F.create(h5FileName);
    end%switch newFileFlag

    fileattrib(h5FileName,'+w');
    plist = 'H5P_DEFAULT';
    gid = H5G.create(fid,configGroupName,plist,plist,plist);
    for attributeIter = 1:numAttributes,
        attributeName = configFieldNameList{attributeIter};
        attributeValue = configStruct.(attributeName);
        %---
        if ismember(attributeName,ignoreAttributeFields)
            continue %jump to next attributeIter loop - ignore this attribute
        end%if ismember(attributeName,ignoreAttributeFields)
        %---
        if isstruct(attributeValue),
            %Structure Entry
            numStructEntries = numel(attributeValue);
            entryName = ['num',upper(attributeName(1)),attributeName(2:end)];
            h5writeatt(h5FileName,['/',configGroupName],entryName,numStructEntries);
            for structIter = 1:numStructEntries,
                thisStruct = attributeValue(structIter);
                fieldNameList = fieldnames(thisStruct);
                numFields = numel(fieldNameList);
                for fieldIter = 1:numFields,
                    thisField = thisStruct.(fieldNameList{fieldIter});
                    entryName = [attributeName,num2str(structIter,'%08d'),'.',fieldNameList{fieldIter}];
                    h5writeatt(h5FileName,['/',configGroupName],entryName,thisField);
                end%for fieldIter
            end%for structIter
        else%if isstruct(attributeValue),
            %Non-structure entry
            if isnumeric(attributeValue) && length(attributeValue)>10,
                %store as data rather than attribute
                dataType = class(attributeValue);
                dataName = ['/',configGroupName,'/',attributeName];
                h5create(h5FileName,dataName,size(attributeValue),'DataType',dataType);%,'ChunkSize',[5 5]);
                h5write(h5FileName,dataName,attributeValue);
            else%isnumeric(attributeValue) && length(attributeValue)>10,
                h5writeatt(h5FileName,['/',configGroupName],attributeName,attributeValue);
            end%isnumeric(attributeValue) && length(attributeValue)>10,
        end%if-else isstruct(attributeValue),
    end%for attributeIter = 1:numAttributes,
    H5G.close(gid);


    H5F.close(fid);
    success = true;
end
