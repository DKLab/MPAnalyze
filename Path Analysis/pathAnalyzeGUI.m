 function varargout = pathAnalyzeGUI(varargin)
% GUI to analyse the data scanned with pathGUI

% change log:
% 2009-12-14: fixed 'rename' function
% 2009-08-07: correct scaling
% 2009-08-07: newest version
% 2009-05-18: now loads header in handles.dataMpd.Header
% 2009-05-07: now only loading part of the data at a time, for longer datasets
% 2009-04-02: added code to cut out sub-objects in intensity and look
% 2009-03-19: usable code, does diameters, draws paths, etc.
% 2011-02-19: now work to queue for offline analysis
% DATA ANALYSIS magic number 2^20 These lines were added to allow the program to stop
% before crashing CELINE MATEO 20111116
% CELINE MATEO implement to get the name of the open in the command window
% CELINE MATEO change to get the mirror voltage = to 2.5 V for Rig 2 this
% is found in the PATH GUI OPEN

% Last Modified by GUIDE v2.5 26-Jun-2014 14:19:50

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @pathAnalyzeGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @pathAnalyzeGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before pathAnalyzeGUI is made visible.
function pathAnalyzeGUI_OpeningFcn(hObject, ~, handles, varargin) %#ok<*DEFNU>
  
    
    handles.output = hObject;  % Choose default command line output for pathAnalyzeGUI
    
    % get the MPBus that was passed in from the mod manager
    if nargin > 3
        handles.mpbus = varargin{1};
    else
        handles.mpbus = MPBus(hObject);
    end
    
    %% user code here ...
    handles.mpbus.scanData = [];            % data from MATLAB, initialize to empty
    handles.scanResult3d = [];        % data from mpscope, initialize to empty
    handles.scanResult2d = [];        % data from mpscope, initialize to empty
    handles.scanResult1d = [];        % data from mpscope, initialize to empty
    
    %%%%% REMOVE THESE
    %handles.fileDirectory = '.\';     % initial file directory
    %handles.fileNameMat = '';         % holds name of Matlab file
    %handles.fileNameHDF = '';         % holds name of HDF5 file
    %handles.imageCh = 1;              % holds imaging channel to load
                                      % selected with pop-up, but default to 1

    % code for analysing data later
    handles.analyzeLater = false;    
    handles.analyzeLaterFilename = '';     % fid to write structures to analyse later
    handles.analyzeLaterIndex = 0;         % not currently used

    %%%%%% END REMOVE
    
    %mjp 2011.05.02
    set(gcf,'name','pathAnalyzeExtraGUI v0.3')
    
    guidata(hObject, handles); % Update handles structure

    % UIWAIT makes pathAnalyzeGUI wait for user response (see UIRESUME)
    % uiwait(handles.figure1);

% --- Outputs from this function are returned to the command line.
function varargout = pathAnalyzeGUI_OutputFcn(~, ~, handles) 

    varargout{1} = handles.output;

% --- BUTTON - Load Data - MATLAB
% TODO: Remove the need to load a Matlab open.
%       Everything should be in the HDF5 open anyway.
function pushButtonLoadDataMat_Callback(hObject, eventdata, handles)
    %{
    [handles.fileNameMat,handles.fileDirectory] = uigetfile([handles.fileDirectory '*.mat'],'open file - MATLAB (*.mat)'); % open file

    if ~verifyFile([handles.fileDirectory handles.fileNameMat], '.mat')
        return;
    end
    
    set(handles.figure1,'Name',['pathAnalyzeGUI     ' handles.fileNameMat '     ' handles.fileNameHDF]);
    
    load([handles.fileDirectory handles.fileNameMat]);      % load the MATLAB data here

    handles.mpbus.scanData = scanData;                            % place scan data in handles
    
    guidata(hObject, handles);                              % Update handles structure
    
    pushButtonResetImage_Callback(hObject, eventdata, handles);  % draw image
    %}

% --- BUTTON - Load Data MpScope
function pushButtonLoadDataHDF_Callback(hObject, eventdata, handles) 
    
    [fileName, filePath] = uigetfile('*.h5','open file - HDF5 (*.h5)'); % open file

    fullFileName = [filePath fileName];
    if ~MPBus.verifyFile(fullFileName, '.h5')
        return;
    end

    set(handles.figure1,'Name',['pathAnalyzeGUI     ' fileName]);
    success = handles.mpbus.open(fullFileName);
    if ~success
        disp('failed to open');
    end
    
    % put the scanData on the MPWorkspace
    handles.mpbus.output('scanData', handles.mpbus.scanData);
    
    % set the channel list
    popUpChannel = findobj('Tag', 'popUpChannel');
    channelCellArray = num2cell(handles.mpbus.channelList);
    
    set(popUpChannel, 'String', channelCellArray);
    
    % initialize
    handles.scanDataLines100 = handles.mpbus.readLines(1:100);
  
    figure(handles.figure1)    % return control to this figure, after the hdfRead
    

    % take the 1d data as a projection of this (first 1000 lines)...    
    handles.scanResult1d = mean(handles.scanDataLines100);   % average collapse to a single line
    handles.scanResult1d = handles.scanResult1d(:);            % make a column vector
    
    %%% sets up a bunch of things, once the data is loaded ...
    
    % check to make sure data is loaded
    if isempty( handles.scanResult1d )
        warndlg( '.h5 (HDF5 from MpScope) file was not loaded ...')
        return;
    end
    
    if isempty( handles.mpbus.scanData )
        warndlg( '.h5 (HDF5 from MpScope) did not have scan data associated with it ...')
        return;
    end
    
    sr1 = handles.scanResult1d;          % 'scan result 1d'
    
    % populate the path listbox
    populatePathListbox(handles);

    % draw first frame, in axesSingleFrame
    set(handles.figure1,'CurrentAxes',handles.axesSingleFrame)    
    imagesc(handles.scanDataLines100)   
    colormap('jet')
       
    % draw a projection, in axesSingleFrameProjection
    set(handles.figure1,'CurrentAxes',handles.axesSingleFrameProjection)
    cla 
    plot(sr1)
    colormap('jet')    
    set(gca,'xlim',[1 length(sr1)])

    pushButtonResetImage_Callback(hObject, eventdata, handles);  % draw image

    handles.nPoints = handles.mpbus.xsize ...
                      * handles.mpbus.ysize ...
                      * handles.mpbus.numFrames;
    
    % total number of lines in scanned data              
    handles.nLines = handles.mpbus.ysize ...
                     * handles.mpbus.numFrames;      
    handles.nPointsPerLine = handles.mpbus.xsize;

    handles.timePerLine = handles.nPointsPerLine * handles.mpbus.scanData.dt;
    
    %round minimum window duration (or time per line) to tenths of ms
    set(handles.minWin,'String',...
        num2str(round(handles.timePerLine*1e4)/10));
    
    % display some stuff for the user ...
    disp(['  total scan time (s): ' num2str(handles.nPoints * handles.mpbus.scanData.dt)])
    disp(['  time per line (ms): ' num2str(handles.nPointsPerLine * handles.mpbus.scanData.dt * 1000)])
    disp(['  scan frequency (Hz): ' num2str(1 / (handles.nPointsPerLine * handles.mpbus.scanData.dt))])
    disp(['  distance between pixels (in ROIs) (mV): ' num2str(handles.mpbus.scanData.scanVelocity *1e3)])
    disp(['  time between pixels (us): ' num2str(1e6*handles.mpbus.scanData.dt)])

    disp ' '
    disp ' initialize completed successfully '
    
    
    guidata(hObject, handles); % Update handles structure
    


% --- BUTTON - Initialize
function pushButtonInitialize_Callback(hObject, ~, handles)
    % DEPRECIATED -- ONLY NEED ONE UI BUTTON TO LOAD/INITIALIZE DATA
    %{
    % load the first 100 lines, for an initial look
    handles.scanDataLines100 = ... 
       hdfRead([handles.fileDirectory handles.fileNameHDF],'lines',handles.imageCh,1:100);
  
    figure(handles.figure1)    % return control to this figure, after the hdfRead
    
    % copy the selected channel into something useful for the program, so
    % it doesn't have to be selected specifically each time
    
    handles.scanDataLines100.Im = ...
        handles.scanDataLines100.(sprintf('Ch%d',handles.imageCh));

    % take the 1d data as a projection of this (first 1000 lines)...    
    handles.scanResult1d = mean(handles.scanDataLines100.Im);   % average collapse to a single line
    handles.scanResult1d = handles.scanResult1d(:);            % make a column vector
    
    %%% sets up a bunch of things, once the data is loaded ...
    
    % check to make sure data is loaded
    if isempty( handles.scanResult1d )
        warndlg( '.h5 (HDF5 from MpScope) file was not loaded ...')
        return;
    end
    
    if isempty( handles.mpbus.scanData )
        warndlg( '.mat (MATLAB) file was not loaded ...')
        return;
    end
    
    sr1 = handles.scanResult1d;          % 'scan result 1d'
    path = handles.mpbus.scanData.path;        % 'scan path'
    
    % TODO: message supressed for testing, re-enable this.
    %{
    if size(sr1,1) ~= size(path,1)
        warndlg( 'Path length from matlab and HDF5 file do not match!')
        return;
    end
    %}
    
    % populate the path listbox
    populatePathListbox(handles);

    % draw first frame, in axesSingleFrame
    set(handles.figure1,'CurrentAxes',handles.axesSingleFrame)    
    imagesc(handles.scanDataLines100.Im)   
    colormap('jet')
       
    % draw a projection, in axesSingleFrameProjection
    set(handles.figure1,'CurrentAxes',handles.axesSingleFrameProjection)
    cla 
    plot(sr1)
    colormap('jet')    
    set(gca,'xlim',[1 length(sr1)])


    handles.nPoints = handles.scanDataLines100.xsize ...
                      * handles.scanDataLines100.ysize ...
                      * handles.scanDataLines100.numFrames;
    
    % total number of lines in scanned data              
    handles.nLines = handles.scanDataLines100.ysize ...
                     * handles.scanDataLines100.numFrames;      
    handles.nPointsPerLine = handles.scanDataLines100.xsize;

    handles.timePerLine = handles.nPointsPerLine * handles.mpbus.scanData.dt;
    
    %round minimum window duration (or time per line) to tenths of ms
    set(handles.minWin,'String',...
        num2str(round(handles.timePerLine*1e4)/10));
    
    % display some stuff for the user ...
    disp(['  total scan time (s): ' num2str(handles.nPoints * handles.mpbus.scanData.dt)])
    disp(['  time per line (ms): ' num2str(handles.nPointsPerLine * handles.mpbus.scanData.dt * 1000)])
    disp(['  scan frequency (Hz): ' num2str(1 / (handles.nPointsPerLine * handles.mpbus.scanData.dt))])
    disp(['  distance between pixels (in ROIs) (mV): ' num2str(handles.mpbus.scanData.scanVelocity *1e3)])
    disp(['  time between pixels (us): ' num2str(1e6*handles.mpbus.scanData.dt)])

    disp ' '
    disp ' initialize completed successfully '
    
    
    guidata(hObject, handles); % Update handles structure
    %}
    
% --- BUTTON - Draw Scan Path
function pushButtonDrawScanPath_Callback(hObject, eventdata, handles)
    % check to make sure data was loaded
    if isempty( handles.scanResult1d )
        warndlg( 'oops, it appears that a .h5 (HDF5 from MpScope) file was not loaded ...')
        return;   
    end
    
    if isempty( handles.mpbus.scanData )
        return;
    end
    
    sr1 = handles.scanResult1d;          % 'scan result 1d'
    path = handles.mpbus.scanData.path;        % 'scan path'
    
    % plot the scan path here ...
    set(handles.figure1,'CurrentAxes',handles.axesMainImage)
    nPoints = size(path,1);
    hold on
    
    % scale the scan result for 0 to 1
    sr1scaled = sr1;
    sr1scaled = sr1scaled - min(sr1scaled);
    sr1scaled = sr1scaled ./ max(sr1scaled);
   
    %colormap(reverse(gray))
    %colormap('default')
    %colormap(gray);
    
    %C = flipud(colormap);
    %C = flipup(get(gca,'colormap'));
    %colormap(C);
    %set(gca,'colormap',C')
    
    drawEveryPoints = 10;
    
    set(handles.figure1,'CurrentAxes',handles.axesMainImage)

    for i = 1:drawEveryPoints:nPoints      % skip points, if the user requests
        
        %color = hsv2rgb([i/nPoints,1,1]);    
        %color = hsv2rgb([0,0,sr1scaled(i)]);        % plot intensity, black and white
        %color = [sr1scaled(i),0,0]                   % plot intensity as RED
        %color = [sr1scaled(i)/3 , sr1scaled(i) , sr1scaled(i)/3]                  % plot intensity as RED
        
        color = 'red';
        plot(path(i,1),path(i,2),'.','color',color)
        drawnow
    end
    
    % find the values from the image and the ideal path
    nRows = size(handles.mpbus.scanData.im,1);
    nCols = size(handles.mpbus.scanData.im,2);
    
    sr1im = 0*sr1;      % will hold the scan result, scanning ideal path across image
    
    % scale voltage coordinates to matrix coordinates
    xMinV = handles.mpbus.scanData.axisLimCol(1);
    xMaxV = handles.mpbus.scanData.axisLimCol(2);
    yMinV = handles.mpbus.scanData.axisLimRow(1);
    yMaxV = handles.mpbus.scanData.axisLimRow(2);

%% mjp commented out after feb 2011? try adding back in
    % Ilya's corrections for scaling
    %the +1 term is to account that we start at 1st pixel (not 0) but we end at 
    % nCol-1+1 pixel. Same for row. Checked with 512x512, 400x400, and 400x256
    pathImCoords(:,1) = (nCols-1)*(path(:,1)-xMinV)/(xMaxV- xMinV)+1;
    pathImCoords(:,2) = (nRows-1)*(path(:,2)-yMinV)/(yMaxV- yMinV)+1;
    
    imMarked = handles.mpbus.scanData.im;
    markIntensity = max(imMarked(:)) * 1.1;

    for i = 1:nPoints 
        try
            c = round(pathImCoords(i,1));   %jd - note c comes before r!
            r = round(pathImCoords(i,2));

            imMarked(r,c) = markIntensity; 

            sr1im(i) = handles.mpbus.scanData.im(r,c);
        catch
           disp('Point out of bounds'); 
        end
    end
    
    % scale so that data from image matches data acquired from arbs scan ... generally not needed
    sr1im = sr1im/mean(sr1im) * mean(sr1);
    
    % plot some values
    
    figure
   
    plot( [sr1im sr1] )
    legend('from image','from arb scan')
    
    guidata(hObject, handles);         % Update handles structure (save the image)

    pathImCoords(:,1) = path(:,1) * (nRows-1)/(xMaxV- xMinV) + 1 - (nRows-1)/(xMaxV - xMinV)*xMinV;
    pathImCoords(:,2) = path(:,2) * (nCols-1)/(yMaxV- yMinV) + 1 - (nCols-1)/(yMaxV - yMinV)*yMinV;
    
    imMarked = handles.mpbus.scanData.im;
    markIntensity = max(imMarked(:)) * 1.1;

    for i = 1:nPoints 
        c = round(pathImCoords(i,1));   %jd - note c comes before r!
        r = round(pathImCoords(i,2));
                        
        imMarked(r,c) = markIntensity; 
        
        sr1im(i) = handles.mpbus.scanData.im(r,c);
    end
    
    % scale so that data from image matches data acquired from arbs scan ... generally not needed
    sr1im = sr1im/mean(sr1im) * mean(sr1);
    
    % plot some values
    
    figure
    subplot(2,2,1:2)
    plot( [sr1im sr1] )
    legend('from image','from arb scan')
    
    guidata(hObject, handles);         % Update handles structure (save the image)


% --- BUTTON - Reset Image
function pushButtonResetImage_Callback(hObject, eventdata, handles)
    if isempty( handles.mpbus.scanData ) 
        return;
    end

    set(handles.figure1,'CurrentAxes',handles.axesMainImage)
    
    cla
    imagesc(handles.mpbus.scanData.axisLimCol,handles.mpbus.scanData.axisLimRow,handles.mpbus.scanData.im);
    axis on
    axis tight
    %colormap('gray');
    colormap('default');


% --- BUTTON - Rename
function pushButtonRename_Callback(hObject, eventdata, handles)    
    newName = inputdlg('type in new name (or enter to keep old name)');  % newName is a cell
    
    if isempty(newName)
        return   % nothing to rename
    end
    
    elementIndex = get(handles.listboxScanCoords,'Value');
    handles.mpbus.scanData.scanCoords(elementIndex).name = newName{1};  
    
    %% populate listbox
    strmat = [];
    for s = 1:length(handles.mpbus.scanData.scanCoords)      
        strmat = strvcat(strmat,handles.mpbus.scanData.scanCoords(s).name);
    end
    set(handles.listboxScanCoords,'String',cellstr(strmat));
    
    guidata(hObject, handles);                                   % Update handles structure
    
% --- helper function, allows user to select other limits
function [userStartPoint userEndPoint] = selectLimit(handles,autoStartPoint,autoEndPoint)
    % make sure the correct portion of the graph is selected, and draw
    im = handles.mpbus.readLines(1:100);
    figure(handles.figure1)
    set(handles.figure1,'CurrentAxes',handles.axesSingleFrame)    
    imagesc(im)   
    colormap('jet')
    hold on
   
    ymax = size(im,1);
    
    %plot values from open (initial guess)
    plot([autoStartPoint autoStartPoint],[1 ymax],'y')
    plot([autoEndPoint autoEndPoint],[1 ymax],'y')

    sp = ginput(1);    % get a user click, note sp(1) is distance across image
    if( sp(1)<1 | sp(1)>size(im,2) | sp(2)<1 | sp(2)>size(im,1))
        userStartPoint = autoStartPoint;   % user clicked outside image, use default point
    else
        userStartPoint = round(sp(1));            % use selected point
    end

    plot([userStartPoint userStartPoint],[1 ymax],'g')

    ep = ginput(1);     % get a user click, note ep(1) is distance across image
    if( ep(1)<1 | ep(1)>size(im,2) | ep(2)<1 | ep(2)>size(im,1))
        userEndPoint = autoEndPoint;     % user clicked outside image
    else
        userEndPoint = round(ep(1));            % use selected point
    end

    plot([userEndPoint userEndPoint],[1 ymax],'r')
    hold off
    

% --- BUTTON - Diameter Transform
function pushButtonDiameterTransform_Callback(hObject, eventdata, handles)
    % Calculate the velocity, using the radon transform
    
    elementIndex = get(handles.listboxScanCoords,'Value');    % grab the selected element
    
    % based on the item selected in the listbox, and the pathObjNum, find
    % the start and end indices
    allIndicesThisObject = find(handles.mpbus.scanData.pathObjNum == elementIndex);
    firstIndexThisObject = allIndicesThisObject(1);
    lastIndexThisObject = allIndicesThisObject(end);

    % let the user change the points, if desired
    [firstIndexThisObject lastIndexThisObject] = ...
        selectLimit(handles,firstIndexThisObject,lastIndexThisObject);
    
    dataStruct = struct( ...
        'fullFileName',handles.mpbus.fullFileName, ... 
        'firstIndexThisObject',firstIndexThisObject, ...
        'lastIndexThisObject',lastIndexThisObject, ...
        'assignName',handles.mpbus.scanData.scanCoords(elementIndex).name, ...
        'windowSize',handles.windowSize, ...
        'windowStep',handles.windowStep,...
        'analysisType','diameter', ...
        'scanVelocity',handles.mpbus.scanData.scanVelocity, ...
        'imageCh',handles.mpbus.activeChannel, ...
        'mpbus', handles.mpbus);

    if handles.analyzeLater
        handles.mpbus.output('dataStruct', dataStruct);
    else
        pathAnalysisHelper(dataStruct);
    end
    
    close(handles.output);

    
    
    % --- Executes on button press in pushButtonIntensity.
function pushButtonIntensity_Callback(hObject, eventdata, handles)
    % Calculate the velocity, using the radon transform
    
    elementIndex = get(handles.listboxScanCoords,'Value');    % grab the selected element
    
    % based on the item selected in the listbox, and the pathObjNum, find
    % the start and end indices
    allIndicesThisObject = find(handles.mpbus.scanData.pathObjNum == elementIndex);
    firstIndexThisObject = allIndicesThisObject(1);
    lastIndexThisObject = allIndicesThisObject(end);
    
    % let the user change the points, if desired
    if get(handles.allowResize,'Value')==1
        [firstIndexThisObject lastIndexThisObject] = ...
            selectLimit(handles,firstIndexThisObject,lastIndexThisObject);
    end
    
    dataStruct = struct( ...
        'fullFileName',handles.mpbus.fullFileName, ... 
        'firstIndexThisObject',firstIndexThisObject, ...
        'lastIndexThisObject',lastIndexThisObject, ...
        'assignName',handles.mpbus.scanData.scanCoords(elementIndex).name, ...
        'windowSize',handles.windowSize, ...
        'windowStep',handles.windowStep,...
        'analysisType','intensity', ...
        'scanVelocity',handles.mpbus.scanData.scanVelocity, ...
        'imageCh',handles.mpbus.activeChannel, ...
        'mpbus', handles.mpbus);
    
    if handles.analyzeLater
        handles.mpbus.output('dataStruct', dataStruct);
    else
        pathAnalysisHelper(dataStruct);
    end
   
% --- BUTTON - Radon Transform
function pushButtonRadonTransform_Callback(hObject, eventdata, handles)
    % Calculate the velocity, using the radon transform
    
    elementIndex = get(handles.listboxScanCoords,'Value');    % grab the selected element
    
    % based on the item selected in the listbox, and the pathObjNum, find
    % the start and end indices
    allIndicesThisObject = find(handles.mpbus.scanData.pathObjNum == elementIndex);
    firstIndexThisObject = allIndicesThisObject(1);
    lastIndexThisObject = allIndicesThisObject(end);
        
    % let the user change the points, if desired
    [firstIndexThisObject lastIndexThisObject] = ...
        selectLimit(handles,firstIndexThisObject,lastIndexThisObject);

    dataStruct = struct( ...
        'fullFileName',handles.mpbus.fullFileName, ... 
        'firstIndexThisObject',firstIndexThisObject, ...
        'lastIndexThisObject',lastIndexThisObject, ...
        'assignName',handles.mpbus.scanData.scanCoords(elementIndex).name, ...
        'windowSize',handles.windowSize, ...
        'windowStep',handles.windowStep,...
        'analysisType','radon', ...
        'scanVelocity',handles.mpbus.scanData.scanVelocity, ...
        'imageCh',handles.mpbus.activeChannel, ...
        'mpbus', handles.mpbus);
    
    
    if handles.analyzeLater
        handles.mpbus.output('dataStruct', dataStruct);
    else
        pathAnalysisHelper(dataStruct);
    end
    
% --- Executes on selection change in listboxScanCoords.
function listboxScanCoords_Callback(hObject, eventdata, handles)
% Hints: contents = get(hObject,'String') returns listboxScanCoords contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listboxScanCoords

    %jd - doesn't really do anything now ...
    % ... should have a check to see if data is loaded ...
    elementIndex = get(handles.listboxScanCoords,'Value');    % grab the selected element
    handles.mpbus.scanData.scanCoords(elementIndex);


% --- Executes during object creation, after setting all properties.
function listboxScanCoords_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end


% --- BUTTON - Draw Scan Regions
function pushButtonDrawScanRegions_Callback(hObject, eventdata, handles)
    % note - this code is copied straight from pathGUI, could be a separate function ...
    % plot the start and endpoints on the graph, and place text
    
    for i = 1:length(handles.mpbus.scanData.scanCoords)
        sc = handles.mpbus.scanData.scanCoords(i);     % copy to a structure, to make it easier to access
        if strcmp(sc.scanShape,'blank')
            break                       % nothing to mark
        end
    
        % mark start and end point 
        set(handles.figure1,'CurrentAxes',handles.axesMainImage)
        hold on
        
        plot(sc.startPoint(1),sc.startPoint(2),'g*')
        plot(sc.endPoint(1),sc.endPoint(2),'r*')
        
        % draw a line or box (depending on data structure type)
        if strcmp(sc.scanShape,'line')
            line([sc.startPoint(1) sc.endPoint(1)],[sc.startPoint(2) sc.endPoint(2)],'linewidth',2)
        elseif strcmp(sc.scanShape,'box')
            % width and height must be > 0 to draw a box
            boxXmin = min([sc.startPoint(1),sc.endPoint(1)]);
            boxXmax = max([sc.startPoint(1),sc.endPoint(1)]);
            boxYmin = min([sc.startPoint(2),sc.endPoint(2)]);
            boxYmax = max([sc.startPoint(2),sc.endPoint(2)]);
                
            rectangle('Position',[boxXmin,boxYmin, ...
                boxXmax-boxXmin,boxYmax-boxYmin], ...
                'EdgeColor','green');
        end
        
        % find a point to place text
        placePoint = sc.startPoint + .1*(sc.endPoint-sc.startPoint);
        text(placePoint(1)-.1,placePoint(2)+.05,sc.name,'color','red','FontSize',12)

    end

    colormap 'jet'

    

% --- BUTTON - Look ...
function pushButtonLook_Callback(hObject, eventdata, handles)
    % take the radon transform, would need to call Patrick's code ...
    elementIndex = get(handles.listboxScanCoords,'Value');    % grab the selected element
        
    % the data is held in:
    %   handles.mpbus.scanData.scanResult3d
    % marks for what part of the path corresponds to what are in:
    %   handles.mpbus.scanData.pathObjNum
    
    % for the item selected in the listbox, find the start and end indices, and cut out data
     
    % find the indices of this scan object, subject to the constraint that the subObjectNum is non-zero
    % subOjectNum being non-zero has no effect for lines, but will cut out turn regions for boxes
    %indices = (handles.mpbus.scanData.pathObjNum  == elementIndex & handles.mpbus.scanData.pathObjSubNum > 0);
    indices = (handles.mpbus.scanData.pathObjNum  == elementIndex);

    % cut out data, and image first frame ...
    %lineData = handles.scanResult3d(:,firstIndexThisObject:lastIndexThisObject,1);
    lineData = handles.scanResult3d(:,indices,1);
    
    figure
    subplot(4,2,1:4)
    imagesc(lineData)
    
    % image projection of first frame
    subplot(4,2,5:6)
    lineData = mean(lineData,1);
    plot(lineData)
    a = axis;
    axis( [1 length(lineData) a(3) a(4)] )
    
    % cut out only the sub-object portion, and plot this
    
    % find the indices of this scan object, subject to the constraint that the subObjectNum is non-zero
    % subOjectNum being non-zero has no effect for lines, but will cut out turn regions for boxes
    %indices = (handles.mpbus.scanData.pathObjNum  == elementIndex & handles.mpbus.scanData.pathObjSubNum > 0);
    indices = (handles.mpbus.scanData.pathObjNum  == elementIndex & handles.mpbus.scanData.pathObjSubNum > 0);

    % cut out data, and image first frame ...
    %lineData = handles.scanResult3d(:,firstIndexThisObject:lastIndexThisObject,1);
    lineData = handles.scanResult3d(:,indices,1);
    
    % 
    subplot(4,2,7:8)
    lineData = mean(lineData,1);
    plot(lineData)
    a = axis;
    axis( [1 length(lineData) a(3) a(4)] )
    
       
    
%--- EDIT (enter) - Window Size (in milliseconds)
function editWindowSizeMs_Callback(hObject, eventdata, handles)
    handles.windowSize = 1e-3*str2double(get(hObject,'String'));  % store as seconds
    guidata(hObject, handles);   % Update handles structure

% --- EDIT (creation) - Window Size (in milliseconds)
function editWindowSizeMs_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    editWindowSizeMs_Callback(hObject, eventdata, handles)   % execute, to read initial value
    

%--- EDIT (enter) - Window Step (in milliseconds)
function editWindowStepMs_Callback(hObject, eventdata, handles)
    handles.windowStep = 1e-3*str2double(get(hObject,'String'));  % store as seconds
    guidata(hObject, handles);   % Update handles structure


% --- EDIT (creation) - Window Step (in milliseconds)
function editWindowStepMs_CreateFcn(hObject, eventdata, handles)
    if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
        set(hObject,'BackgroundColor','white');
    end
    editWindowStepMs_Callback(hObject, eventdata, handles)   % execute, to read initial value


% --- BUTTON - Analyse Stored Selections
function pushButtonAnalyseStoredSelections_Callback(hObject, eventdata, handles)
    % not curretly used
    return;

% --- CHECKBOX - Queue Values (analyse later.
function checkboxQueueValues_Callback(hObject, eventdata, handles)
    value = get(handles.checkboxQueueValues,'Value');

    %{
    if value == true;
        c = clock;
        % elements are year, month, day, hour, minute, seconds
        s = '_'; % the space character, goes between the elements of the data
        c = [num2str(c(1)) s num2str(c(2)) s num2str(c(3)) s num2str(c(4)) s num2str(c(5)) s num2str(round(c(6)))];
    
        handles.analyzeLaterFilename =  ['a' c '.m']; 
        handles.analyzeLater = true;    
        
        % write the header info
        fid = fopen(handles.analyzeLaterFilename,'a');
        
        % ... \% escape sequence does not work ... ?
        fprintf(fid,['%% analysis file for ' handles.fileNameMat ' ' handles.fileNameHDF '\n']);
        fprintf(fid,['%% created ' num2str(c(1)) '-' num2str(c(2)) '-' num2str(c(3)) '\n']);
                
        fprintf(fid,'dataStructArray = []; \n\n');
        fclose(fid);
    else
        handles.analyzeLater = false;
    end
    %}
    
    handles.analyzeLater = value;
    guidata(hObject, handles);   % Update handles structure

function writeForLater(dataStruct,handles)
    % write this stuff to appropriate filename    
    
    fid = fopen(handles.analyzeLaterFilename,'a');
    
    escapedFilename = regexprep(dataStruct.fullFileNameHDF,'\\','\\\');  % changes \ to \\
    
    fprintf(fid,'dataStruct = struct( ...\n');
    fprintf(fid,[' ''fullFileNameHDF'',' '''' escapedFilename '''' ', ...\n'] ,'char');
    fprintf(fid,[' ''firstIndexThisObject'',' '' num2str(dataStruct.firstIndexThisObject) '' ', ...\n'],'char');
    fprintf(fid,[' ''lastIndexThisObject'',' '' num2str(dataStruct.lastIndexThisObject) '' ', ...\n'],'char');   
    fprintf(fid,[' ''assignName'',' '''' dataStruct.assignName '''' ', ...\n'],'char');
    fprintf(fid,[' ''windowSize'',' num2str(dataStruct.windowSize) ', ...\n'],'char');
    fprintf(fid,[' ''windowStep'',' num2str(dataStruct.windowStep) ', ...\n'],'char');
    fprintf(fid,[' ''analysisType'',' '''' dataStruct.analysisType '''' ', ...\n'],'char');
    fprintf(fid,[' ''scanVelocity'',' num2str(dataStruct.scanVelocity) ', ...\n'],'char');
    fprintf(fid,[' ''imageCh'',' num2str(dataStruct.imageCh) ' ...\n'],'char');
    fprintf(fid,');\n');
    
    fprintf(fid,'dataStructArray = [dataStructArray dataStruct];\n');
    
    fprintf(fid,'\n');
  
    fclose(fid);


% --- Executes on selection change in popUpChannel.
function popUpChannel_Callback(hObject, eventdata, handles)
% hObject    handle to popUpChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns popUpChannel contents as cell array
%        contents = get(hObject,'Value') returns selected item from popUpChannel
    index = get(hObject,'Value');
    channelList = get(hObject, 'String');
    
    % remember which image channel the user selected by saving it as the
    % MPBus activeChannel. When MPBus performs read operations, it will do
    % so for the image channel specified by activeChannel
    channelNumber = str2double(channelList{index});
    if ~isnan(channelNumber)
        handles.mpbus.activeChannel = channelNumber;
    end
    
    guidata(hObject, handles); % Update handles structure
    
% --- Executes during object creation, after setting all properties.
function popUpChannel_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popUpChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in allowResize.
function allowResize_Callback(hObject, eventdata, handles)
% hObject    handle to allowResize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Utility Functions
function populatePathListbox(handles)
    % start with an empty string matrix and populate
    % it with the names of every path in scanCoords  
    strmat = [];
    
    for s = 1:length(handles.mpbus.scanData.scanCoords)      
        strmat = char(strmat,handles.mpbus.scanData.scanCoords(s).name);
    end

    strcell = cellstr(strmat);   % convert to a cell array
    % then remove any empty cells
    strcell_nospace = strcell(~cellfun('isempty', strcell));
   
    % use cellstr to convert the matrix into a form that
    % the listbox will accept.
    set(handles.listboxScanCoords,'String',strcell_nospace);
    


% --------------------------------------------------------------------
function MainMenu_Callback(hObject, eventdata, handles)
% hObject    handle to Open (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function Open_Callback(hObject, eventdata, handles)
% hObject    handle to Open (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function Calculations_Callback(hObject, eventdata, handles)
% hObject    handle to Calculations (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function Diamter_Callback(hObject, eventdata, handles)
% hObject    handle to Diamter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function Intensity_Callback(hObject, eventdata, handles)
% hObject    handle to Intensity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function Velocity_Callback(hObject, eventdata, handles)
% hObject    handle to Velocity (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
