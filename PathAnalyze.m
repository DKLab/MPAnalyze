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
handles.windowHorizontalPixelLocations = 1; % the pixel location of every 
                                            %visible horizontal window line
                    
handles.windowWidth = 0;

handles.closestPoint = [];
handles.closestLineHandle = [];

handles.region = struct(...
    'leftBoundary',0,...
    'rightBoundary',0,...
    'lineHandle',[],...
    'lineStyle',':');

handles.regionPath = [];        % initially this is just scanData.pathObjNum
                                % which is an array of integers that
                                % indicate where each region is on the scan
                                % path
handles.dragLine = struct(...
    'isActive', false,...
    'isHorizontal', false,...
    'regionIndex', 0,...
    'isLeftBoundary',false,...
    'horizontalLine',0);
                                
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
set(handles.main, 'WindowButtonUpFcn', @mouseUp);

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
        handles = drawLineView(handles);
        guidata(handles.main, handles);
    end
end

function drawTopView(handles)
    set(handles.main,'CurrentAxes',handles.axes_topView);
    scanData = handles.mpbus.scanData;
    
    cla
    imageHandle = imagesc(scanData.axisLimCol, scanData.axisLimRow, ...
                                                            scanData.im);
    axis off
    colormap(handles.colormap);
    
    set(imageHandle, 'ButtonDownFcn', @mouseClick_top);
end

function drawSideView(handles, z)
    if ~exist('z', 'var')
        z = 0;
    end
end

function handles = drawLineView(handlesIn, startingLine)
    persistent lastStartingLine;
    handles = handlesIn;
    % the number of lines to draw is based on the height of the line scan
    % axes
    if ~exist('startingLine', 'var')
        if isempty(lastStartingLine)
            startingLine = 1;
        else
            startingLine = lastStartingLine;
        end
    else
        lastStartingLine = startingLine;
    end
    
    axesPosition = getpixelposition(handles.axes_lineScan);
    finishLine = startingLine + axesPosition(4);
    visibleRange = startingLine : finishLine;
    domain = [1, floor(axesPosition(3))];
    
    lineData = handles.mpbus.readLines(visibleRange);
    
    set(handles.main,'CurrentAxes',handles.axes_lineScan);    
    cla
    imagesc(lineData, 'ButtonDownFcn', @mouseClick_line);
    axis off
    colormap(handles.colormap);
    
    % now draw lines to show where the data windows are
    % for now, just drawing horizontal lines
    [~, visibleLocations] = ismember(handles.windowHorizontalLocations, visibleRange);
    visibleLocations(visibleLocations==0) = [];     % remove unmatched elements
    handles.windowHorizontalPixelLocations = visibleLocations;
    
    for location = visibleLocations
        line(domain, [location location], ...
            'color','red',...
            'Tag','scanWindow',...
            'LineStyle',':',...
            'ButtonDownFcn',@mouseClick_line);
    end
    
    drawRegionInLineView(handles);
end

function drawRegionInLineView(handles)
    % draw the boundaries for every region in handles.region struct array
    
    oldLines = findall(handles.axes_lineScan, 'Tag', 'regionLine');
    delete(oldLines);
    
    set(handles.main, 'CurrentAxes', handles.axes_lineScan);
    
    Y = ylim;
    
    
    for region = handles.region
        x1 = region.leftBoundary;
        x2 = region.rightBoundary;
                
        if isempty(region.lineStyle)
            region.lineStyle = ':';
        end
        
        if strcmp(region.lineStyle, '-')
            % color the lines cyan as well
            leftColor = 'cyan';
            rightColor = 'cyan';
        else
            leftColor = 'green';
            rightColor = 'red';
        end
        
        line([x1,x1],Y,...
            'Tag','regionLine',...
            'Color',leftColor,...
            'LineStyle',region.lineStyle,...
            'ButtonDownFcn',@mouseClick_line );
        line([x2,x2],Y,...
            'Tag','regionLine',...
            'Color',rightColor,...
            'LineStyle',region.lineStyle,...
            'ButtonDownFcn',@mouseClick_line );
    end
end
%%%

function updateMousePosition(hObject)
   % for each window line on the axes, find the closest point to (x,y)
    % then from the set of closest points, find the closest one to (x,y)
    % and draw a line (point) with the tag closestPoint
    
   handles = guidata(hObject);
   
   scanData = handles.mpbus.scanData;
   
   if ~isempty(scanData)
       xBoundsTop = scanData.axisLimRow;
       yBoundsTop = scanData.axisLimCol;
       xBoundsLine = get(handles.axes_lineScan, 'XLim');
       yBoundsLine = get(handles.axes_lineScan, 'YLim');
       
       topViewPosition = get(handles.axes_topView, 'CurrentPoint');
       lineScanPosition = get(handles.axes_lineScan, 'CurrentPoint');
       
       x_topView = topViewPosition(1,1);
       y_topView = topViewPosition(1,2);
       x_lineScan = lineScanPosition(1,1);
       y_lineScan = lineScanPosition(1,2);
       
       if x_topView > xBoundsTop(1) && x_topView < xBoundsTop(2) && ...
          y_topView > yBoundsTop(1) && y_topView < yBoundsTop(2)

            updateMousePosition_topView(handles, x_topView, y_topView);
            
       elseif x_lineScan > xBoundsLine(1) && x_lineScan < xBoundsLine(2) && ...
              y_lineScan > yBoundsLine(1) && y_lineScan < yBoundsLine(2)
      
            updateMousePosition_lineScan(handles, x_lineScan, y_lineScan);
       else
           % reset cursor
           set(handles.main, 'Pointer', 'arrow');
       end
   end
end

function updateMousePosition_topView(handles, x, y)
    % cursor is in the top view axes
    % determine which line is the closest to the cursor
    lineList = findall(handles.axes_topView, 'Tag', 'windowLine');
    if ~isempty(lineList)

        closestPointList = cell(length(lineList), 1);

        for index = 1 : length(lineList)
            closestPointList{index} = getClosestPoint( ...
                                    lineList(index), x, y);        
        end

        squareDistanceList = cellfun(@squareDistance, closestPointList);

        [ ~, closestLineIndex ] = min(squareDistanceList);

        closestPoint = closestPointList{closestLineIndex};
        % save this info for later
        handles.closestPoint = closestPoint;
        handles.closestLineHandle = lineList(closestLineIndex);
        guidata(handles.main, handles);

        % and draw
        drawPoint(handles.axes_topView, closestPoint(1), closestPoint(2) );

     end
    
     function d = squareDistance(p)
        d = ( p(1) - x )^2 + ( p(2) - y )^2;
     end
                
end

function updateMousePosition_lineScan(handles, x, y)
    % draw a point on the top view axes that corresponds to the pixel that
    % the cursor is over on the line scan axes
    
    % constants: the number of pixels the cursor can be away from a line
    MOUSE_PIXEL_WIDTH = 5;       
    
    pixelIndex = ceil(x);
    scanPath = handles.mpbus.scanData.path;
    regionPath = handles.regionPath;

    
    % get the set of pixels near the cursor location -- if the elements are
    % not all the same then the cursor is near a boundary
    startIndex = pixelIndex - MOUSE_PIXEL_WIDTH;
    endIndex = pixelIndex + MOUSE_PIXEL_WIDTH;
    
    if startIndex <= 0
        startIndex = 1;
    end
    
    if endIndex > length(regionPath)
        endIndex = length(regionPath);
    end
    
    localRegion = regionPath(startIndex : endIndex);
    
    % check if cursor is near vertical line
    if min(localRegion) ~= max(localRegion)
        set(handles.main, 'Pointer', 'left');
    else
        set(handles.main, 'Pointer', 'arrow');
    end
    
    % check if cursor is near horizontal line
    isHorizontal = closeToHorizontalLine(handles, y);
    
    if isHorizontal 
        set(handles.main, 'Pointer', 'top');
    end

    if pixelIndex > 0 && pixelIndex <= length(scanPath)
        x_topView = scanPath(pixelIndex,1);
        y_topView = scanPath(pixelIndex,2);    
        
        drawPoint( handles.axes_topView, x_topView, y_topView );
        updateDrag(handles, pixelIndex, floor(y) );
    end
end

function [ isClose, horizontalLine] = closeToHorizontalLine(handles, lineNumber)
    MOUSE_PIXEL_HEIGHT = 5;
    
    distance = abs( handles.windowHorizontalPixelLocations - lineNumber );
    
    foundIndex = find(distance < MOUSE_PIXEL_HEIGHT, 1);
    horizontalLine = handles.windowHorizontalPixelLocations(foundIndex);
    isClose = ~isempty(foundIndex);
end

function closestPoint = getClosestPoint(lineHandle, x, y)
    X = get(lineHandle, 'XData');
    Y = get(lineHandle, 'YData');
     
    lineVector = [ X(2) - X(1), Y(2) - Y(1) ];
    pointVector = [ x - X(1), y - Y(1) ];
    L = dot(lineVector, lineVector);
    r = dot(lineVector, pointVector) / L;
    
    
    closestPoint = [ X(1), Y(1) ] + lineVector .* r;
    
    if r < 0
        closestPoint(1) = X(1);
        closestPoint(2) = Y(1);
    end
    
    if r > 1
        closestPoint(1) = X(2);
        closestPoint(2) = Y(2);
    end
end

function drawPoint(axesHandle, x, y)
    
    persistent pointHandle;
    
    if ishghandle(pointHandle)
        delete(pointHandle);
    end

    pointHandle = line(x,y,...
                        'Marker','o',...
                        'Color','green',...
                        'Parent',axesHandle,...
                        'Tag','closestPoint',...
                        'ButtonDownFcn', @mouseClick_top);

end


function handles = createRegions(handlesIn)
    % the line scan data is captured along the entire scan path, determine
    % where regions are from the scanCoords in scanData
    % the pathObjNum array in scanData is nonzero when the path is within a
    % scan region. (The number indicates which region number it is)
    handles = handlesIn;
    scanData = handles.mpbus.scanData;
       
    if ~isempty(scanData)
        if isempty(handles.regionPath)
            regionPath = scanData.pathObjNum;
        else
            regionPath = handles.regionPath;
        end
        
        regionIndex = 0;
        for pixelIndex = 1 : length(regionPath)
           if regionPath(pixelIndex) ~= regionIndex
                % a region boundary has been encountered
                
                if regionPath(pixelIndex) == 0
                    % the region has ended, update the region indicated by
                    % the regionIndex (this was the regionIndex before the
                    % boundary was encountered)
                    handles.region(regionIndex).rightBoundary = pixelIndex;
                    
                    % then update the regionIndex for the next iteration
                    % (we already know this has to be 0)
                    regionIndex = 0;
                else
                    % the region has begun, update the region index first
                    regionIndex = regionPath(pixelIndex);
                    handles.region(regionIndex).leftBoundary = pixelIndex;
                end
           end
        end
        
        % save the region path -- all other functions will use
        % handles.regionPath instead of scanData.pathObjNum
        handles.regionPath = regionPath;
    end
end

function activateRegion(handles, regionIndex)
    % highlight the selected region line in the top view
    allLines = findall(handles.axes_topView, 'Tag', 'windowLine');
    set(allLines, ...
        'LineStyle', ':',...
        'Color', 'blue');
    
    regionLine = findall(handles.axes_topView, 'UserData', regionIndex);
    set(regionLine, ...
        'LineStyle', '-',...
        'Color', 'cyan');
                
    % then update the region line style in the line scan view
    
    for index = 1 : length(handles.region)
        if index == regionIndex
            handles.region(index).lineStyle = '-';
        else
            handles.region(index).lineStyle = ':';
        end
    end
    
    handles = drawLineView(handles);
    
    guidata(handles.main, handles);
    
end

function handles = activateDrag(handlesIn, regionIndex, isLeftBoundary,...
                                isHorizontal, horizontalLine )
    % the left or right boundaries of a region can be dragged
    % if isHorizontalLines is true then instead of dragging vertical region
    % lines, user will be dragging the horizontal lines
    handles = handlesIn;
    handles.dragLine.isHorizontal = isHorizontal;
    handles.dragLine.isLeftBoundary = isLeftBoundary;
    handles.dragLine.regionIndex = regionIndex;    
    
    if ~exist('horizontalLine', 'var')
        horizontalLine = 0;
    end
    
    handles.dragLine.horizontalLine = horizontalLine;
    
    if regionIndex > 0 || isHorizontal
       handles.dragLine.isActive = true;
    else
        handles.dragLine.isActive = false;
    end
end

function handles = deactivateDrag(handlesIn)
    handles = handlesIn;
    handles.dragLine.isActive = false;
    handles.dragLine.isHorizontal = false;
    
    dragHandle = findall(handles.axes_lineScan, 'Tag', 'dragLine');
    if ishghandle(dragHandle)
        xdata = get(dragHandle, 'XData');
        pixelIndex = floor( xdata(1) );
        if pixelIndex <= 0
            pixelIndex = 1;
        end
        handles = updateRegionWidth(handles, ...
                                    handles.dragLine.regionIndex,...
                                    handles.dragLine.isLeftBoundary,...
                                    pixelIndex);
    end
    disp('--------');
end

function updateDrag(handles, pixelIndex, lineIndex)
    persistent dragHandle;
    PERIOD_CHANGE = 1;
    %TODO need to clean up the horizontal line behavior (too clunky atm)
    
    if handles.dragLine.isActive
        if handles.dragLine.isHorizontal
            % horizontal drag
            if lineIndex < handles.dragLine.horizontalLine 
                % reduce the horizontal period (distance between horizontal
                % lines)
                handles.windowPeriod = handles.windowPeriod - PERIOD_CHANGE;
            else
                % increase the horizontal period
                handles.windowPeriod = handles.windowPeriod + PERIOD_CHANGE;
            end
            handles.windowHorizontalLocations = ...
                                    1:handles.windowPeriod:handles.nLines;
            guidata(handles.main, handles);
        else
            % vertical drag
            Y = get(handles.axes_lineScan, 'YLim');
            if ishghandle(dragHandle)
                if pixelIndex > 0 && pixelIndex <= length(handles.regionPath)
                    set(dragHandle, 'XData', [pixelIndex, pixelIndex], 'YData', Y);
                end
            else
                dragHandle = line( [pixelIndex, pixelIndex], Y, ...
                                    'Color', 'cyan',...
                                    'LineStyle', ':',...
                                    'Tag','dragLine');
            end
        end
    end
end

function handles = updateRegionWidth(...
                    handlesIn, regionIndex, isLeftBoundary, newPixelIndex)
    % a new area in the regionPath will be filled with the regionIndex, or
    % a new area will be zeroed out to effectively change the width
    % of a region as defined in regionPath
    
    % if newPixelIndex - (bounary location) is positive, then add new
    % nonzero elements to regionPath
    % if it's negative, add zeros to regionPath
    handles = handlesIn;

    if regionIndex > 0
        % check that the new region (as indicated by newPixelIndex) does not
        % include a region other than the one indicated by regionIndex
        bounds = [ newPixelIndex, handles.region(regionIndex).leftBoundary ];
        newRegion = handles.regionPath( min(bounds) : max(bounds) );
        invalidElements = newRegion(newRegion > 0 & newRegion ~= regionIndex);
        
        if ~isempty(invalidElements)
            return;
        end
        
        if isLeftBoundary
            boundaryIndex = handles.region(regionIndex).leftBoundary;
            
            if boundaryIndex - newPixelIndex < 0
                newValue = 0;
            else 
                newValue = regionIndex;
            end
            
            if newPixelIndex > handles.region(regionIndex).rightBoundary
                return;
            end
        else
            boundaryIndex = handles.region(regionIndex).rightBoundary;
            
            if boundaryIndex - newPixelIndex < 0
                newValue = regionIndex;
            else 
                newValue = 0;
            end
            
            if newPixelIndex < handles.region(regionIndex).leftBoundary
                return;
            end
        end
        
        bounds = [ newPixelIndex, boundaryIndex ];
        handles.regionPath( min(bounds) : max(bounds) ) = newValue;
        
    end
end
%%% Callbacks
function mouseClick_top(hObject, ~)

    handles = guidata(hObject);
    if ishghandle(handles.closestLineHandle)
        % if the user clicked within the topView axes, highlight the region
        % (in the lineScan axes) that corresponds to the closestPoint line

        regionIndex = get(handles.closestLineHandle, 'UserData');
        activateRegion(handles, regionIndex);
    end
end

function mouseClick_line(hObject, ~)
    % called when user clicks within the lineScan axes
    % begin dragging mode (determine which region and line to move)
    % when the mouse button is released, dragging mode will be disabled
    MOUSE_PIXEL_WIDTH = 5; 
    
    handles = guidata(hObject);
    
    mouseLocation = get(handles.axes_lineScan, 'CurrentPoint');
    
    pixelIndex = floor(mouseLocation(1,1));
    if pixelIndex == 0
        pixelIndex = 1;
    end
    
    % if the user clicked within a region, highlight it
    regionPath = handles.regionPath;
    if ~isempty(regionPath)
        % check to see if the cursor is close to a region
        startIndex = pixelIndex - MOUSE_PIXEL_WIDTH;
        endIndex = pixelIndex + MOUSE_PIXEL_WIDTH;
        if startIndex <= 0
            startIndex = 1;
        end
        if endIndex > length(regionPath)
            endIndex = length(regionPath);
        end
            
        localRegion = regionPath(startIndex : endIndex);
        
        % determine if this is the left or the right boundary
        if localRegion(1) < localRegion(end)
            isLeftBoundary = true;
        else
            isLeftBoundary = false;
        end
        
        % check if the cursor is close to a horizontal line (this will
        % supersede the vertical line drag)
        [isHorizontal, horizontalLine] = ...
                       closeToHorizontalLine( handles, mouseLocation(1,2) );
        
        if min(localRegion) ~= max(localRegion) || isHorizontal 
            handles = activateDrag(handles,  max(localRegion),...
                            isLeftBoundary, isHorizontal, horizontalLine );
        end
        
        activateRegion(handles, max(localRegion));
    end
end

function mouseMovement(hObject, ~)
    updateMousePosition(hObject);
    
%{  
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
%}
end

function slider_lineScan_Callback(hObject, ~)
    handles = guidata(hObject);    
    sliderValue = floor(get(hObject, 'Value'));
    
    max = get(hObject, 'Max');
    line = max - sliderValue + 1;
    
    handles = drawLineView(handles, line);
    guidata(handles.main, handles);
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
    
    
    
    % setup the sliders
    range = [1, (handles.mpbus.ysize * handles.mpbus.numFrames)];
    handles = createLineSlider(handles, range, 10, 100);
    
    
    % setup region boundaries
    handles = createRegions(handles);
    
    % draw image
    drawTopView(handles);
    drawSideView(handles, 1);
    handles = drawLineView(handles);
    
    guidata(hObject, handles); % Update handles structure
    
end

function drawScanRegion(hObject, ~)
    handles = guidata(hObject);
    
    % allow user to toggle the scan region
    checked = get(handles.menu_drawScanRegion, 'Checked');
    switch checked
        case 'on'
            % just clear the scan region and uncheck this option
            lines = findall(handles.axes_topView, 'Tag', 'windowLine');
            points = findall(handles.axes_topView, 'Tag', 'windowPoint');
            delete(lines);
            delete(points);
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
            'Tag','windowPoint');
        plot(sc.endPoint(1),sc.endPoint(2),'r*',...
            'Tag','windowPoint');
        
        % draw a line or box (depending on data structure type)
        if strcmp(sc.scanShape,'line')
            line([sc.startPoint(1) sc.endPoint(1)], ...
                [sc.startPoint(2) sc.endPoint(2)],...
                'linewidth',2,...
                'Tag','windowLine',...
                'LineStyle',':',...
                'UserData',i);
        elseif strcmp(sc.scanShape,'box')
            % width and height must be > 0 to draw a box
            boxXmin = min([sc.startPoint(1),sc.endPoint(1)]);
            boxXmax = max([sc.startPoint(1),sc.endPoint(1)]);
            boxYmin = min([sc.startPoint(2),sc.endPoint(2)]);
            boxYmax = max([sc.startPoint(2),sc.endPoint(2)]);
                
            rectangle('Position',[boxXmin,boxYmin, ...
                boxXmax-boxXmin,boxYmax-boxYmin], ...
                'EdgeColor','green',...
                'Tag','windowLine',...
                'UserData',i);
        end
        
        % find a point to place text
        %placePoint = sc.startPoint + .1*(sc.endPoint-sc.startPoint);
        %text(placePoint(1)-.1,placePoint(2)+.05,sc.name,'color','red','FontSize',12)

        % attach a context menu to the axes
        menuHandle = uicontextmenu;
        uimenu(menuHandle,'Label','Hide','Callback',@axesmenu_hide);
        set(handles.axes_topView, 'uicontextmenu', menuHandle);
        
        % draw the scan regions on the Line Scan axes
        drawRegionInLineView(handles);
    end
end


function axesmenu_hide(hObject, ~)
    disp('hiding this line');
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

function mouseUp(hObject, ~)
    handles = guidata(hObject);
    handles = deactivateDrag(handles);
    
    % then recreate the regions
    handles = createRegions(handles);
    
    % and redraw the linescan axes
    handles = drawLineView(handles);
    
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
    'Position',[0.02 0.088 0.955 0.9],...
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