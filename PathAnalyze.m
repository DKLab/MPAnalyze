function PathAnalyze( varargin )
%PATHANALYZE A GUI that allows gives users a top down and side view of
%image data from MPScope, along with the line scan data. Users can select
%regions and run diameter, intensity, or velocity calculations.
%   Detailed explanation goes here


handles = createGUI();

% Constants:
handles.SLIDER_WIDTH = 20;

handles.MINIMUM_WINDOW_PERIOD = 15;
handles.IMAGE_SCALE_FACTOR = 1;     % used by calculator
handles.OUTLIER_SIGMA = 3;   % the number of standard deviations that signifies an outlier
% REJECT_ANGLE_RANGE is in units of pi radians and indicates the range of
% angles to reject from Radon transforms. ( for example, 0.5 means pi/2 radians ) 
handles.REJECT_ANGLE_RANGE = [0.40, 0.60];
handles.isLoaded = false;
handles.imageStack = [];

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
    'lineStyle',':',...
    'leftScanCoord',0,...
    'rightScanCoord',0);

handles.activeRegion = [];  % will contain a single region struct from
                            % the stuct array handles.region
handles.activeRegionIndex = 0;

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
       handles.mpbus = MPBus(handles.main, true);
   end
else
    % there was no varargin
    disp('Creating a new MPBus');
    handles.mpbus = MPBus(handles.main);
end

set(handles.main, 'WindowButtonMotionFcn', @mouseMovement);
set(handles.main, 'WindowButtonUpFcn', @mouseUp);
set(handles.main, 'ResizeFcn', @resizeFigure);

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

        handles = drawLineView(handles);
        guidata(handles.main, handles);
        
        drawScanRegion(handles.main, []);
    end
    
    % also redraw the calculator images
    drawFrame(handles);
end

function drawTopView(handles)
    set(handles.main,'CurrentAxes',handles.axes_topView);
    scanData = handles.mpbus.scanData;
    
    cla
    imageHandle = imagesc(scanData.axisLimCol, scanData.axisLimRow, ...
                                                            scanData.im);
    axis off
    axis image
    colormap(handles.colormap);
    
    set(imageHandle, 'ButtonDownFcn', @mouseClick_top);
end

function [ X, Y ] = getPixelIndicies(startPixel, endPixel)
%GETPIXELINDICIES returns an array of indicies corresponding to the pixels
%along the line from startPixel to endPixel

    % using point slope formla y - y0 = m(x - x0)
    X = startPixel(1) - 10 : endPixel(1) + 10;
    m = (endPixel(2) - startPixel(2)) /...
        (endPixel(1) - startPixel(1));
    x0 = startPixel(1);
    y0 = startPixel(2);
    
    Y = round( m .* ( X - x0 ) + y0 ); 
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
    
    if handles.isLoaded
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
                    handles.region(regionIndex).rightScanCoord = ...
                        [scanCoords.startPoint(1), scanCoords.startPoint(2)];
                    
                    % update the active region as well
                    if regionIndex == handles.activeRegionIndex
                        handles.activeRegion.rightBoundary = pixelIndex;
                    end
                    
                    % then update the regionIndex for the next iteration
                    regionIndex = 0;
                else
                    % the region has begun, update the region index first
                    regionIndex = regionPath(pixelIndex);
                    
                    % then get new scanCoords for this region
                    scanCoords = scanData.scanCoords(regionIndex);
                    handles.region(regionIndex).leftScanCoord = ...
                        [scanCoords.endPoint(1), scanCoords.endPoint(2)];
                    
                    handles.region(regionIndex).leftBoundary = pixelIndex;
                    
                    % update the active region as well
                    if regionIndex == handles.activeRegionIndex
                        handles.activeRegion.leftBoundary = pixelIndex;
                    end
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
    
    
    % save this as the active region
    controlHandles = findall(handles.panel_control,...
                                'Tag', 'activeRegionControl');
    extractHandles = findall(handles.main, 'Tag', 'extract');
    inactiveControlHandles = findall(handles.panel_control,...
                                'Tag', 'activeRegionControl_inactive');
    allHandles = union(controlHandles, extractHandles);
    
    if regionIndex > 0
        handles.activeRegion = handles.region(regionIndex);
        handles.activeRegionIndex = regionIndex;
        set(allHandles, 'Enable','on');
        set(inactiveControlHandles, 'Enable', 'inactive');
    else
        handles.activeRegion = [];
        handles.activeRegionIndex = 0;
        set(allHandles, 'Enable','off');
        set(inactiveControlHandles, 'Enable', 'off');
    end
     
    guidata(handles.main, handles);
    displayWidthChange(handles);
    displayHeightChange(handles);

end

function handles = heightChange(handles, newPixelHeight)
    handles.windowPeriod = newPixelHeight;
    
    handles.windowHorizontalLocations = ...
                                    1:handles.windowPeriod:handles.nLines;
                                
    displayHeightChange(handles);
end

function handles = widthChange(handles, newPixelWidth)
end

function displayHeightChange(handles)
    % all regions automatically have the same height -- just set the value
    % in the edit boxes based on the current window period from
    % handles.windowPeriod
    
    height_px = sprintf('%d', handles.windowPeriod);
    height_ms = sprintf('%.1f', handles.msPerLine * handles.windowPeriod);
    set(handles.edit_regionHeight_px, 'String', height_px);
    set(handles.edit_regionHeight_ms, 'String', height_ms);
end

function displayWidthChange(handles, changeInWidth)
    if ~isempty(handles.activeRegion)
        if ~exist('changeInWidth', 'var')
            regionWidth = handles.activeRegion.rightBoundary - ...
                    handles.activeRegion.leftBoundary + 1;
        else
            regionWidth = str2double(get(handles.edit_regionWidth_px, 'String'));

            if isnan(regionWidth)
                regionWidth = changeInWidth;
            else
                regionWidth = regionWidth + changeInWidth;
            end

        end

        width_px = sprintf('%d', regionWidth);
        width_mv = sprintf('%d', regionWidth * handles.mvPerPixel);
        set(handles.edit_regionWidth_px, 'String', width_px);
        set(handles.edit_regionWidth_mv, 'String', width_mv);
    end

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
    dragHandle = findall(handles.axes_lineScan, 'Tag', 'dragLine');
    
    if ishghandle(dragHandle)
        if handles.dragLine.isHorizontal
            % horizontal drag
            ydata = get(dragHandle, 'YData');
            lineIndex = floor( ydata(1) );
            
            if lineIndex <= 0
                lineIndex = 1;
            end
            
            % change the window period s.t. the difference between the line
            % index and the original location of the line
            % (dragline.horizontalLine) is equal to the difference in
            % window period
            difference = handles.dragLine.horizontalLine - lineIndex;
            handles.windowPeriod = handles.windowPeriod - difference; 
            
            if handles.windowPeriod < handles.MINIMUM_WINDOW_PERIOD
                handles.windowPeriod = handles.MINIMUM_WINDOW_PERIOD;
            end
            
            handles.windowHorizontalLocations = ...
                                    1:handles.windowPeriod:handles.nLines;
                                
            displayHeightChange(handles);
        else
            % vertical drag
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
    end
    
    handles.dragLine.isActive = false;
    handles.dragLine.isHorizontal = false;
end

function updateDrag(handles, pixelIndex, lineIndex)
    persistent dragHandle;

    if handles.dragLine.isActive
        if handles.dragLine.isHorizontal
            % horizontal drag
            X = get(handles.axes_lineScan, 'XLim');
            yBounds = get(handles.axes_lineScan, 'YLim');
            
            if ishghandle(dragHandle)   
                if lineIndex >= yBounds(1) && lineIndex <= yBounds(2)
                    set(dragHandle, 'XData', X, 'YData', [lineIndex, lineIndex]);
                end
            else
                dragHandle = line( X, [lineIndex, lineIndex], ...
                                    'Color', 'red',...
                                    'LineStyle', ':',...
                                    'Tag','dragLine');
            end
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
            
            widthDifference = boundaryIndex - newPixelIndex;
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
            
            widthDifference = newPixelIndex - boundaryIndex;
        end
        
        bounds = [ newPixelIndex, boundaryIndex ];
        handles.regionPath( min(bounds) : max(bounds) ) = newValue;
        
        % update the region width edit box
        displayWidthChange(handles, widthDifference);
        
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

function loadScanFile(hObject, ~, optional_filename)
    handles = guidata(hObject);
    
    if exist('optional_filename', 'var')
        fullFileName = optional_filename;
    else
        [fileName, filePath] = uigetfile('*.h5','open file - HDF5 (*.h5)'); % open file

        fullFileName = [filePath fileName];
    end
    
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
    handles.mpbus.output('scanData', handles.mpbus.scanData, 'Path Analyze');
    
    % set the channel list
    % TODO: need a new way to display channel list
    
    % TODO: populate the path listbox
    
   
    handles.isLoaded = true;
    
    handles.nPoints = handles.mpbus.xsize ...
                      * handles.mpbus.ysize ...
                      * handles.mpbus.numFrames;
    %TODO: try/catch error if the loaded file doesnt actually have this
    %info
    
    % total number of lines in scanned data              
    handles.nLines = handles.mpbus.ysize ...
                     * handles.mpbus.numFrames;      
    handles.nPointsPerLine = handles.mpbus.xsize;

    handles.timePerLine = handles.nPointsPerLine * handles.mpbus.scanData.dt;
    
    handles.mvPerPixel = handles.mpbus.scanData.scanVelocity * 1000;
    handles.msPerLine = handles.nPointsPerLine * handles.mpbus.scanData.dt * 1000;
    
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
    handles = createLineSlider(handles, range);
    
    
    % setup region boundaries
    handles = createRegions(handles);
    
    % draw image
    drawTopView(handles);
    handles = drawLineView(handles);
    
    guidata(hObject, handles); % Update handles structure
    
    drawScanRegion(handles.main, []);
    
    resizeFigure(handles.main, []);
end


function convertFile(hObject, ~)
    handles = guidata(hObject);
    
    [fileName, filePath] = uigetfile('*.mpd','open file - MPD (*.mpd)'); % open file

    fullFileName = [filePath fileName];
    if MPBus.verifyFile(fullFileName, '.mpd')
        [ h5Filename, success ] = convert(fullFileName);
        
        
        if success
            loadFile(hObject, [], h5Filename);
        end
    end
    
    
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

        
        % draw the scan regions on the Line Scan axes
        drawRegionInLineView(handles);
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
    
    % reset the regions before drawing anything
    handles.regionPath = handles.mpbus.scanData.pathObjNum;
    activateRegion(handles, 0);

    handles = createRegions(handles);
    
    % and reset the window period
    handles = heightChange(handles, 100);
    
    refreshAll(handles);
end

function calculateDiameter(hObject, ~)
    handles = guidata(hObject);
    
    handles = clearResults(handles);
    
    if isfield(handles, 'exImageData') && ~isempty(handles.exImageData)
        [ results, diameterVector ] = diameter(handles.exImageData);
        
        handles.diameter = results;
        % make the results visible
        set(handles.axes_results, 'Visible', 'on');
        drawFrame(handles);

        outputDiameter(handles, diameterVector);
    
        guidata(handles.main, handles);
    end
    
    % enable the Reject Frames button
    set(handles.button_reject, 'Enable', 'on');
end

function outputDiameter(handles, diameterVector)

    if ~isempty( handles.mpbus.fullFileName )
        [ ~, filename, ~ ] = fileparts( handles.mpbus.fullFileName );
    else
        filename = 'output';
    end
    
    varname = sprintf('Diameter_%s', filename); 
    handles.mpbus.output(varname, diameterVector);

    figure; plot(diameterVector);
end

function calculateIntensity(hObject, ~)
    % simply get the mean intensity (value) for all frames of the extracted image
    handles = guidata(hObject);
    
    handles = clearResults(handles);
    
    if isfield(handles, 'exImageData') && ~isempty(handles.exImageData)
        intensity = mean( mean(handles.exImageData, 1), 3);
        
        % output the results right away (nothing to display in the results
        % axes)
        outputIntensity(handles, intensity);
        
        figure, plot(intensity);
    end
    
    guidata(hObject, handles);
end

function outputIntensity(handles, intensity)

        [~,filename,~] = fileparts(handles.mpbus.fullFileName);
            
        varname = sprintf('Intensity_%s', filename); 
        handles.mpbus.output(varname, intensity);
end

function calculateVelocity(hObject, ~)
    % get the Radon transform for each frame of the extracted image
    
    handles = guidata(hObject);
    handles = clearResults(handles);
    
    if isfield(handles, 'exImageData') && ~isempty(handles.exImageData)
        handles.velocity = velocity(handles.exImageData);
    end

    guidata(hObject, handles);
    
    drawFrame(handles);
    
    set(handles.button_reject, 'Enable', 'on');
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

function mouseUp(hObject, ~)
    handles = guidata(hObject);
    handles = deactivateDrag(handles);
    
    % then recreate the regions
    handles = createRegions(handles);
    
    % and redraw the linescan axes
    handles = drawLineView(handles);
    
    guidata(handles.main, handles);
end

function exportActiveRegion(hObject, ~)
    % export the active region (extract)
    handles = guidata(hObject);
    
    if ~isempty(handles.activeRegion)

        domain = [ handles.activeRegion.leftBoundary,...
                    handles.activeRegion.rightBoundary ];

        handles = readFrames(handles, domain, handles.windowPeriod); 

        toggleCalculator(handles);
        guidata(handles.main, handles);
    end
end

function mouseWheelScroll(hObject, eventdata)
    SCROLL_FACTOR = 100;
    
    % set the new slider value and run its callback
    handles = guidata(hObject);
    if handles.isLoaded
        sliderValue = get(handles.slider_lineScan, 'Value');
        newValue = sliderValue - SCROLL_FACTOR * eventdata.VerticalScrollCount;

        minValue = get(handles.slider_lineScan, 'Min');
        maxValue = get(handles.slider_lineScan, 'Max');

        newValue = min( [ max([newValue, minValue]), maxValue ] );


        set(handles.slider_lineScan, 'Value', newValue );

        slider_lineScan_Callback(handles.slider_lineScan, []);
    end
end


function resizeFigure(hObject, ~)
    handles = guidata(hObject);
    
    % if there is an image loaded then the figure should be drawn such that
    % the top view panel is the same size as the top view axes
    
    % delete all graphics handles so that they can be redrawn
    clf
    
    handles = populateGUI(handles);
    handles = createLineSlider(handles);
    guidata(hObject, handles);
    
    refreshAll(handles);
    
end

function pixelHeightChange_Callback(hObject, ~)
    handles = guidata(hObject);
    
    
    inputString = get(hObject, 'String');
    
    newHeight_px = str2double(inputString);
    if isnan(newHeight_px) || newHeight_px < handles.MINIMUM_WINDOW_PERIOD
        % invalid input, reset the edit box to the current windowPeriod
        set(hObject, 'String', sprintf('%d', handles.windowPeriod));
        return;
    end
    
    handles = heightChange(handles, newHeight_px);
    
    guidata(hObject, handles);
    
    refreshAll(handles);
end

function msHeightChange_Callback(hObject, ~)
    handles = guidata(hObject);
    
    inputString = get(hObject, 'String');
    
    newHeight_ms = str2double(inputString);
    if isnan(newHeight_ms) || newHeight_ms < handles.MINIMUM_WINDOW_PERIOD
        % invalid input, reset the edit box to the current windowPeriod
        set(hObject, 'String',...
                sprintf('%.1f', handles.windowPeriod * handles.msPerLine));
        return;
    end
    
    newHeight_px = round( newHeight_ms / handles.msPerLine );

    handles = heightChange(handles, newHeight_px);
    
    guidata(hObject, handles);
    
    refreshAll(handles);
end
%%% END CALLBACKS


%% Image Extraction/Calculation Functions 
function handles = readFrames(handles, domain, windowPeriod, forceNFrames)
    % read in image data

    frameWidth = domain(2) - domain(1) + 1;
    frameHeight = windowPeriod;
    nFrames = floor( handles.mpbus.ysize * handles.mpbus.numFrames / frameHeight );
    
    handles.exImageWidth = (domain(2) - domain(1) + 1)...
                        * handles.IMAGE_SCALE_FACTOR;
    handles.exImageHeight = windowPeriod * handles.IMAGE_SCALE_FACTOR;
    
    % forceNFrames is used for debugging purposes to only extract a set
    % amount of frames
    if exist('forceNFrames', 'var')
        nFrames = min( [forceNFrames, nFrames] );
    end
    
    % initialize a waitbar
    waitbarHandle = waitbar(0, 'Time Remaining: ',...
                            'Name', 'Extracting...',...
                            'WindowStyle', 'modal' );
    
    %exportFile = matfile(EXPORT_FILE_NAME, 'Writable', true);
    %exportFile.data = zeros(frameHeight, frameWidth, nFrames, 'int16' );
    if isfield(handles, 'exImageData') && ~isempty(handles.exImageData)
        % there is already image data loaded, just resize the exImageData
        % matrix instead of allocating a new one (this is done to prevent
        % Out Of Memory errors)
        allocatedHeight = size(handles.exImageData, 1);
        allocatedWidth = size(handles.exImageData, 2);
        dHeight = frameHeight - allocatedHeight;
        dWidth = frameWidth - allocatedWidth;
        
        adjustedHeight = allocatedHeight + dHeight;
        adjustedWidth = allocatedWidth + dWidth;
        % now resize the matrix
        if dHeight < 0
            % the height needs to be smaller
            handles.exImageData( adjustedHeight + 1 : allocatedHeight, :, : ) = [];
        else
            % the height needs to be larger
            handles.exImageData( allocatedHeight : adjustedHeight, :, : ) = 0; 
        end

        if dWidth < 0
            % the width needs to be smaller
            handles.exImageData( :, adjustedWidth + 1 : allocatedWidth, : ) = [];
        else
            % the width needs to be larger
            handles.exImageData( :, allocatedWidth : adjustedWidth, : ) = 0; 
        end

    else
        % no image data yet, allocate a new matrix
        handles.exImageData = zeros(frameHeight, frameWidth, nFrames, 'int16' );
    end
    
    handles.nFrames = nFrames;
    
    startTime = clock;
    for frameIndex = 1 : nFrames
        finishLine = frameIndex * frameHeight;
        startingLine = finishLine - frameHeight + 1;
    
        frameData = handles.mpbus.readLines(startingLine : finishLine);
        frameDataCropped = frameData(: , domain(1) : domain(2));
        
        handles.exImageData( :, :, frameIndex) = frameDataCropped;
        
        % also, calculate how much time is remaining
        currentTime = clock;
        elapsedTime = etime(currentTime, startTime);
        secondsPerFrame = elapsedTime / frameIndex;
        secondsRemaining = floor(( nFrames - frameIndex ) * secondsPerFrame);
        waitbarMessage = sprintf('About %d seconds remaining.', secondsRemaining);
        
        waitbar(frameIndex/nFrames, waitbarHandle, waitbarMessage);
    end
    
    close(waitbarHandle);
    
    set(handles.main, 'CurrentAxes', handles.axes_exImage);
    drawFrame(handles, 0, 1);  
end

%%% Drawing Functions
function eof = drawFrame(handles, nFramesToAdvance, startingFrame)
    % do not specify a frameNumber when this function is first called
    persistent frameNumber;
    
    if isempty(frameNumber)
        frameNumber = 1;
    end
    
    if ~exist('startingFrame', 'var')
        startingFrame = 1;
    else
        frameNumber = startingFrame;
    end
    if ~exist('nFramesToAdvance', 'var')
        nFramesToAdvance = 0;
    end

    % if there isn't an extracted image, don't draw anything
    if ~isfield(handles, 'exImageData') || isempty(handles.exImageData)
        return;
    end
  
    frameNumber = frameNumber + nFramesToAdvance;
    
    % check for overflow
    if frameNumber <= 0
        frameNumber = handles.nFrames;
    elseif frameNumber > handles.nFrames
        frameNumber = 1;
    end
    
    imageWidth = size(handles.exImageData, 2);
    nFrames = size(handles.exImageData, 3);

    if frameNumber == nFrames
        % this is the last frame, return end of file (eof)
        eof = true;
    elseif frameNumber > nFrames
        % beyond the last frame
        frameNumber = 1;
        eof = true;
        return; 
    else
        eof = false;
    end
    set(handles.main, 'CurrentAxes', handles.axes_exImage);
    imagesc(handles.exImageData(:,:,frameNumber));
    axis image
    axis off
    colormap(handles.colormap); 

    % also draw any calculation results
    if isfield(handles, 'diameter') && ~isempty(handles.diameter)
        diameterStruct = handles.diameter(frameNumber);
        
        set(handles.main, 'CurrentAxes', handles.axes_results);
        set(handles.axes_results, 'Visible', 'on');
        cla
        plot(diameterStruct.image);
        set(gca,'xtick',[], 'ytick',[], 'xlim', [1, imageWidth]);
        hold on
        
        % draw the FWHM lines as well (unless this datapoint is rejected)
        if isnan(diameterStruct.fwhm)
            % rejected data -- cross out the results axes
            X = xlim;
            Y = ylim;
            
            line([X(1), X(2)], [Y(1), Y(2)], 'Linestyle', '-', 'Color', 'black');
            line([X(1), X(2)], [Y(2), Y(1)], 'Linestyle', '-', 'Color', 'black');
            
        else
            % good data
            X = [ diameterStruct.leftWidthPoint, ...
                diameterStruct.rightWidthPoint ];

            Y = ylim;

            line([X(1), X(1)], Y, 'Linestyle', ':', 'Color', 'black');
            line([X(2), X(2)], Y, 'Linestyle', ':', 'Color', 'black');

            % and the Gaussian fit
            coefficients = diameterStruct.coefficients;
            if ~isempty(coefficients)
                a = coefficients(1);
                b = coefficients(2);
                c = coefficients(3);

                gaussX = 1 : length(diameterStruct.image);
                gaussY = a * exp( -1/2 .* ( (gaussX - b) ./ c ).^2 );

                plot(gaussX, gaussY, 'r');
            end
        end
    elseif isfield(handles, 'velocity') && ~isempty(handles.velocity)
        
        % draw a line on the image at the angle determined by the Radon
        % transform
        theta = handles.velocity(frameNumber).angle;
        domain = xlim;
        range = ylim;
        width = domain(2) - domain(1);
        height = range(2) - range(1);

        if isnan(theta)
            % rejected datapoint -- cross out the image axes
            X = domain;
            Y = range;
            line([X(1), X(2)], [Y(1), Y(2)], ...
                'Linestyle', '-', 'Color', 'black', 'LineWidth', 4);
            line([X(1), X(2)], [Y(2), Y(1)], ...
                'Linestyle', '-', 'Color', 'black', 'LineWidth', 4);
            
            x_text = width/4;
            y_text = height * 3/4;
            text('Position', [x_text, y_text],...
                'BackgroundColor', 'white',... 
                'String', '-----------');
            
        else
            % good data
            lineLength = width/2;
            x_start = width/2;
            y_start = height/2;
            y_end = y_start - lineLength * sin(theta);
            x_end = x_start + lineLength * cos(theta);

            line([x_start, x_end], [y_start, y_end], ...
                    'Color', 'cyan',...
                    'LineWidth', 4);

            angleString = sprintf('%0.3f \\pi', theta/pi);
            x_text = width/4;
            y_text = height * 3/4;
            text('Position', [x_text, y_text],...
                'BackgroundColor', 'white',... 
                'String', angleString);
        end
      
        % display velocity results
        set(handles.main, 'CurrentAxes', handles.axes_results);
        set(handles.axes_results, 'Visible', 'on');
        
        cla
         
        if length(handles.velocity) >= frameNumber
            imagesc( transpose(handles.velocity(frameNumber).transform) );
            set(handles.axes_results, ...
                'YTick', [1, 45, 90, 135, 179],...
                'YTickLabel', {'0', '1/4 pi', '1/2 pi', '3/4 pi', 'pi'},...
                'XTick', []);
            colormap(handles.colormap);
        end
    end
    
    set(handles.edit_frameNumber, 'String', frameNumber);
end

function animateFrames(~, ~, handles)
    eof = drawFrame(handles, 1);
    
    if eof
        play_callback(handles.main, []);
    end
end
%%% CALLBACKS
function play_callback(hObject, ~)
    persistent lastCommandIsPlay;
    MAX_FPS = 60;
    MIN_FPS = 1;
    
    handles = guidata(hObject);
    
    % get the requested frames per second
    fps = str2double(get(handles.edit_fps, 'String'));
    if isnan(fps)
        fps = handles.DEFAULT_FPS;
    else
        % ensure fps is between the min and max allowed fps
        fps = min( [ max( [fps, MIN_FPS] ), MAX_FPS ] ); 
    end
    
    set(handles.edit_fps, 'String', fps);

    if ~isfield(handles, 'animationTimer')
        handles.animationTimer = timer(...
           'ExecutionMode','fixedRate',...  
           'Period', ceil(1000/fps)/1000,...
           'TimerFcn',{@animateFrames,handles});
    end
    
    if isempty(lastCommandIsPlay)
        lastCommandIsPlay = false;
    end
    
    if lastCommandIsPlay
        stop(timerfind);
        lastCommandIsPlay = false;
        set(handles.button_play, 'String', '>');
    else
        lastCommandIsPlay = true;
        start(handles.animationTimer);
        set(handles.button_play, 'String', '| |');
    end    
end

function next_callback(hObject, ~)
    handles = guidata(hObject);
    drawFrame(handles, 1);
end

function previous_callback(hObject, ~)
    handles = guidata(hObject);
    drawFrame(handles, -1);
end

function first_callback(hObject, ~)
    handles = guidata(hObject);
    drawFrame(handles, 0, 1);
end

function last_callback(hObject, ~)
    handles = guidata(hObject);
    drawFrame(handles, 0, handles.nFrames);
end

function toggleCalculator(handles, forceClear)

    if ~exist('forceClear', 'var')
        forceClear = false;
    end
    
    % if there is no extracted image data, hide all the calculator controls
    calcHandles = findall(handles.panel_calculator, 'Tag', 'calculator');
    extractHandles = findall(handles.main, 'Tag', 'extract');
    if forceClear || ~isfield(handles, 'exImageData') || isempty(handles.exImageData)
        set(calcHandles, 'Visible', 'off');
        set(extractHandles, 'Visible', 'on');
    else
        set(calcHandles, 'Visible', 'on');
        set(extractHandles, 'Visible', 'off');
    end
    

end

function clearCalculator(hObject, ~)
    % used to remove the extracted image and return the calculator panel to
    % its opening state -- just a button in the middle that lets users
    % extract an image from the scan data
    handles = guidata(hObject);
    
    % clear both calculator axes
    cla(handles.axes_exImage);
    cla(handles.axes_results);
    
    % then hide all the calculator controls
    set(handles.popup_calculate, 'Value', 1);
    set(handles.axes_results, 'Visible', 'off');
    set(handles.button_reject, 'Enable', 'off');
    handles.diameter = [];
    handles.velocity = [];
    toggleCalculator(handles, true);
    
    
    guidata(hObject, handles);
end

function handles = clearResults(handles)
% remove any diameter, intensity, or velocity calculations (always called
% before a new calculation begins)

    handles.diameter = [];
    handles.intensity = [];
    handles.velocity = [];
end

function saveCalculator(hObject, ~)
    disp('save is not functional yet');
end

function popupCalculate(hObject, ~)
    handles = guidata(hObject);
    
    selectedIndex = get(hObject, 'Value');
    items = get(hObject, 'String');
    
    selectedItem = items{selectedIndex};
    
    s = handles.calculateOptions;
    switch selectedItem
        case s.diameter
            calculateDiameter(hObject, []);
        case s.velocity
            calculateVelocity(hObject, []);
        case s.intensity
            calculateIntensity(hObject, []);
        otherwise
            return;
    end
end

function loadSample(hObject, ~)
    % used to test the Calculator panel without having to use actual data
    handles = guidata(hObject);
    clearCalculator(hObject, []);
    
    THICKNESS = 5;
    width = 50;
    height = 100;
    nFrames = 50;

    function frame = makeFrame(theta)
        % dy/dx = tan(theta)
        % let dy = 1, then dx = 1 / tan(theta)
        % basically, step down through the matrix and on each horizontal line,
        % draw a dashed line, then shift this dashed line by dx for the next
        % horizontal position.
        dx = 1 / tan(theta);    % this is the amount each line gets shifted

        dashedLine = zeros( width, 1 );
        dashedLine( : ) = 0.2;
        pixelIndex = 1;
        while pixelIndex <= (width - THICKNESS)
            dashedLine( pixelIndex : (pixelIndex - 1 + THICKNESS) ) = 1;
            pixelIndex = pixelIndex + ( 2 * THICKNESS );
        end

        frame = zeros(width, height, 'int16' );
        for lineIndex = 1 : height
            shiftAmount = round( dx * lineIndex );
            frame( :, lineIndex ) = circshift( dashedLine, shiftAmount );
        end

        % reorient the frame so that the lines are at an angle relative to the
        % positive horizontal (x) axis.
        frame = flipud(transpose(frame));
    end

    % the starting angle is random, after that the angle is incremented by
    % a small amount on each frame
    
    angle = rand * 2 * pi;
    angle = pi / 2 + 0.05;  % TESTING
    fprintf('Test Image created with lines at an intial angle of %.1f degrees.\n', angle * 180 / pi );
    
    
    fullImage = zeros(height, width, nFrames);
    for frameIndex = 1 : nFrames
        cframe = makeFrame(angle);
        fullImage(:, :, frameIndex) = cframe;
        
        % continuously vary the angle
        angle = angle + 0.01;
    end
    
    handles.exImageData = fullImage;
    handles.exImageWidth = width;
    handles.exImageHeight = height;
    handles.nFrames = nFrames;
    guidata(hObject, handles);
    
    % show the calculator panel
    toggleCalculator(handles);
     
    guidata(handles.main, handles);
    
    
    set(handles.main, 'CurrentAxes', handles.axes_exImage);
    drawFrame(handles, 0, 1);  

end

function smallExportActiveRegion(hObject, ~)
    % export the active region (extract)
    handles = guidata(hObject);
    SAMPLE_SIZE = 100;
    
    if ~isempty(handles.activeRegion)

        domain = [ handles.activeRegion.leftBoundary,...
                    handles.activeRegion.rightBoundary ];

        handles = readFrames(handles, domain, handles.windowPeriod, SAMPLE_SIZE); 

        toggleCalculator(handles);
        guidata(handles.main, handles);
    end    
end

function rejectFrames(hObject, ~)
    handles = guidata(hObject);
    % activates the rejection rules --
    % for velocity: reject angles at pi/2
    % for diameter: reject outliers ( > 3 standard deviations )
    % rejections are handled by replacing the relevant value with NaN
    % NaNs can then be skipped or interpolated
    
    questionString = [ 'Do you want to interpolate over the rejected frames? ' ...
                        'WARNING: There will be no way to tell which frames '...
                        'were rejected if you choose to interpolate.' ];
    answer = questdlg(questionString, 'Reject Frames');
    
    switch answer
        case 'Yes'
            doInterpolate = true;
        case 'No'
            doInterpolate = false;
        otherwise
            doInterpolate = false;
    end
    
    nRejected = 0;
    if isfield(handles, 'diameter') && ~isempty(handles.diameter)
        
        diameterVector = [ handles.diameter.fwhm ];
        meanDiameter = mean( diameterVector );
        threshold = std( diameterVector ) * handles.OUTLIER_SIGMA;
        nFrames = length(diameterVector);
        
        for frameIndex = 1 : nFrames
            if diameterVector(frameIndex) >= meanDiameter + threshold || ...
                diameterVector(frameIndex) <= meanDiameter - threshold
                % this is an outlier
                handles.diameter(frameIndex).fwhm = NaN;
                nRejected = nRejected + 1;
            end
        end
        
        %TODO: diameter interpolation -- need to handle left and right
        %boundary somehow (interpolate these as well?)

    elseif isfield(handles, 'velocity') && ~isempty(handles.velocity)
    
        angleVector = [ handles.velocity.angle ];
        minAngle = handles.REJECT_ANGLE_RANGE(1) * pi;
        maxAngle = handles.REJECT_ANGLE_RANGE(2) * pi;
        
        nFrames = length(angleVector);
        for frameIndex = 1 : nFrames
            if angleVector(frameIndex) >= minAngle && ...
                angleVector(frameIndex) <= maxAngle
                
                % reject this datapoint
                handles.velocity(frameIndex).angle = NaN;
                nRejected = nRejected + 1;
            end
        end
        
        % now interpolate over the rejected values
        if doInterpolate
            rejected = isnan(angleVector);
            t = 1 : length(angleVector);
            angleVector(rejected) = interp1( ...
                    t(~rejected), angleVector(~rejected), t(rejected) );
                
            % handle the boundaries of the vector (the above interpolation
            % will not work on the first and last element)
            if isnan(angleVector(end))
                angleVector(end) = angleVector(nFrames - 1);
            end
            if isnan(angleVector(1))
                angleVector(1) = angleVector(2);
            end
            % can't figure out how to vectorize an assignment to a struct
            % array, using a for loop for now
            for frameIndex = 1 : nFrames
                handles.velocity(frameIndex).angle = angleVector(frameIndex);
            end
        end
    end
    
    if nRejected == 1
        messageString = sprintf('1 frame out of %d rejected.', nFrames);
    else
        messageString = sprintf('%d frames out of %d rejected', nRejected, nFrames);
    end
    
    helpdlg(messageString, 'Finished Rejecting Frames');
    
    guidata(hObject, handles);
end

%% GUI Creation Functions

function handles = createLineSlider(handles, range)
    persistent lastRange;
    %check to see if the slider already exists then create a new one
    
    % the range and tick arguments are optional, set them to default values
    % if they weren't specified
    if ~exist('range', 'var')
        if ~isempty(lastRange)
            range = lastRange;
        else
            range = 1:100;
        end
    end
    
    lastRange = range;
    
    TICKS_CLICK = 10;
    TICKS_DRAG = 100;
    
    NORMAL_BUFFER = 0;
    
    if isfield(handles, 'slider_lineScan') && ishghandle(handles.slider_lineScan)
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
        'SliderStep', [TICKS_CLICK/maxValue , TICKS_DRAG/maxValue ]);
end

% TODO: Seperate createGUI into at least two functions so that controls can be
% redrawn to correct size when the window is resized
function handles = createGUI()
    handles.BUTTON_WIDTH = 80;
    handles.BUTTON_HEIGHT = 25;

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
    'Visible','on',...
    'WindowScrollWheelFcn', @mouseWheelScroll);

    
    handles = populateGUI(handles);


end

function handles = populateGUI(handles)
    % this function is called when the GUI is created (from createGUI) and
    % every time the figure is resized.
    % imageWidth is passed in when data is loaded so that the panel
    % containing the axes is correctly sized

    % all variables/constants that determine graphics object placement on
    % the figure will be assigned here:
    handles.BUTTON_WIDTH = 80;
    handles.BUTTON_HEIGHT = 25;
    handles.PADDING = 10;

    % create vertical and horizontal "anchors"
    figurePixelPosition = getpixelposition(handles.main);
    figureSize = [ figurePixelPosition(3), figurePixelPosition(4) ];
    
    % horizontal anchor
    hAnchor = figureSize(2) / 2.5;
    
    
%%% TOP VIEW    
    topView_x = handles.PADDING;
    topView_y = hAnchor;
    topView_height = (figureSize(2) - hAnchor) - handles.PADDING;
    topView_width = topView_height;         % assuming square image
    
    handles.panel_topView = uipanel(...
        'Parent',handles.main,...
        'Title','Top Down View',...
        'Clipping','on',...
        'Units', 'pixels',...
        'Position',[ topView_x, topView_y, topView_width, topView_height ],...
        'Tag','panel_topView' );
    
    topAxesPadding = handles.PADDING / topView_width;
    handles.axes_topView = axes(...
        'Parent',handles.panel_topView,...
        'Units', 'normalized',...
        'Position',[topAxesPadding, topAxesPadding, (1 - topAxesPadding), (1 - topAxesPadding)],...
        'XTick', [],...
        'YTick', [],...
        'Tag','axes_topView' );
%%%

%%% CONTROL PANEL
 % create the selected region and path info panels
    cp_x = topView_x + topView_width;
    cp_y = hAnchor;
    cp_width = handles.BUTTON_WIDTH * 2;
    cp_height = (figureSize(2) - hAnchor) - handles.PADDING;
    handles.panel_control = uipanel(...
        'Parent',handles.main,...
        'Title','Selected Region',...
        'Clipping','on',...
        'Units', 'pixels',...
        'Position',[cp_x cp_y cp_width cp_height],...
        'Tag','panel_control' );
%%%

%%% CALCULATION PANEL
    x = cp_x + cp_width;
    y = hAnchor;
    width = figureSize(1) - x - handles.PADDING;
    height = topView_height;
    handles.panel_calculator = uipanel(...
        'Parent',handles.main,...
        'Title','Calculations',...
        'Clipping','on',...
        'Units', 'pixels',...
        'Position',[ x, y, width, height ],...
        'Tag','panel_calculator' );
%%%

%%% LINE SCAN
    x = handles.PADDING;
    y = handles.PADDING;
    width = figureSize(1) - handles.PADDING;
    height = hAnchor - handles.PADDING;
    handles.panel_lineScan = uipanel(...
        'Parent',handles.main,...
        'Title','Scan Data',...
        'Clipping','on',...
        'Units', 'pixels',...
        'Position',[x y width height],...
        'Tag','panel_lineScan' );
    lsPadding = handles.PADDING / width;
    handles.axes_lineScan = axes(...
        'Parent',handles.panel_lineScan,...
        'Position',[lsPadding 0.088 0.955 0.9],...
        'XTick', [],...
        'YTick', [],...
        'Tag','axes_lineScan' );
%%%

    handles = populateControlPanel(handles);
    handles = populateCalculationPanel(handles);
    handles = createMenu(handles);
    
end

function handles = createMenu(handles)

%%% UI MENU
handles.menu_file = uimenu(...
    'Parent',handles.main,...
    'Label','File',...
    'Tag','menu_file' );

handles.menu_open = uimenu(...
    'Parent',handles.menu_file,...
    'Accelerator','O',...
    'Callback',@loadScanFile,...
    'Label','Open...',...
    'Tag','menu_open' );

handles.menu_convert = uimenu(...
    'Parent',handles.menu_file,...
    'Callback',@convertFile,...
    'Label','Convert MPD to HDF5...',...
    'Tag','menu_convert' );

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

handles.menu_debug = uimenu(...
    'Parent',handles.main,...
    'Label','Debug',...
    'Tag','menu_debug' );

handles.menu_loadSample = uimenu(...
    'Parent',handles.menu_debug,...
    'Label','Load Sample Data',...
    'Callback', @loadSample,...
    'Tag','menu_debug' );

handles.menu_smallExtract = uimenu(...
    'Parent',handles.menu_debug,...
    'Label','Extract first 100 frames',...
    'Callback', @smallExportActiveRegion,...
    'Tag','menu_debug' );
%%%
end

function handles = populateControlPanel(handles)
    

    panel_bounds = getpixelposition(handles.panel_control);

    buttonWidth = handles.BUTTON_WIDTH / panel_bounds(3);
    buttonHeight = handles.BUTTON_HEIGHT / panel_bounds(4);
    padding_x = 2 / panel_bounds(3);
    padding_y = 2 / panel_bounds(4);
    
    column1_x = 0.1;
    column2_x = 0.6;
    labelWidth = 0.9;
    labelHeight = buttonHeight;
    editWidth = 35 / panel_bounds(3);
    editHeight = 20 / panel_bounds(4);
    unitsWidth = 20 / panel_bounds(3);
    unitsHeight = labelHeight;

    rowY = 1 - ( 0.2 : labelHeight : 0.9 );
    %%% REGION WIDTH
    handles.label_regionWidth = uicontrol(...
        'Parent', handles.panel_control,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ column1_x, rowY(1), labelWidth, labelHeight ],...
        'Tag','activeRegionControl',...
        'HorizontalAlignment', 'left',...
        'String', 'Region Width (space)',...
        'Enable','off' );

    handles.edit_regionWidth_px = uicontrol(...
        'Parent', handles.panel_control,...
        'Style', 'edit',...
        'Units', 'normalized',...
        'BackgroundColor', 'white',...
        'Position', [ column1_x, rowY(2) + 4 * padding_y, editWidth, editHeight ],...
        'Tag','activeRegionControl_inactive',...
        'String', '',...
        'Enable','off' );

    handles.label_regionWidth_px = uicontrol(...
        'Parent', handles.panel_control,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ column1_x + editWidth, rowY(2), unitsWidth, unitsHeight ],...
        'Tag','activeRegionControl',...
        'String', 'px',...
        'Enable','off' );

    handles.edit_regionWidth_mv = uicontrol(...
        'Parent', handles.panel_control,...
        'Style', 'edit',...
        'Units', 'normalized',...
        'BackgroundColor', 'white',...
        'Position', [ column2_x, rowY(2) + 4 * padding_y, editWidth, editHeight ],...
        'Tag','activeRegionControl_inactive',...
        'String', '',...
        'Enable','off' );

    handles.label_regionWidth_mv = uicontrol(...
        'Parent', handles.panel_control,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ column2_x + editWidth, rowY(2), unitsWidth, unitsHeight ],...
        'Tag','activeRegionControl',...
        'String', 'mV',...
        'Enable','off' );
    %%% END REGION WIDTH
    
    %%% REGION HEIGHT
     handles.label_regionHeight = uicontrol(...
        'Parent', handles.panel_control,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ column1_x, rowY(4), labelWidth, labelHeight ],...
        'Tag','activeRegionControl',...
        'HorizontalAlignment', 'left',...
        'String', 'Region Height (time)',...
        'Enable','off' );

    handles.edit_regionHeight_px = uicontrol(...
        'Parent', handles.panel_control,...
        'Style', 'edit',...
        'Units', 'normalized',...
        'BackgroundColor', 'white',...
        'Position', [ column1_x, rowY(5) + 4 * padding_y, editWidth, editHeight ],...
        'Tag','activeRegionControl',...
        'Callback', @pixelHeightChange_Callback,...
        'String', '',...
        'Enable','off' );

    handles.label_regionHeight_px = uicontrol(...
        'Parent', handles.panel_control,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ column1_x + editWidth, rowY(5), unitsWidth, unitsHeight ],...
        'Tag','activeRegionControl',...
        'String', 'px',...
        'Enable','off' );
    
    handles.edit_regionHeight_ms = uicontrol(...
        'Parent', handles.panel_control,...
        'Style', 'edit',...
        'Units', 'normalized',...
        'BackgroundColor', 'white',...
        'Position', [ column2_x, rowY(5) + 4 * padding_y, editWidth, editHeight ],...
        'Tag','activeRegionControl',...
        'Callback', @msHeightChange_Callback,...
        'String', '',...
        'Enable','off' );

    handles.label_regionHeight_ms = uicontrol(...
        'Parent', handles.panel_control,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ column2_x + editWidth, rowY(5), unitsWidth, unitsHeight ],...
        'Tag','activeRegionControl',...
        'String', 'ms',...
        'Enable','off' );
    
    %%% END REGION HEIGHT

   
    %%%
    
end

function handles = populateCalculationPanel(handles)
    MAX_MAGNIFICATION = 3;      % don't enlarge the image by a factor any
                                % larger than this
    
   handles.DEFAULT_FPS = 12;
   
    function htmlString = makeHTML(stringIn)
        htmlString = sprintf('<HTML><b>&nbsp;&nbsp;&nbsp;%s</b></HTML>', stringIn);
    end
   
   % the calculateOptions struct is used to populate the popupmenu that
   % users can use to run a calculation
   handles.calculateOptions = struct(...
       'head', 'Calculate...', ...
       'diameter', makeHTML('Diameter'),...
       'velocity', makeHTML('Velocity'),...
       'intensity', makeHTML('Intensity') );
                                
   
   %NOTE: testing
   handles.exImageWidth = 40;
   handles.exImageHeight = 100;
   % end testing
   
   % working width and height are the dimensions of the area that can be
   % used by the calculation graphics objects
   calculationPanelPosition = getpixelposition(handles.panel_calculator);
   workingWidth = calculationPanelPosition(3);
   workingHeight = calculationPanelPosition(4);
    
    %%% Control Panel
    panelWidth = (handles.BUTTON_WIDTH * 2) / workingWidth;
    panelHeight = 0.7; 
    
    editWidth = 50 / ( panelWidth * workingWidth );
    editHeight = 20 / ( panelHeight * workingHeight );
    labelWidth = 2 * editWidth;
    labelX = 0;
    editX = labelX + labelWidth + 2 * handles.PADDING / workingWidth;
    yLocations = 1 - (1:12) * editHeight;
    
    buttonWidth = labelWidth / 2 + editWidth;
    buttonHeight = 1.5 * editHeight;
    buttonX = (labelX + editX) / 2;
    
    handles.panel_calcControl = uipanel(...
    'Parent',handles.panel_calculator,...
    'Clipping','off',...
    'BorderType','none',...
    'Position',[0 0.2 panelWidth panelHeight],...
    'Tag','panel_controls' );

    handles.label_frameNumber = uicontrol(...
        'Parent', handles.panel_calcControl,...
        'Style', 'text',...
        'Units', 'normalized',...
        'HorizontalAlignment', 'right',...
        'Position', [ labelX yLocations(1) labelWidth editHeight ],...
        'String', 'Frame',...
        'Tag', 'calculator');

    handles.edit_frameNumber = uicontrol(...
        'Parent', handles.panel_calcControl,...
        'Style','edit',...
        'Units', 'normalized',...
        'Enable', 'inactive',...
        'Position', [editX yLocations(1) editWidth editHeight],...
        'Tag', 'calculator' );
    
    handles.label_fps = uicontrol(...
        'Parent', handles.panel_calcControl,...
        'Style', 'text',...
        'Units', 'normalized',...
        'HorizontalAlignment', 'right',...
        'Position', [ labelX yLocations(3) labelWidth editHeight ],...
        'String', 'FPS',...
        'Tag', 'calculator' );

    handles.edit_fps = uicontrol(...
        'Parent', handles.panel_calcControl,...
        'Style','edit',...
        'Units', 'normalized',...
        'BackgroundColor', 'white',...
        'String', handles.DEFAULT_FPS,...
        'Position', [editX yLocations(3) editWidth editHeight],...
        'Tag', 'calculator' );
    
    handles.button_save = uicontrol(...
        'Parent', handles.panel_calcControl,...
        'Style', 'pushbutton',...
        'Units', 'normalized',...
        'String', 'Save',...
        'Callback', @saveCalculator,...
        'Position', [ buttonX yLocations(5) buttonWidth buttonHeight ],...
        'Tag', 'calculator' );
    
    handles.button_clear = uicontrol(...
        'Parent', handles.panel_calcControl,...
        'Style', 'pushbutton',...
        'Units', 'normalized',...
        'String', 'Clear',...
        'Callback', @clearCalculator,...
        'Position', [ buttonX yLocations(7) buttonWidth buttonHeight ],...
        'Tag', 'calculator' );
        
    popupX = (labelX + editX) / 2;
    popupWidth = labelWidth / 2 + editWidth;
    s = handles.calculateOptions;
    handles.popup_calculate = uicontrol(...
        'Parent', handles.panel_calcControl,...
        'BackgroundColor', 'white',...
        'Style', 'popupmenu',...
        'Units', 'normalized',...
        'Callback', @popupCalculate,...
        'String', {s.head, s.diameter, s.velocity, s.intensity},...
        'Position', [ popupX, yLocations(9), popupWidth, editHeight ],...
        'Tag', 'calculator' );
    
    handles.button_reject = uicontrol(...
        'Parent', handles.panel_calcControl,...
        'Style', 'pushbutton',...
        'Units', 'normalized',...
        'String', 'Reject Frames...',...
        'Callback', @rejectFrames,...
        'Position', [ buttonX yLocations(12) buttonWidth buttonHeight ],...
        'Tag', 'calculator', ...
        'Enable', 'off' );
  
    %{
    buttonWidth = handles.BUTTON_WIDTH / panelWidth;
    buttonHeight = handles.BUTTON_HEIGHT / panelHeight;
    handles.button_export = uicontrol(...
        'Parent',handles.panel_calcControl,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[(1-buttonWidth)/2, 0.1, buttonWidth, buttonHeight],...
        'String','Extract',...
        'Callback',@exportActiveRegion,...
        'Tag','activeRegionControl',...
        'Enable','off' );
   %}
    %%% END Control Panel
    
    %%% Main Axes
    % THIS IS THE ONLY GRAPHICS OBJECT THAT IS IN UNITS OF PIXELS (other
    % than the figure itself)
    % the maximum axes height is the control panel height (in pixels)
    controlPanelBounds = getpixelposition(handles.panel_calcControl);
    panelPixelWidth = controlPanelBounds(3);
    panelPixelHeight = controlPanelBounds(4);
    panelPixelX = controlPanelBounds(1);
    panelPixelY = controlPanelBounds(2);
    
    heightScale = panelPixelHeight / handles.exImageHeight;
    widthScale = panelPixelWidth / handles.exImageWidth;
    
    % choose the smallest scale factor as the overall magnification
    % (with an upper bound set by MAX_MAGNIFICATION)
    magnification = min( [heightScale, widthScale, MAX_MAGNIFICATION] );
    
    
    axesHeight = handles.exImageHeight * magnification;
    axesWidth = handles.exImageWidth * magnification;
    axesX = panelPixelX + panelPixelWidth;
    axesY = panelPixelY;
   
    axesNormCenterX = ( axesX + 0.5 * axesWidth ) / workingWidth;
    
    handles.axes_exImage = axes(...
        'Parent',handles.panel_calculator,...
        'Units','pixels',...
        'Position',[axesX axesY axesWidth axesHeight],...
        'XTick', [],...
        'YTick', [],...
        'Tag', 'calculator' );
    
    % also create an axes for calculation results
    handles.axes_results = axes(...
        'Parent',handles.panel_calculator,...
        'Units','pixels',...
        'Position',[(axesX + axesWidth + 50) axesY axesWidth axesHeight],...
        'XTick', [],...
        'YTick', [],...
        'Visible', 'off' );
    
    %%% END Main Axes
   
    
    %%% Movie Buttons
    
    buttonPixelWidth = 25;
    buttonPixelHeight = 25;
    
    panelPixelWidth = 5 * ( buttonPixelWidth + handles.PADDING );
    panelPixelHeight = buttonPixelHeight + 2 * handles.PADDING;
    
    panelWidth = panelPixelWidth / workingWidth;
    panelHeight = panelPixelHeight / workingHeight;
    
    panelX = axesNormCenterX - 0.5 * panelWidth;
    panelY = 0.05;
    buttonWidth = buttonPixelWidth / panelPixelWidth;
    buttonHeight = buttonPixelHeight / panelPixelHeight;
    
    buttonY = handles.PADDING / panelPixelHeight;
    playX = (1 - buttonWidth) / 2;
    nextX = playX + buttonWidth + 0.01;
    previousX = playX - buttonWidth - 0.01;
    lastX = playX + 2 * ( buttonWidth + 0.01 );
    firstX = playX - 2 * ( buttonWidth + 0.01 );
    
    
    handles.panel_movie = uipanel(...
        'Parent',handles.panel_calculator,...
        'Clipping','off',...
        'Position',[panelX panelY panelWidth panelHeight],...
        'Tag', 'calculator' );

    handles.button_play = uicontrol(...
        'Parent',handles.panel_movie,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[playX buttonY buttonWidth buttonHeight],...
        'Callback', @play_callback,...
        'String','>' );
    
    handles.button_next = uicontrol(...
        'Parent',handles.panel_movie,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[nextX buttonY buttonWidth buttonHeight],...
        'Callback', @next_callback,...
        'String','>>' );
    
    handles.button_previous = uicontrol(...
        'Parent',handles.panel_movie,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[previousX buttonY buttonWidth buttonHeight],...
        'Callback', @previous_callback,...
        'String','<<' );
    
    handles.button_first = uicontrol(...
        'Parent',handles.panel_movie,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[firstX buttonY buttonWidth buttonHeight],...
        'Callback', @first_callback,...
        'String','|<<' );

    handles.button_last = uicontrol(...
        'Parent',handles.panel_movie,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[lastX buttonY buttonWidth buttonHeight],...
        'Callback', @last_callback,...
        'String','>>|' );
    %%% END Movie Buttons
    
    
    %%% EXTRACT BUTTON (only visible when nothing has been extracted yet)
    panelBounds = getpixelposition(handles.panel_calculator);
    
    width = 2 * handles.BUTTON_WIDTH / panelBounds(3);
    height = handles.BUTTON_HEIGHT / panelBounds(4);
    x = (1 - width) / 2;
    y = (1 - height) / 2;
    handles.button_extract = uicontrol(...
        'Parent', handles.panel_calculator,...
        'Style', 'pushbutton',...
        'Units','normalized',...
        'String', 'Extract Selected Region',...
        'Position',[ x y width height],...
        'Callback', @exportActiveRegion,...
        'Enable', 'off',...
        'Tag', 'extract');
    %%%
    
    
    toggleCalculator(handles);
   
end