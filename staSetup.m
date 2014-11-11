function [success, stimVector, pixelsLeft, pixelsRight] = staSetup( mpbus )
%STASETUP Summary of this function goes here
%   Detailed explanation goes here

    handles = createGUI();
    
    % ensure the handles struct always has these fields

    handles.success = false;
    handles.mpbus = mpbus;
    handles.dragIsActive = false;
    handles.rawStimVector = readAnalog(handles);
    handles.stimVector = [];
    handles.reducedStimVector = [];
    handles.pixelsLeft = 1;
    handles.pixelsRight= 1;
    
    handles.LIGHT_RED = [1,0.8,0.8];
    handles.LIGHT_GREEN = [0.8,1,0.8];
   
    
    % set the threshold based on the rawStimVector that was just read in
    handles = setThreshold(handles, max(handles.rawStimVector) / 2);
    
    handles = populateGUI(handles);
    
    % return values for premature close
    success = false;
    stimVector = [];
    
    % if rawStimVector is empty then there was no analog data found
    if isempty(handles.rawStimVector)
        warndlg('No analog channel was found in the HDF5 file.');
        close(handles.main);
        return;
    end
    
    drawStimVector(handles);

    

    set(handles.main, 'ResizeFcn', @resize_Callback);
    set(handles.main, 'WindowButtonMotionFcn', @mouse_Callback);
    set(handles.main, 'WindowButtonUpFcn', @click_Callback);
    
    % and guess how big the stim window should be -- how many
    % pixels to the left and right of each stimulus point
    guessWidth = length(handles.rawStimVector) / 100;
    handles = setPixelsLeft(handles, guessWidth);
    handles = setPixelsRight(handles, guessWidth);
    
    % save the handles struct
    guidata(handles.main, handles);
    
   

    % do not return anything until the user has clicked Ok or Cancel
    uiwait(handles.main);
    
    % the rest of this code will execute once the user has clicked Ok or Cancel
    
    % make sure the figure hasn't already been closed
    if ishghandle(handles.main)
        % get the latest copy of handles
        handles = guidata(handles.main);

        % set return values and close
        stimVector = handles.stimVector;
        success = handles.success;
        pixelsLeft = handles.pixelsLeft;
        pixelsRight = handles.pixelsRight;

        close(handles.main);
    end
    
end

function drawStimVector(handles)
    persistent thresholdLine;

    set(handles.main, 'CurrentAxes', handles.axes_main);
    cla
    
    % draw the stim windows first so that they are in the background
    drawStimWindows(handles);
    
    % draw the raw stim vector
    l = length(handles.rawStimVector);
    
    hold on
    plot(1:l, handles.rawStimVector, 'ButtonDownFcn', @click_Callback);
    hold off
    
    set(handles.axes_main,...
        'YTick', [],...
        'ButtonDownFcn', @click_Callback);
    
    % draw the threshold line
    y = handles.threshold;
    if isempty(thresholdLine) || ~ishghandle(thresholdLine)
        thresholdLine = line(xlim, [y y],...
            'Color', 'red',...
            'LineStyle', ':',...
            'ButtonDownFcn', @click_Callback);
    else
        set(thresholdLine, 'YData', [y y], 'LineStyle', ':');
    end
    
    % draw the stim vector (all the elements from the raw stim vector that
    % are bigger than the threshold)
    
    hold on
    plot(1:l, handles.stimVector, 'or', 'ButtonDownFcn', @click_Callback);
    hold off
    
end

function drawStimWindows(handles)
    % draw a box to the left and to the right of every stimulus point

    lastRectangles = findall(handles.axes_main, 'Tag', 'windowRectangle');
    delete(lastRectangles);
    
    centerPoints = handles.reducedStimVector;
    y = 0;
    height = handles.threshold;
    
    width_left = handles.pixelsLeft;
    width_right = handles.pixelsRight;
    X_left = centerPoints - width_left;
    X_right = centerPoints;
    
    
    for index = 1 : length(centerPoints)
        
        rectangle('Position', [X_left(index), y, width_left, height],...
                  'Tag', 'windowRectangle',...
                  'Parent', handles.axes_main,...
                  'FaceColor', handles.LIGHT_GREEN);
              
        rectangle('Position', [X_right(index), y, width_right, height],...
                  'Tag', 'windowRectangle',...
                  'Parent', handles.axes_main,...
                  'FaceColor', handles.LIGHT_RED); 
        
    end
end

function stimVector = readAnalog(handles)
    % read the analog channel from the mpbus -- this is the stim vector
    analogChannelList = handles.mpbus.analogChannelList;

    nChannels = length(analogChannelList);
    stimVector = [];
    if nChannels > 1
        % user needs to choose which analog channel to use
        %TODO: Finish this case
        analogChannel = analogChannelList(1);
    elseif nChannels == 1
        % only one analog channel, use it
        analogChannel = analogChannelList(1);
    else
        % no analog channels
        disp('No analog channel was found in the HDF5 file.');
        
        return;
    end
    
    stimVector = handles.mpbus.readAnalog( analogChannel );
    
end


function closeGUI(hObject, ~, isOK)
    % iff the user clicked 'Ok' then isOK is true

    handles = guidata(hObject);
    
    if isOK
        handles.success = true;
    else
        handles.success = false;
    end
    
    guidata(handles.main, handles);
    
    uiresume(handles.main);
end

function handles = setThreshold(handles, newThreshold)

    if newThreshold <= 0
        return;
    end
    
    handles.threshold = newThreshold;

    % also, build the stim vector using only elements from the raw stim
    % vector that are bigger than the threshold
    stimVector = handles.rawStimVector;
    stimVector(stimVector < newThreshold) = 0;

    
    stimIndicies = find(stimVector);
    if isempty(stimIndicies)
        return;
    end
    
    % collapse consecutive indicies into one index by taking the mean
    % start with the first index then loop over the rest
    n0 = stimIndicies(1);
    consecutiveSum = n0;
    consecutiveElements = 1;
    reducedStimVector(1) = 0;   % undefined length until for loop is run
    for stimIndiciesIndex = 2 : length(stimIndicies)
       
        n = stimIndicies(stimIndiciesIndex);

        if n - n0 == 1
            % this is a consecutive index
            consecutiveSum = consecutiveSum + n;
            consecutiveElements = consecutiveElements + 1;
        else
            % this is a new series of consecutive indicies
            % first get the mean index from the last series and save it
            reducedStimVector(end + 1) = consecutiveSum / consecutiveElements;
            
            % then prepare for the next iteration
            consecutiveSum = n;
            consecutiveElements = 1;
        end
        
        % set n0 for the next iteration
        n0 = n;
        
    end
    % the last series isn't covered by the for loop
    reducedStimVector(end + 1) = consecutiveSum / consecutiveElements;
    
    % clean up the reducedStimVector by removing the first element
    reducedStimVector(1) = [];
    reducedStimVector(reducedStimVector < 0) = 0;
    
    finalStimVector = zeros(length(stimVector), 1);
    finalStimVector(reducedStimVector) = max(stimVector);
    
    
    handles.stimVector = finalStimVector;
    handles.reducedStimVector = reducedStimVector;

    % and update the threshold value in the edit box
    if isfield(handles, 'edit_threshold') && ishghandle(handles.edit_threshold)
        set(handles.edit_threshold, 'String', sprintf('%0.1f', newThreshold));
    end
   
end

function handles = activateDrag(handles)
    handles.dragIsActive = true;
end

function handles = deactivateDrag(handles)
    handles.dragIsActive = false;
end

function updateDrag(handles, y_mouse)
    handles = setThreshold(handles, y_mouse);
    guidata(handles.main, handles);
    
    % redraw the plots/threshold
    drawStimVector(handles);
end

function click_Callback(hObject, ~)
    
    handles = guidata(hObject);
    
    if handles.dragIsActive
        handles = deactivateDrag(handles);
    else
        cursorType = get(handles.main, 'Pointer');
        
        if strcmp(cursorType, 'top')
            handles = activateDrag(handles);
        else
            handles = deactivateDrag(handles);
        end
    end
    
    guidata(hObject, handles);
end

function mouse_Callback(hObject, ~)
    MOUSE_PIXEL_TOLERANCE = 5;  % the number of pixels that the mouse
                                % can be from a line and still be 'on the
                                % line'
    handles = guidata(hObject);
    
    mousePosition = get(handles.axes_main, 'CurrentPoint');
    
    xBounds = get(handles.axes_main, 'XLim');
    yBounds = get(handles.axes_main, 'YLim');
    
    x = mousePosition(1,1);
    y = mousePosition(1,2);

    if x >= xBounds(1) && x <= xBounds(2) && y >= yBounds(1) && y <= yBounds(2)
       % mouse is within axis
       
       if handles.dragIsActive
            % just update the threshold and do nothing else in this function
            updateDrag(handles, y);
            return;
       end
       
       % check if mouse is close to the threshold (a horizontal line)
       axesPosition = getpixelposition(handles.axes_main);
       pointsPerPixel = ( yBounds(2) - yBounds(1) ) / axesPosition(4);
       
       thresholdRange(1) = handles.threshold - ...
                           MOUSE_PIXEL_TOLERANCE * pointsPerPixel;
       thresholdRange(2) = handles.threshold + ...
                           MOUSE_PIXEL_TOLERANCE * pointsPerPixel;
                       
       if y >= thresholdRange(1) && y <= thresholdRange(2)
      
          set(handles.main, 'Pointer', 'top');
       else
          set(handles.main, 'Pointer', 'arrow');
       end
       
    else
        % mouse is not within the axis
       set(handles.main, 'Pointer', 'arrow');
    end
    
end

function resize_Callback(hObject, ~)
    handles = guidata(hObject);
    
    % remove every handle from the figure
    allHandles = findall(handles.main);
    
    allHandles = setdiff( allHandles, handles.main );
    
    
    delete(allHandles);
    
    handles = populateGUI( handles );
    
    drawStimVector(handles);
    
    guidata(hObject, handles);
end

function handles = setPixelsLeft(handles, value)
    if ~isnan(value) && value > 0
        % valid entry
        handles.pixelsLeft = round(value);
    end
    
    set(handles.edit_pixelsLeft, 'String', sprintf('%d', handles.pixelsLeft) );
    drawStimVector(handles);
end

function handles = setPixelsRight(handles, value)
    if ~isnan(value) && value > 0
        % valid entry
        handles.pixelsRight = round(value);
    end
    
    set(handles.edit_pixelsRight, 'String', sprintf('%d', handles.pixelsRight) );
    drawStimVector(handles);
end

function pixelsLeft_Callback(hObject, ~)
    handles = guidata(hObject);
    pixelsLeftString = get(hObject, 'String');
    handles = setPixelsLeft(handles, str2double(pixelsLeftString));
    
    guidata(hObject, handles);
end

function pixelsRight_Callback(hObject, ~)
    handles = guidata(hObject);
    pixelsRightString = get(hObject, 'String');
    handles = setPixelsRight(handles, str2double(pixelsRightString));
    
    guidata(hObject, handles);
end

function maximize_Callback(hObject, ~)
    % between every stimulus point is 2 boxes whose width are defined by
    % pixelsLeft and pixelsRight (the box to the left of the stimulus has
    % width = pixelsLeft etc)
    
    % maximize the width of the two boxes by finding the smallest
    % difference between any 2 stimulus points, and setting 
    % pixelsLeft = pixelsRight = minimum difference / 2
    
    handles = guidata(hObject);
    
    r = handles.reducedStimVector;
    
    if ~isempty(r)
        % get the difference between each element in r 
        differenceVector = diff(r);
        minDifference = min(differenceVector);
        
        handles = setPixelsLeft(handles, minDifference / 2);
        handles = setPixelsRight(handles, minDifference / 2);
        
        guidata(hObject, handles);
        
        
        drawStimWindows(handles);
        drawStimVector(handles);
    end
end

function handles = createGUI()
    
    handles.EDIT_WIDTH = 50;
    handles.EDIT_HEIGHT = 25;
    handles.BUTTON_WIDTH = 80;
    handles.BUTTON_HEIGHT = 25;
    handles.PADDING = 10;

    screenSize = get(0,'ScreenSize');
    
    screen_width = screenSize(3);
    screen_height = screenSize(4);
    
    figure_width = 600;
    figure_height = 400;
    figure_x = (screen_width - figure_width) / 2;
    figure_y = (screen_height - figure_height) / 2;

    handles.main = figure(...
        'Color',[0.941176470588235 0.941176470588235 0.941176470588235],...
        'Colormap',[0 0 0.5625;0 0 0.625;0 0 0.6875;0 0 0.75;0 0 0.8125;0 0 0.875;0 0 0.9375;0 0 1;0 0.0625 1;0 0.125 1;0 0.1875 1;0 0.25 1;0 0.3125 1;0 0.375 1;0 0.4375 1;0 0.5 1;0 0.5625 1;0 0.625 1;0 0.6875 1;0 0.75 1;0 0.8125 1;0 0.875 1;0 0.9375 1;0 1 1;0.0625 1 1;0.125 1 0.9375;0.1875 1 0.875;0.25 1 0.8125;0.3125 1 0.75;0.375 1 0.6875;0.4375 1 0.625;0.5 1 0.5625;0.5625 1 0.5;0.625 1 0.4375;0.6875 1 0.375;0.75 1 0.3125;0.8125 1 0.25;0.875 1 0.1875;0.9375 1 0.125;1 1 0.0625;1 1 0;1 0.9375 0;1 0.875 0;1 0.8125 0;1 0.75 0;1 0.6875 0;1 0.625 0;1 0.5625 0;1 0.5 0;1 0.4375 0;1 0.375 0;1 0.3125 0;1 0.25 0;1 0.1875 0;1 0.125 0;1 0.0625 0;1 0 0;0.9375 0 0;0.875 0 0;0.8125 0 0;0.75 0 0;0.6875 0 0;0.625 0 0;0.5625 0 0],...
        'Units', 'pixels',...
        'IntegerHandle','off',...
        'MenuBar','none',...
        'NumberTitle','off',...
        'Position', [ figure_x figure_y figure_width figure_height ],...
        'Name','Stimulus Triggered Average Setup' );
    
   
    
end

function handles = populateGUI(handles)
 % seperate figure into 3 panels + 1 axes
    %   - a top panel that contains time before/after edit boxes
    %   - a mid panel the same height as the axes for threshold edit box
    %   - a bottom panel for Save and Cancel buttons
    
    figurePosition = getpixelposition(handles.main);
    figure_width = figurePosition(3);
    figure_height = figurePosition(4);
    
    bottom_width = figure_width;
    bottom_height = 3 * handles.BUTTON_HEIGHT;

    top_width = figure_width;
    top_height = 3 * handles.EDIT_HEIGHT;
    
    middle_width = handles.EDIT_WIDTH + 2 * handles.PADDING;
    middle_height = figure_height - bottom_height - top_height;
    

    bottom_x = 0;
    bottom_y = 0;
    middle_x = 0;
    middle_y = bottom_height;
    top_x = 0;
    top_y = middle_y + middle_height;
    
    %% PANELS
    handles.panel_top = uipanel(...
        'Units', 'pixels',...
        'Position', [ top_x, top_y, top_width, top_height ],...
        'BorderType', 'none');
    
    handles.panel_middle = uipanel(...
        'Units', 'pixels',...
        'Position', [ middle_x, middle_y, middle_width, middle_height ],...
        'BorderType', 'none' );
    
    handles.panel_bottom = uipanel(...
        'Units', 'pixels',...
        'Position', [ bottom_x, bottom_y, bottom_width, bottom_height ],...
        'BorderType', 'none' );
    
    %% BOTTOM PANEL
    
    ok_width = 1.2 * handles.BUTTON_WIDTH / bottom_width;
    ok_height = 1.2 * handles.BUTTON_HEIGHT / bottom_height;
    cancel_width = ok_width;
    cancel_height = ok_height;
    
    button_padding = 0.5 * handles.BUTTON_WIDTH / bottom_width;
    
    ok_y = (1 - ok_height)/2;
    cancel_y = ok_y;
    
    ok_x = (1 - button_padding)/2 - ok_width;
    cancel_x = (1 + button_padding)/2;
    
    handles.button_ok = uicontrol(...
        'Parent', handles.panel_bottom,...
        'Style', 'pushbutton',...
        'Units', 'normalized',...
        'String', 'Ok',...
        'Callback', {@closeGUI, true},...
        'Position', [ ok_x ok_y ok_width ok_height ] );
    
    handles.button_cancel = uicontrol(...
        'Parent', handles.panel_bottom,...
        'Style', 'pushbutton',...
        'Units', 'normalized',...
        'String', 'Cancel',...
        'Callback', {@closeGUI, false},...
        'Position', [ cancel_x cancel_y cancel_width cancel_height ] );
    
    %% MIDDLE PANEL
    label_width = 1;
    label_height = handles.EDIT_HEIGHT / middle_height;
    edit_width = handles.EDIT_WIDTH / middle_width;
    edit_height = label_height;
    
    label_x = 0;
    edit_x = (1 - edit_width) / 2;
    
    label_y = 0.5 + label_height;
    edit_y = 0.5;
    
    handles.label_threshold = uicontrol(...
        'Parent', handles.panel_middle,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ label_x, label_y, label_width, label_height ],...
        'String', 'Threshold');
    
    handles.edit_threshold = uicontrol(...
        'Parent', handles.panel_middle,...
        'Background', 'white',...
        'Style', 'edit',...
        'Units', 'normalized',...
        'Position', [ edit_x, edit_y, edit_width, edit_height ],...
        'String', sprintf('%0.1f', handles.threshold));
    
    %% TOP PANEL
    
    label_width = 2 * handles.BUTTON_WIDTH / top_width;
    label_height = handles.BUTTON_HEIGHT / top_height;
    edit_width = handles.EDIT_WIDTH / top_width;
    edit_height = handles.EDIT_HEIGHT / top_height;
    padding = label_width;
    
    label_X(1) = (1 - padding - 1.5 * label_width) / 2;
    label_X(2) = (1 - padding + 1.5 * label_width) / 2;

    edit_X = label_X + ( label_width - edit_width) / 2;
    
    label_y = 0.5;
    edit_y = 0.2;
    
    button_width = handles.BUTTON_WIDTH / top_width;
    button_height = label_height;
    button_x = (1 - button_width) / 2;
    button_y = edit_y;
    
    handles.label_pixelsLeft = uicontrol(...
        'Parent', handles.panel_top,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ label_X(1), label_y, label_width, label_height ],...
        'String', 'Time before stimulus (in pixels)');
    
    handles.edit_pixelsLeft = uicontrol(...
        'Parent', handles.panel_top,...
        'Style', 'edit',...
        'Units', 'normalized',...
        'Position', [ edit_X(1), edit_y, edit_width, edit_height ],...
        'Background', handles.LIGHT_GREEN,...
        'Callback', @pixelsLeft_Callback,...
        'String', sprintf('%d', handles.pixelsLeft));
    
    handles.label_pixelsRight = uicontrol(...
        'Parent', handles.panel_top,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ label_X(2), label_y, label_width, label_height ],...
        'String', 'Time after stimulus (in pixels)');
    
    handles.edit_pixelsRight = uicontrol(...
        'Parent', handles.panel_top,...
        'Style', 'edit',...
        'Units', 'normalized',...
        'Position', [ edit_X(2), edit_y, edit_width, edit_height ],...
        'Background', handles.LIGHT_RED,...
        'Callback', @pixelsRight_Callback,...
        'String', sprintf('%d', handles.pixelsRight));
    
      handles.button_maximize = uicontrol(...
        'Parent', handles.panel_top,...
        'Style', 'pushbutton',...
        'Units', 'normalized',...
        'String', 'Maximize',...
        'Callback', @maximize_Callback,...
        'Position', [ button_x, button_y, button_width, button_height ] );
    %% AXES
    padding = handles.PADDING / top_width;
    axes_x = middle_x + middle_width + padding;
    axes_y = bottom_y + bottom_height + padding;
    
    axes_width = top_width - 2 * middle_width;
    axes_height = middle_height - 2 * padding;
    
    
    handles.axes_main = axes(...
        'Parent',handles.main,...
        'Units', 'pixels',...
        'Position',[axes_x axes_y axes_width axes_height] );
    
    
end