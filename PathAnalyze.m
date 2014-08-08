function PathAnalyze( varargin )
%PATHANALYZE A GUI that allows gives users a top down and side view of
%image data from MPScope, along with the line scan data. Users can select
%regions and run diameter, intensity, or velocity calculations.
%   Detailed explanation goes here


handles = createGUI();

% Constants:
handles.COLORMAP = 'gray';

% check if a MPBus object was passed into varargin, otherwise just create a
% new MPBus

if nargin > 0
   if isa(varargin{1}, 'MPBus')
       handles.mpbus = varargin{1};
   else
       % there was a varargin but it wasn't a MPBus
       disp('Creating a new MPBus');
       handles.mpbus = MPBus(handles.main);
   end
else
    % there was no varargin
    disp('Creating a new MPBus');
    handles.mpbus = MPBus(handles.main);
end

guidata(handles.main, handles);

end

%%% Image Drawing Functions
function drawTopView(handles)
    set(handles.main,'CurrentAxes',handles.axes_topView);
    
    cla
    imagesc(handles.mpbus.scanData.axisLimCol,handles.mpbus.scanData.axisLimRow,handles.mpbus.scanData.im);
    axis off
    colormap(handles.COLORMAP);
end

function drawSideView(handles, z)
end

function drawLineView(handles, startingLine)

    % the number of lines to draw is based on the height of the line scan
    % axes
    axesPosition = getpixelposition(handles.axes_lineScan);
    finishLine = startingLine + axesPosition(4);
    
    lineData = handles.mpbus.readLines(startingLine : finishLine);
    
    set(handles.main,'CurrentAxes',handles.axes_lineScan);    
    cla
    imagesc(lineData);
    axis off
    colormap(handles.COLORMAP);
   
end
%%%



%%% Callbacks
function slider_lineScan_Callback(hObject, ~)
    handles = guidata(hObject);    
    selectedLine = int32(get(hObject, 'Value'));
    disp(selectedLine);
    drawLineView(handles, selectedLine);
end

function slider_sideView_Callback(hObject, ~)
end

function loadFile(hObject, ~)
    handles = guidata(hObject);
    
    [fileName, filePath] = uigetfile('*.h5','open file - HDF5 (*.h5)'); % open file

    fullFileName = [filePath fileName];
    if ~MPBus.verifyFile(fullFileName, '.h5')
        return;
    end

    % TODO: need better way to display which file is open
    %set(handles.figure1,'Name',['pathAnalyzeGUI     ' fileName]);
    
    success = handles.mpbus.open(fullFileName);
    if ~success
        fprintf('There was a problem opening the file "%s".\n', fullFileName);
        return;
    end
    
    % put the scanData on the MPWorkspace
    handles.mpbus.output('scanData', handles.mpbus.scanData);
    
    % set the channel list
    % TODO: need a new way to display channel list
    
    % TODO: populate the path listbox
    
    % setup the sliders before drawing anything
    finishLine = handles.mpbus.ysize * handles.mpbus.numFrames;
    set(handles.slider_sideView, 'Min', 1);
    set(handles.slider_sideView, 'Max', finishLine);
    set(handles.slider_sideView, 'Value', 1);
    set(handles.slider_sideView, 'SliderStep', [1/finishLine , 10/finishLine ]);
    
    
    % draw image
    drawTopView(handles);
    drawSideView(handles, 1);
    drawLineView(handles, 1);
    
    
    handles.nPoints = handles.mpbus.xsize ...
                      * handles.mpbus.ysize ...
                      * handles.mpbus.numFrames;
    
    % total number of lines in scanned data              
    handles.nLines = handles.mpbus.ysize ...
                     * handles.mpbus.numFrames;      
    handles.nPointsPerLine = handles.mpbus.xsize;

    handles.timePerLine = handles.nPointsPerLine * handles.mpbus.scanData.dt;
    
    % display some stuff for the user ...
    disp(['  total scan time (s): ' num2str(handles.nPoints * handles.mpbus.scanData.dt)])
    disp(['  time per line (ms): ' num2str(handles.nPointsPerLine * handles.mpbus.scanData.dt * 1000)])
    disp(['  scan frequency (Hz): ' num2str(1 / (handles.nPointsPerLine * handles.mpbus.scanData.dt))])
    disp(['  distance between pixels (in ROIs) (mV): ' num2str(handles.mpbus.scanData.scanVelocity *1e3)])
    disp(['  time between pixels (us): ' num2str(1e6*handles.mpbus.scanData.dt)])

    disp ' '
    disp ' initialize completed successfully '
    
    
    guidata(hObject, handles); % Update handles structure
    
end

function drawScanRegion(hObject, ~)
end

function drawScanPath(hObject, ~)
end

function resetImage(hObject, ~)
end

function calculateDiameter(hObject, ~)
end

function calculateIntensity(hObject, ~)
end

function calculateVelocity(hObject, ~)
end
%%%







function createSideSlider(handles)
    %check to see if the slider already exists then create a new one
end



function handles = createGUI()

handles.main = figure(...
'Units','characters',...
'Color',[0.941176470588235 0.941176470588235 0.941176470588235],...
'Colormap',[0 0 0.5625;0 0 0.625;0 0 0.6875;0 0 0.75;0 0 0.8125;0 0 0.875;0 0 0.9375;0 0 1;0 0.0625 1;0 0.125 1;0 0.1875 1;0 0.25 1;0 0.3125 1;0 0.375 1;0 0.4375 1;0 0.5 1;0 0.5625 1;0 0.625 1;0 0.6875 1;0 0.75 1;0 0.8125 1;0 0.875 1;0 0.9375 1;0 1 1;0.0625 1 1;0.125 1 0.9375;0.1875 1 0.875;0.25 1 0.8125;0.3125 1 0.75;0.375 1 0.6875;0.4375 1 0.625;0.5 1 0.5625;0.5625 1 0.5;0.625 1 0.4375;0.6875 1 0.375;0.75 1 0.3125;0.8125 1 0.25;0.875 1 0.1875;0.9375 1 0.125;1 1 0.0625;1 1 0;1 0.9375 0;1 0.875 0;1 0.8125 0;1 0.75 0;1 0.6875 0;1 0.625 0;1 0.5625 0;1 0.5 0;1 0.4375 0;1 0.375 0;1 0.3125 0;1 0.25 0;1 0.1875 0;1 0.125 0;1 0.0625 0;1 0 0;0.9375 0 0;0.875 0 0;0.8125 0 0;0.75 0 0;0.6875 0 0;0.625 0 0;0.5625 0 0],...
'IntegerHandle','off',...
'MenuBar','none',...
'Name','Path Analyze',...
'NumberTitle','off',...
'Position',[40 4 200 50],...
'Tag','figure1',...
'Visible','on' );

%%% CONTROLS
handles.panel_controls = uipanel(...
'Parent',handles.main,...
'Title','Controls',...
'Clipping','on',...
'Position',[0.014 0.46 0.15 0.5],...
'Tag','panel_controls' );
%%%

%%% TOP VIEW
handles.panel_topView = uipanel(...
'Parent',handles.main,...
'Title','Top Down View',...
'Clipping','on',...
'Position',[0.18 0.46 0.4 0.5],...
'Tag','panel_topView' );

handles.axes_topView = axes(...
'Parent',handles.panel_topView,...
'Position',[0.025 0.05 0.9 0.9],...
'XTick', [],...
'YTick', [],...
'Tag','axes_topView' );
%%%

%%% SIDE VIEW
handles.panel_sideView = uipanel(...
'Parent',handles.main,...
'Title','Side View',...
'Clipping','on',...
'Position',[0.585 0.46 0.4 0.5],...
'Tag','panel_sideView' );

handles.axes_sideView = axes(...
'Parent',handles.panel_sideView,...
'Position',[0.025 0.05 0.9 0.9],...
'XTick', [],...
'YTick', [],...
'Tag','axes_sideView' );

handles.slider_sideView = uicontrol(...
'Parent',handles.panel_sideView,...
'Units','normalized',...
'BackgroundColor',[0.9 0.9 0.9],...
'Callback',@slider_sideView_Callback,...
'Position',[0.94 0.05 0.05 0.9],...
'String',{  'Z Axis' },...
'Style','slider',...
'Tag','slider_sideView');
%%%

%%% LINE SCAN
handles.panel_lineScan = uipanel(...
'Parent',handles.main,...
'Title','Line Scan',...
'Clipping','on',...
'Position',[0.012 0.007 0.973 0.453],...
'Tag','panel_lineScan' );

handles.axes_lineScan = axes(...
'Parent',handles.panel_lineScan,...
'Position',[0.026 0.088 0.945 0.9],...
'XTick', [],...
'YTick', [],...
'Tag','axes_lineScan' );

handles.slider_lineScan = uicontrol(...
'Parent',handles.panel_lineScan,...
'Units','normalized',...
'BackgroundColor',[0.9 0.9 0.9],...
'Callback',@slider_lineScan_Callback,...
'Position',[0.975 0.088 0.022 0.9],...
'String',{  'Time Axis' },...
'Style','slider',...
'Tag','slider_lineScan');
%%%


%%% UI MENU
handles.menu_file = uimenu(...
'Parent',handles.main,...
'Label','File',...
'Tag','menu_file' );

handles.menu_open = uimenu(...
'Parent',handles.menu_file,...
'Accelerator','O',...
'Callback',@loadFile,...
'Label','Open...',...
'Tag','menu_open' );

handles.menu_image = uimenu(...
'Parent',handles.main,...
'Label','Image',...
'Tag','menu_image' );

handles.menu_drawScanRegion = uimenu(...
'Parent',handles.menu_image,...
'Callback',@drawScanRegion,...
'Label','Draw Scan Region',...
'Tag','menu_drawScanRegion' );

handles.menu_drawScanPath = uimenu(...
'Parent',handles.menu_image,...
'Callback',@drawScanPath,...
'Label','Draw Scan Path',...
'Tag','menu_drawScanPath' );

handles.menu_resetImage = uimenu(...
'Parent',handles.menu_image,...
'Callback',@resetImage,...
'Label','Reset Image',...
'Tag','menu_resetImage' );

handles.menu_calculate = uimenu(...
'Parent',handles.main,...
'Label','Calculate',...
'Tag','menu_calculate' );

handles.menu_diameter = uimenu(...
'Parent',handles.menu_calculate,...
'Accelerator','D',...
'Callback',@calculateDiameter,...
'Label','Diameter',...
'Tag','menu_diameter' );

handles.menu_intensity = uimenu(...
'Parent',handles.menu_calculate,...
'Accelerator','I',...
'Callback',@calculateIntensity,...
'Label','Intensity',...
'Tag','menu_intensity' );

handles.menu_velocity = uimenu(...
'Parent',handles.menu_calculate,...
'Accelerator','V',...
'Callback',@calculateVelocity,...
'Label','Velocity',...
'Tag','menu_velocity' );
%%%




end