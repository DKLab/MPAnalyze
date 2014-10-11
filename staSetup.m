function [success, stimVector] = staSetup( mpbus )
%STASETUP Summary of this function goes here
%   Detailed explanation goes here

    handles = createGUI();
    handles.mpbus = mpbus;
    handles.rawStimVector = readAnalog(handles);
    
    handles = populateGUI(handles);
    
    drawStimVector(handles);

    % return values for premature close
    success = false;
    stimVector = [];
    
    % ensure the handles struct always has these fields
    handles.stimVector = [];
    handles.success = false;
    
    set(handles.main, 'ResizeFcn', @resize_Callback);
    
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

        close(handles.main);
    end
    
end

function drawStimVector(handles)
    set(handles.main, 'CurrentAxes', handles.axes_main);
    
    l = length(handles.rawStimVector);
    
    plot(1:l, handles.rawStimVector);
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
        warndlg('No analog channel was found in the HDF5 file.');
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
        'Style', 'edit',...
        'Units', 'normalized',...
        'Position', [ edit_x, edit_y, edit_width, edit_height ],...
        'String', '');
    
    %% TOP PANEL
    
    label_width = 2 * handles.BUTTON_WIDTH / top_width;
    label_height = handles.BUTTON_HEIGHT / top_height;
    edit_width = handles.EDIT_WIDTH / top_width;
    edit_height = handles.EDIT_HEIGHT / top_height;
    padding = label_width;
    
    label_X(1) = (1 - padding) / 2 - label_width;
    label_X(2) = (1 - padding) / 2 + label_width;

    edit_X = label_X + ( label_width - edit_width) / 2;
    
    label_y = 0.5;
    edit_y = 0.1;
    
    handles.label_timeBefore = uicontrol(...
        'Parent', handles.panel_top,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ label_X(1), label_y, label_width, label_height ],...
        'String', 'Time before stimulus (in pixels)');
    
    handles.edit_timeBefore = uicontrol(...
        'Parent', handles.panel_top,...
        'Style', 'edit',...
        'Units', 'normalized',...
        'Position', [ edit_X(1), edit_y, edit_width, edit_height ],...
        'String', '');
    
    handles.label_timeAfter = uicontrol(...
        'Parent', handles.panel_top,...
        'Style', 'text',...
        'Units', 'normalized',...
        'Position', [ label_X(2), label_y, label_width, label_height ],...
        'String', 'Time after stimulus (in pixels)');
    
    handles.edit_timeAfter = uicontrol(...
        'Parent', handles.panel_top,...
        'Style', 'edit',...
        'Units', 'normalized',...
        'Position', [ edit_X(2), edit_y, edit_width, edit_height ],...
        'String', '');
    
    %% AXES
    padding = handles.PADDING / top_width;
    axes_x = middle_x + middle_width + padding;
    axes_y = bottom_y + bottom_height + padding;
    
    axes_width = top_width - middle_width - 2 * padding;
    axes_height = middle_height - 2 * padding;
    
    
    handles.axes_main = axes(...
        'Parent',handles.main,...
        'Units', 'pixels',...
        'Position',[axes_x axes_y axes_width axes_height] );
    
    
end