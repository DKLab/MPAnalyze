function PathAnalyze( varargin )
%PATHANALYZE A GUI that allows gives users a top down and side view of
%image data from MPScope, along with the line scan data. Users can select
%regions and run diameter, intensity, or velocity calculations.
%   Detailed explanation goes here


handles = createGUI();

% Constants:
handles.SLIDER_WIDTH = 20;
handles.BUTTON_WIDTH = 60;
handles.BUTTON_HEIGHT = 25;

% Data window specs (values are modified by the user through the GUI)
handles.showWindow = false;
handles.windowPeriod = 100;       % the height (in time) of a data window
handles.windowHorizontalLocations = 1;  % the line locations of every horizontal window line
handles.windowWidth = 0;

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

set(handles.main, 'WindowButtonMotionFcn', @mouseMovement);

guidata(handles.main, handles);

% set the default colormap
selectColormap(handles.main, [], 'gray');

end

%%% Image Drawing Functions
function refreshAll(handles)
    % only refresh if there is a file open to get image data from
    set(handles.menu_drawScanRegion, 'Checked', 'off');
    set(handles.menu_drawScanPath, 'Checked', 'off');
    
    if ~isempty(handles.mpbus.fullFileName)
        drawTopView(handles);
        drawSideView(handles);
        drawLineView(handles);
    end
end

function drawTopView(handles)
    set(handles.main,'CurrentAxes',handles.axes_topView);
    
    cla
    imagesc(handles.mpbus.scanData.axisLimCol,handles.mpbus.scanData.axisLimRow,handles.mpbus.scanData.im);
    axis off
    colormap(handles.colormap);
end

function drawSideView(handles, z)
    if ~exist('z', 'var')
        z = 0;
    end
end

function drawLineView(handles, startingLine)

    % the number of lines to draw is based on the height of the line scan
    % axes
    if ~exist('startingLine', 'var')
        startingLine = 1;
    end
    
    axesPosition = getpixelposition(handles.axes_lineScan);
    finishLine = startingLine + axesPosition(4);
    visibleRange = startingLine : finishLine;
    domain = [1, floor(axesPosition(3))];
    
    lineData = handles.mpbus.readLines(visibleRange);
    
    set(handles.main,'CurrentAxes',handles.axes_lineScan);    
    cla
    imagesc(lineData);
    axis off
    colormap(handles.colormap);
    
    % now draw lines to show where the data windows are
    % for now, just drawing horizontal lines
    [~, visibleLocations] = ismember(handles.windowHorizontalLocations, visibleRange);
    visibleLocations(visibleLocations==0) = [];     % remove unmatched elements
    for location = visibleLocations
        line(domain, [location location], 'color','red','Tag','scanWindow');
    end
    
   
end
%%%

function updateMousePosition(hObject)
   handles = guidata(hObject);
   
   mousePosition = get(handles.axes_topView, 'CurrentPoint');
   
   % check if the mouse is in the top view axes
   topViewAxes = getpixelposition(handles.axes_topView);
   topViewPanel = getpixelposition(handles.panel_topView);
   
   %{
   bounds(1) = topViewAxes(1) + topViewPanel(1);
   bounds(2) = topViewAxes(2) + topViewPanel(2);
   bounds(3) = topViewAxes(3);
   bounds(4) = topViewAxes(4);
   %}
   bounds = topViewPanel;
   
   x = floor(mousePosition(1) - bounds(1));
   y = floor(mousePosition(2) - bounds(2));
   
   disp('----------------------------------------');
   disp(bounds);
   fprintf('mouse: x:%d, y:%d\n', mousePosition(1), mousePosition(2));
   fprintf('top view, x:%d, y:%d\n', x, y);
end


%%% Callbacks
function mouseMovement(hObject, ~)
    persistent lastMoveTime;
    currentTime = clock;
    WAIT_SECONDS = 0.1;

    if isempty(lastMoveTime)
        lastMoveTime = currentTime;
    else
       if etime(currentTime, lastMoveTime) >= WAIT_SECONDS
           lastMoveTime = currentTime;
           updateMousePosition(hObject);
       end
    end

end

function slider_lineScan_Callback(hObject, ~)
    handles = guidata(hObject);    
    sliderValue = floor(get(hObject, 'Value'));
    
    max = get(hObject, 'Max');
    line = max - sliderValue + 1;
    
    drawLineView(handles, line);
end

function slider_sideView_Callback(hObject, ~)
    selectedLine = floor(get(hObject, 'Value'));
    disp(selectedLine);
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
    
   handles.windowHorizontalLocations = ...
                                    1:handles.windowPeriod:handles.nLines;
    
    % draw image
    drawTopView(handles);
    drawSideView(handles, 1);
    drawLineView(handles, 1);
    
    
    % setup the sliders
    range = [1, (handles.mpbus.ysize * handles.mpbus.numFrames)];
    handles = createLineSlider(handles, range, 10, 100);
    
    guidata(hObject, handles); % Update handles structure
    
end

function drawScanRegion(hObject, ~)
    handles = guidata(hObject);
    
    % allow user to toggle the scan region
    checked = get(handles.menu_drawScanRegion, 'Checked');
    switch checked
        case 'on'
            % just clear the scan region and uncheck this option
            lines = findall(handles.axes_topView, 'Tag', 'regionLine');
            delete(lines);
            set(handles.menu_drawScanRegion, 'Checked', 'off');
            return;
        case 'off'
            % this is the only option that continues the execution of this
            % function
            set(handles.menu_drawScanRegion, 'Checked', 'on');
        otherwise
            % something went wrong, just exit
            return;
    end
    
    
    for i = 1:length(handles.mpbus.scanData.scanCoords)
        sc = handles.mpbus.scanData.scanCoords(i);     % copy to a structure, to make it easier to access
        
        if strcmp(sc.scanShape,'blank')
            break                       % nothing to mark
        end
    
        % mark start and end point 
        set(handles.main,'CurrentAxes',handles.axes_topView);
        hold on
        
        plot(sc.startPoint(1),sc.startPoint(2),'g*',...
            'Tag','regionLine');
        plot(sc.endPoint(1),sc.endPoint(2),'r*',...
            'Tag','regionLine');
        
        % draw a line or box (depending on data structure type)
        if strcmp(sc.scanShape,'line')
            line([sc.startPoint(1) sc.endPoint(1)], ...
                [sc.startPoint(2) sc.endPoint(2)],...
                'linewidth',2,...
                'Tag','regionLine');
        elseif strcmp(sc.scanShape,'box')
            % width and height must be > 0 to draw a box
            boxXmin = min([sc.startPoint(1),sc.endPoint(1)]);
            boxXmax = max([sc.startPoint(1),sc.endPoint(1)]);
            boxYmin = min([sc.startPoint(2),sc.endPoint(2)]);
            boxYmax = max([sc.startPoint(2),sc.endPoint(2)]);
                
            rectangle('Position',[boxXmin,boxYmin, ...
                boxXmax-boxXmin,boxYmax-boxYmin], ...
                'EdgeColor','green',...
                'Tag','regionLine');
        end
        
        % find a point to place text
        %placePoint = sc.startPoint + .1*(sc.endPoint-sc.startPoint);
        %text(placePoint(1)-.1,placePoint(2)+.05,sc.name,'color','red','FontSize',12)

    end
end

function drawScanPath(hObject, ~)
    handles = guidata(hObject);
    
    checked = get(handles.menu_drawScanPath, 'Checked');
    switch checked
        case 'on'
            % just clear the scan region and uncheck this option
            points = findall(handles.axes_topView, 'Tag', 'pathPoint');
            delete(points);
            set(handles.menu_drawScanPath, 'Checked', 'off');
            return;
        case 'off'
            % this is the only option that continues the execution of this
            % function
            set(handles.menu_drawScanPath, 'Checked', 'on');
        otherwise
            % something went wrong, just exit
            return;
    end
    
    
    path = handles.mpbus.scanData.path;
 
    set(handles.main,'CurrentAxes',handles.axes_topView)
    nPoints = size(path,1);
    hold on
    
    drawEveryPoints = 10;
    
    set(handles.main,'CurrentAxes',handles.axes_topView)

    for i = 1:drawEveryPoints:nPoints      % skip points, if the user requests
        plot(path(i,1),path(i,2),'.','color','red','Tag','pathPoint');
        drawnow
    end

end

function resetImage(hObject, ~)
    handles = guidata(hObject);
    refreshAll(handles);
end

function calculateDiameter(hObject, ~)
end

function calculateIntensity(hObject, ~)
end

function calculateVelocity(hObject, ~)
end

function selectColormap(hObject, ~, colormap)
    handles = guidata(hObject);
    
    % make sure a check is placed on the colormap menu item that was
    % selected
    allHandles = allchild(handles.menu_colormap);
    set(allHandles, 'Checked', 'off');
    
    menu_handle = sprintf('menu_%s', colormap);
    set(handles.(menu_handle), 'Checked', 'on');
    
    handles.colormap = colormap;
    guidata(hObject, handles);
    
    refreshAll(handles);
end

function displayTimeInterval(hObject, ~)
    % draw windows on the scan data to indicate regions that will be
    % calculated
    handles = guidata(hObject);
    
    handles.showWindow = true;
    
    guidata(handles.main, handles);
end
%%%


function handles = createSideSlider(handlesToUpdate, range, ticks_click, ticks_drag)
    %check to see if the slider already exists then create a new one
    
    % the range and tick arguments are optional, set them to default values
    % if they weren't specified
    if ~exist('range', 'var')
        range = 1:100;
    end
    if ~exist('ticks_click', 'var')
        ticks_click = 1;
    end
    if ~exist('ticks_drag', 'var')
        ticks_drag = 10;
    end
    
    NORMAL_BUFFER = .01;
    handles = handlesToUpdate;
    
    if isfield(handles, 'slider_sideView')
        delete(handles.slider_sideView);
    end
    
    if ~isfield(handles, 'axes_sideView') || ~isfield(handles, 'panel_sideView')
        % can't create the slider if the axes don't exist so just exit
        return;
    end
        
    % determine dimensions of the slider
    axesPixelPosition = getpixelposition(handles.axes_sideView);
    axesNormalPosition = get(handles.axes_sideView, 'Position');
    
    height = axesNormalPosition(4);
    
    normalWidth = axesNormalPosition(3);
    pixelWidth = axesPixelPosition(3);
    
    width = handles.SLIDER_WIDTH * normalWidth / pixelWidth;
    
    x = axesNormalPosition(1) + normalWidth + NORMAL_BUFFER;
    y = axesNormalPosition(2);
  
    maxValue = range(end);
    
    handles.slider_sideView = uicontrol(...
        'Parent',handles.panel_sideView,...
        'Units','normalized',...
        'BackgroundColor',[0.9 0.9 0.9],...
        'Callback',@slider_sideView_Callback,...
        'Position',[x y width height],...
        'String',{  'Z Axis' },...
        'Style','slider',...
        'Tag','slider_sideView',...
        'Min', range(1),...
        'Max', maxValue,...
        'Value', range(1),...
        'SliderStep', [ticks_click/maxValue , ticks_drag/maxValue ]);
end
function handles = createLineSlider(handlesToUpdate, range, ticks_click, ticks_drag)
    %check to see if the slider already exists then create a new one
    
    % the range and tick arguments are optional, set them to default values
    % if they weren't specified
    if ~exist('range', 'var')
        range = 1:100;
    end
    if ~exist('ticks_click', 'var')
        ticks_click = 1;
    end
    if ~exist('ticks_drag', 'var')
        ticks_drag = 10;
    end
    
    NORMAL_BUFFER = 0;
    handles = handlesToUpdate;
    
    if isfield(handles, 'slider_lineScan')
        delete(handles.slider_lineScan);
    end
    
    if ~isfield(handles, 'axes_lineScan') || ~isfield(handles, 'panel_lineScan')
        % can't create the slider if the axes don't exist so just exit
        return;
    end
        
    % determine dimensions of the slider
    axesPixelPosition = getpixelposition(handles.axes_lineScan);
    axesNormalPosition = get(handles.axes_lineScan, 'Position');
    
    height = axesNormalPosition(4);
    
    normalWidth = axesNormalPosition(3);
    pixelWidth = axesPixelPosition(3);
    
    width = handles.SLIDER_WIDTH * normalWidth / pixelWidth;
    
    x = axesNormalPosition(1) + normalWidth + NORMAL_BUFFER;
    y = axesNormalPosition(2);
  
    maxValue = range(end);
    
    handles.slider_lineScan = uicontrol(...
        'Parent',handles.panel_lineScan,...
        'Units','normalized',...
        'BackgroundColor',[0.9 0.9 0.9],...
        'Callback',@slider_lineScan_Callback,...
        'Position',[x y width height],...
        'String',{  'Z Axis' },...
        'Style','slider',...
        'Tag','slider_lineScan',...
        'Min', range(1),...
        'Max', maxValue,...
        'Value', range(end),...
        'SliderStep', [ticks_click/maxValue , ticks_drag/maxValue ]);
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
    'Position',[0.09 0.088 0.88 0.9],...
    'XTick', [],...
    'YTick', [],...
    'Tag','axes_lineScan' );

%{
handles.button_timeWindow = uicontrol(...
    'Parent',handles.panel_lineScan,...
    'Style', 'pushbutton',...
    'Units','normalized',...
    'Position', [0.007 0.8 0.075 0.09],...
    'Min',0,...
    'Max',1,...
    'String', 'Time Interval',...
    'Callback', @displayTimeInterval);
%}
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

handles.menu_colormap = uimenu(...
    'Parent',handles.menu_image,...
    'Label','Colormap',...
    'Tag','menu_colormap' );

    handles.menu_jet = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Jet',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'jet'} );

    handles.menu_hsv = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','HSV',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'hsv'} );

    handles.menu_gray = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Gray',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'gray'} );

    handles.menu_hot = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Hot',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'hot'} );

    handles.menu_cool = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Cool',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'cool'} );

    handles.menu_spring = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Spring',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'spring'} );

    handles.menu_summer = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Summer',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'summer'} );

    handles.menu_autumn = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Autumn',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'autumn'} );

    handles.menu_winter = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Winter',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'winter'} );

    handles.menu_bone = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Bone',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'bone'} );

    handles.menu_copper = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Copper',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'copper'} );

    handles.menu_pink = uimenu(...
        'Parent',handles.menu_colormap,...
        'Label','Pink',...
        'Tag','menu_colormap_option',...
        'Callback',{@selectColormap, 'pink'} );

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