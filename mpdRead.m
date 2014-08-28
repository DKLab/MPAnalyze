function mpContent = mpdRead(fname,readType,chNum,readRange,opened,dataType)
% program to read data data from (*.MPD)
% by Jonathan Driscoll, based on programs 
% by Pablo Blinder and Phil Tsai
% Revised again by Philbert Tsai on 1/22/14 - added frame read range
%
% input:
%   fname: filename, '' or <blank> opens a file select dialog
%   chNum: channel, or channel range (i.e., 1:4), or <blank> for all
%   readType: 'header' - only header data is returned
%             'frames' - data is returned as frame data (3d matrix), with an optional data range
%             'lines' - data is returned as line data (2d matrix), with an optional data range
%             'default' - the standard read method (for analog data, etc.)
%   readRange is number of lines (readType 'lines') or number of frames (readType 'frames')
%
% examples:
%   d = mpdRead('filename')       % works like mp2mat
%   d = mpdRead                   % allows user to selct filename
%   d = mpdRead('','header')      % returns only the header info
%   d = mpdRead('filename','frames',1,[32:35])  % read frames 32:35 of ch1 of filename
%   d = mpdRead('filename','lines',1,1:100)  % read first 100 lines ch1 of filename
%   d = mpdRead('filename','default',3)      % reads in channel 3 analog data
%
% if opened is set to true, the program will read the control assigned in the base space
% instead of re-opening another activeX connection
%
% v 0.1 - initial version working version

%% parse user inputs - set filename, readType, and readRange, and display results to screen

verbose = false;               % display text while loading

if ~exist('chNum','var')       % did the user request a certain channel, or just use default?
    chNum = 1:4;
end

if max(chNum) > 4
    error 'requested channel higher that channel 4'
end

if ~exist('opened','var') || isempty(opened)
    opened = false;
else
    switch lower(opened),
        case {'open','opened','isopen','isopened','true','t','yes',1,true}
            opened = true;
        otherwise
            opened = false;
    end%switch
end

dataTypeAnalog = 'int16';
if ~exist('dataType','var') || isempty(dataType)
    dataType = 'uint16';
end


% check if a filename was given
if ~exist('fname','var') || strcmp(fname,'')
    % open gui to select a file
    [fname,fdir] = uigetfile('*.mpd','open MpScan file (*.mpd)');
    if fname == 0
        error 'no file selected ...'
    end
    fname = [fdir fname]      % append for full filename
end

if ~exist('readType','var')   % did the user request a certain read type, or just use default?
    readType = 'default';
end

if ~exist('readRange','var')  % did the user request a certain read range, or just use default?
    readRange = 0; 
end

% display information to user before extracting ...
if verbose
    disp(['   filename: ' fname])
    disp(['   readType: ' readType])
    if readRange == 0
        disp '   readRange: (all)'
    else
        disp(['   readRange: ' num2str(readRange(1)) ':' num2str(readRange(end))])
    end
end

%% open file and read data

% evalin('base','mpfileSavedControl')

if ~opened
    %Open stream

    % check to make sure the filename is correct
    if exist(fname,'file') == 0
        error 'file does not exist ...'
    end

    fh = figure(287);
    close(fh);
    fh = figure(287);

    %fh = evalin('base', 'fh')
    
    set(fh,'visible','off');

    mpfile = actxcontrol('MPfile.Data',[0,0,500,500],fh);
    supportedMethods = invoke(mpfile,'OpenMPFile',fname);  % open file for reading

    %set(fh,'visible','on');
    
    % assign the control in the base space, so it can be re-used without being reopnened
    assignin('base','mpfileSavedControl',mpfile );
else
    % get the stream from the base space
    mpfile = evalin('base','mpfileSavedControl;');
end

% example of how to read ...
%Header.Scan_Mode = invoke(mpfile,'ReadParameter','Scan Mode');

%Read header and take further action based on header information
%try

mpContent.Header = mp2mat_readHeader(mpfile);
mpContent.num_frames = str2double(mpContent.Header.Frame_Count);
mpContent.xsize = str2double(mpContent.Header.Frame_Width);
mpContent.ysize = str2double(mpContent.Header.Frame_Height);
mpContent.mpfile = mpfile;
mpContent.error = [];

%catch
%     error 'caught error'
%     delete(mpfile)
%     close(fh)
%end

switch lower(readType)
    case {'header'}
        % do nothing - header is already loaded.
    case {'default'}
        for chIter = chNum
            chNumStr = num2str(chIter);
            if strcmp(mpContent.Header.(['Enabled' chNumStr]),'True')
                mpContent.(['Ch' chNumStr]) = mp2mat_getChannelData(mpfile,chIter,mpContent,dataType);
            end%if strcmp...
        end%for ch = chNum
    case {'frames','frame'}
        for chIter = chNum
            chNumStr = num2str(chIter);
            if strcmp(mpContent.Header.(['Enabled' chNumStr]),'True')
                numFrames = numel(readRange);
                chFrames = zeros(mpContent.ysize,mpContent.xsize,numFrames,dataType);
                for frameIter = numFrames,
                    frameNum = readRange(frameIter);
                    tempFrame = mpfile.ReadFrameData(chNum,frameNum);
                    if numel(tempFrame) == mpContent.xsize * mpContent.ysize
                        % channel contains image data
                        thisFrame = transpose(reshape(tempFrame,mpContent.xsize,mpContent.ysize)); 
                    else
                        mpContent.error = 'Not an Imaging Channel';
                        mpContent.(['Ch',chNumStr]) = tempFrame;
                        return
                    end%if numel(tempFrame) == ...
                    chFrames(:,:,frameIter) = thisFrame;
                end%for frameIter = readRange
                mpContent.(['Ch',chNumStr]) = chFrames;
            end%if strcmp...
        end%for ch = chNum
    case {'lines','line'}
       % set the full readRange (lines to get), if this was not passed in 
       if readRange ==0
           readRange = mpContent.ysize * mpContent.num_frames;
       end
   
       % default to only reading channel 1, if no channel data was passed in (or set to ch 1:4) ...
       % prevent error reading analog channel (since there is no check)
       if isequal(chNum,1:4)
           chNum = 1;
       end
       for chIter = chNum
           chNumStr = num2str(chIter);
%            try    
                mpContent.(['Ch' chNumStr]) = mp2mat_getChLineData(mpfile,chIter,mpContent,readRange,dataType);
%            catch
%                 error 'caught error'
%                 delete(mpfile)
%                 close(fh)
%            end%try-catch
       end%for ch = chNum;
end %switch lower(readType)


%close(fh)

%jd - just extract line data, with fewer checks (and no waitbar)
%---------------------------------------------------------------------------------------
function chLineData = mp2mat_getChLineData(mpfile,chNum,mpContent,linesToGet,dataType)
% read in a given number of lines from the data
% this is imaging data for speed (call does not make sense for analog data, anyway) 

% convert lines to frames and lines in frame ... 

verboseFn = false;    

nLinesPerFrame = mpContent.ysize;   % helpful to write this out explicitly 

% from previous code
frames = ceil(linesToGet ./ nLinesPerFrame);  % indices of desired frames
rows = mod(linesToGet-1,nLinesPerFrame)+1;    % indices of desired rows in that frame

firstFrame = frames(1);          % index of first frame to cut
lastFrame = frames(end);         % index of last frame to cut

if verboseFn
    disp(['* first frame ' num2str(firstFrame) ' last frame ' num2str(lastFrame)])
end

firstLineInCutFrames = rows(1);  % once the data is cut out, this is the first relevant index

% will contain data from relevant frames, in a 2d matrix
chLineData = zeros(nLinesPerFrame*(lastFrame-firstFrame+1), ...
                  mpContent.xsize, ...
                  dataType);

% loop though all the frames ... only 
for f = firstFrame:lastFrame
    
    thisFrame = mpfile.ReadFrameData(chNum,f);   % read in single frame
    verboseFn = true 
    if verboseFn
        disp([' * size of thisFrame ' mat2str(size(thisFrame))])
        disp([' * size of chLineData ' mat2str(size(chLineData))]);
        disp([' * mpContent.xsize ' num2str(mpContent.xsize)])
        disp([' * mpContent.ysize ' num2str(mpContent.ysize)])
    end

    chLineData( (f-firstFrame)*nLinesPerFrame+1: (f-firstFrame)*nLinesPerFrame+nLinesPerFrame, :) = ... 
        transpose(reshape(thisFrame,mpContent.xsize,mpContent.ysize));  % reshape and place in array
end

% data was taken in full frames, cut out only relevant lines ... 
chLineData = chLineData(firstLineInCutFrames:firstLineInCutFrames+length(linesToGet)-1,:);  


%---------------------------------------------------------------------------------------
function chData = mp2mat_getChannelData(mpfile,chNum,mpContent,dataType)

h2bar = waitbar(0,['Reading channel' num2str(chNum)]);  % setup waitbar

%read first data frame and figure out if channel contains analog or image data
tempFrame = mpfile.ReadFrameData(chNum,1);
if numel(tempFrame) == mpContent.xsize * mpContent.ysize
    % channel contains image data
   
    chData = zeros(mpContent.ysize,mpContent.xsize,mpContent.num_frames,dataType);
    chData(:,:,1) = transpose(reshape(tempFrame,mpContent.xsize,mpContent.ysize)); 
    
    for nf = 2 : mpContent.num_frames
        tempFrame = mpfile.ReadFrameData(chNum,nf);
        chData(:,:,nf) = transpose(reshape(tempFrame,mpContent.xsize,mpContent.ysize));
        waitbar(nf/mpContent.num_frames);
    end
else
    % channel contains analog data
    dataTypeAnalog = 'int16';
    np = length(tempFrame);
    chData = zeros( np *  mpContent.num_frames,1,dataTypeAnalog);
    idx = 1 : np;
    chData(idx) = tempFrame;
    for nf = 2 : mpContent.num_frames
        tempFrame = mpfile.ReadFrameData(chNum,nf)';
        idx = idx + np;
        chData(idx) = tempFrame;
    end
end

close (h2bar);

%---------------------------------------------------------------------------------------
function Header = mp2mat_readHeader(mpfile)
%Read all the header information, but do nothing with it
Header.Scan_Mode = invoke(mpfile,'ReadParameter','Scan Mode');
Header.Frame_Width = invoke(mpfile,'ReadParameter','Frame Width');
Header.Frame_Height = invoke(mpfile,'ReadParameter','Frame Height');
Header.Frame_Count = invoke(mpfile,'ReadParameter','Frame Count');
Header.X_Position = invoke(mpfile,'ReadParameter','X Position');
Header.Y_Position = invoke(mpfile,'ReadParameter','Y Position');
Header.Z_Position = invoke(mpfile,'ReadParameter','Z Position');
Header.Stack_Count = invoke(mpfile,'ReadParameter','Stack Count');
Header.Z_Interval = invoke(mpfile,'ReadParameter','z- Interval');
Header.Averaging_Count = invoke(mpfile,'ReadParameter','Averaging Count');
Header.Repeat_Count = invoke(mpfile,'ReadParameter','Repeat Count');
Header.Magnification = invoke(mpfile,'ReadParameter','Magnification');
Header.Rotation = invoke(mpfile,'ReadParameter','Rotation');
Header.X_Frame_Offset = invoke(mpfile,'ReadParameter','X Frame Offset');
Header.Y_Frame_Offset = invoke(mpfile,'ReadParameter','Y Frame Offset');
Header.Channel_Name1 = invoke(mpfile,'ReadParameter','Channel Name (1)');
Header.Channel_Name2 = invoke(mpfile,'ReadParameter','Channel Name (2)');
Header.Channel_Name3 = invoke(mpfile,'ReadParameter','Channel Name (3)');
Header.Channel_Name4 = invoke(mpfile,'ReadParameter','Channel Name (4)');
Header.Enabled1 = invoke(mpfile,'ReadParameter','Enabled (1)');
Header.Enabled2 = invoke(mpfile,'ReadParameter','Enabled (2)');
Header.Enabled3 = invoke(mpfile,'ReadParameter','Enabled (3)');
Header.Enabled4 = invoke(mpfile,'ReadParameter','Enabled (4)');
Header.Input_Range1 = invoke(mpfile,'ReadParameter','Input Range (1)');
Header.Input_Range2 = invoke(mpfile,'ReadParameter','Input Range (2)');
Header.Input_Range3 = invoke(mpfile,'ReadParameter','Input Range (3)');
Header.Input_Range4 = invoke(mpfile,'ReadParameter','Input Range (4)');
Header.Channel_Unit3 = invoke(mpfile,'ReadParameter','Channel Unit (3)');
Header.Channel_Unit4 = invoke(mpfile,'ReadParameter','Channel Unit (4)');
Header.Channel_Prefix3 = invoke(mpfile,'ReadParameter','Channel Prefix (3)');
Header.Channel_Prefix4 = invoke(mpfile,'ReadParameter','Channel Prefix (4)');
Header.Conversion_Factor3 = invoke(mpfile,'ReadParameter','Conversion Factor (3)');
Header.Conversion_Factor4 = invoke(mpfile,'ReadParameter','Conversion Factor (4)');
Header.Offset3 = invoke(mpfile,'ReadParameter','Offset (3)');
Header.Offset4 = invoke(mpfile,'ReadParameter','Offset (4)');
Header.Data_Point_Per_Frame3 = invoke(mpfile,'ReadParameter','Data Point Per Frame (3)');
Header.Data_Point_Per_Frame4 = invoke(mpfile,'ReadParameter','Data Point Per Frame (4)');
Header.Comments = invoke(mpfile,'ReadParameter','Comments');

% added read for additional parameters (pixel clock and frame rate)
Header.Pixel_Clock= invoke(mpfile,'ReadParameter','Pixel Clock');
Header.PixelClockSecs = 50e-9*str2double(Header.Pixel_Clock);     % convert from board clock (50 ns) to seconds
Header.Frame_Rate=invoke(mpfile,'ReadParameter','Frame Rate');