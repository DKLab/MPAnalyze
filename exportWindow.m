function exportWindow( mpbus, domain, windowPeriod, showGUI, defaultColormap )
%EXPORTWINDOW pulls data from an MPScope HDF5 file and saves it as frames
%that are the same height as the windowPeriod and the same width as the domain
%   Detailed explanation goes here
    IMAGE_SCALE_FACTOR = 2;
    
    if ~exist('showGUI','var')
        showGUI = true;
    end
    
    if ~exist('defaultColormap', 'var')
        defaultColormap = 'gray';       % default colormap
    end
    
    handles = struct();
    handles.DEFAULT_FPS = 12;
    handles.colormap = defaultColormap;  
    handles.frameNumber = 1;
    
    if showGUI
        handles.imageWidth = (domain(2) - domain(1) + 1) * IMAGE_SCALE_FACTOR;
        handles.imageHeight = windowPeriod * IMAGE_SCALE_FACTOR;
        handles = createFigure( handles, 500, 300 );
    end

    handles.domain = domain;
    handles.windowPeriod = windowPeriod;
    handles.mpbus = mpbus;
    
    handles = readFrames(handles);
    
    if showGUI
        guidata(handles.main, handles);
        
        % set the default colormap
        selectColormap(handles.main, [], handles.colormap);  
    end
    
    % TODO: need additional code to handle case where showGUI = false
end

function handles = readFrames(handlesIn)
    EXPORT_FILE_NAME = 'temp_export.mat';
    handles = handlesIn;
    domain = handles.domain;
     
    frameWidth = domain(2) - domain(1) + 1;
    frameHeight = handles.windowPeriod;
    nFrames = floor( handles.mpbus.ysize * handles.mpbus.numFrames / frameHeight );
    
    % TESTING -- just loading 100 frames for now
    nFrames = 100;
    % END TESTING
    
    % initialize a waitbar
    waitbarHandle = waitbar(0, 'Time Remaining: ',...
                            'Name', 'Exporting...',...
                            'WindowStyle', 'modal' );
    
    %exportFile = matfile(EXPORT_FILE_NAME, 'Writable', true);
    %exportFile.data = zeros(frameHeight, frameWidth, nFrames, 'int16' );
    handles.imageData = zeros(frameHeight, frameWidth, nFrames, 'int16' );
    handles.nFrames = nFrames;
    
    startTime = clock;
    for frameIndex = 1 : nFrames
        finishLine = frameIndex * frameHeight;
        startingLine = finishLine - frameHeight + 1;
    
        frameData = handles.mpbus.readLines(startingLine : finishLine);
        frameDataCropped = frameData(: , domain(1) : domain(2));
        
        handles.imageData( :, :, frameIndex) = frameDataCropped;
        
        % also, calculate how much time is remaining
        currentTime = clock;
        elapsedTime = etime(currentTime, startTime);
        secondsPerFrame = elapsedTime / frameIndex;
        secondsRemaining = floor(( nFrames - frameIndex ) * secondsPerFrame);
        waitbarMessage = sprintf('About %d seconds remaining.', secondsRemaining);
        
        waitbar(frameIndex/nFrames, waitbarHandle, waitbarMessage);
    end
    
    close(waitbarHandle);
    
    set(handles.main, 'CurrentAxes', handles.axes_main);
    drawFrame(handles, 0, 1);  
end

function eof = drawFrame(handles, nFramesToAdvance, startingFrame)
    % do not specify a frameNumber when this function is first called
    persistent frameNumber;
    
    if ~exist('startingFrame', 'var')
        startingFrame = 1;
    else
        frameNumber = startingFrame;
    end
    if ~exist('nFramesToAdvance', 'var')
        nFramesToAdvance = 0;
    end

  
    frameNumber = frameNumber + nFramesToAdvance;
    
    % check for overflow
    if frameNumber <= 0
        frameNumber = handles.nFrames;
    elseif frameNumber > handles.nFrames
        frameNumber = 1;
    end

    if frameNumber == size(handles.imageData, 3)
        % this is the last frame, return end of file (eof)
        eof = true;
    elseif frameNumber > size(handles.imageData, 3)
        % beyond the last frame
        frameNumber = 1;
        eof = true;
        return; 
    else
        eof = false;
    end
    
    imagesc(handles.imageData(:,:,frameNumber));
    axis off
    colormap(handles.colormap); 
    
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

function resize_callback(hObject, ~)
    % remove everything from the GUI, then populate it again
    handles = guidata(hObject);

    if ~isempty(handles)
        oldHandles = get(hObject, 'Children');
        delete(oldHandles);

        newPosition = get(hObject, 'Position');

        handles = populateGUI(handles, newPosition(3), newPosition(4));

        guidata(hObject, handles);
        drawFrame(handles);
    end
end

function calculateDiameter(hObject, ~)
end

function calculateIntensity(hObject, ~)
end

function calculateVelocity(hObject, ~)
end

function loadFile(hObject, ~)
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
    
    drawFrame(handles);
end

%%% END CALLBACKS

function handles = createFigure(handlesIn, figureWidth, figureHeight)
    handles = handlesIn;
    
    handles.main = figure(...
        'Units','pixels',...
        'Color',[0.941176470588235 0.941176470588235 0.941176470588235],...
        'Colormap',[0 0 0.5625;0 0 0.625;0 0 0.6875;0 0 0.75;0 0 0.8125;0 0 0.875;0 0 0.9375;0 0 1;0 0.0625 1;0 0.125 1;0 0.1875 1;0 0.25 1;0 0.3125 1;0 0.375 1;0 0.4375 1;0 0.5 1;0 0.5625 1;0 0.625 1;0 0.6875 1;0 0.75 1;0 0.8125 1;0 0.875 1;0 0.9375 1;0 1 1;0.0625 1 1;0.125 1 0.9375;0.1875 1 0.875;0.25 1 0.8125;0.3125 1 0.75;0.375 1 0.6875;0.4375 1 0.625;0.5 1 0.5625;0.5625 1 0.5;0.625 1 0.4375;0.6875 1 0.375;0.75 1 0.3125;0.8125 1 0.25;0.875 1 0.1875;0.9375 1 0.125;1 1 0.0625;1 1 0;1 0.9375 0;1 0.875 0;1 0.8125 0;1 0.75 0;1 0.6875 0;1 0.625 0;1 0.5625 0;1 0.5 0;1 0.4375 0;1 0.375 0;1 0.3125 0;1 0.25 0;1 0.1875 0;1 0.125 0;1 0.0625 0;1 0 0;0.9375 0 0;0.875 0 0;0.8125 0 0;0.75 0 0;0.6875 0 0;0.625 0 0;0.5625 0 0],...
        'IntegerHandle','off',...
        'MenuBar','none',...
        'Name','Path Analyze -- Export',...
        'NumberTitle','off',...
        'Position',[300 300 figureWidth figureHeight],...
        'Tag','main',...
        'Visible','on',...
        'ResizeFcn', @resize_callback);
    
    
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
   
    handles = populateGUI(handles, figureWidth, figureHeight);
end

function handles = populateGUI(handlesIn, figureWidth, figureHeight)
    MAX_MAGNIFICATION = 3;      % don't enlarge the image by a factor any
                                % larger than this
    PIXEL_PADDING = 5;
    
    handles = handlesIn;
    
    %%% Control Panel
    panelWidth = 0.4;
    panelHeight = 0.7; 
    
    editWidth = 50 / ( panelWidth * figureWidth );
    editHeight = 20 / ( panelHeight * figureHeight );
    labelWidth = 2 * editWidth;
    labelX = 0.05;
    editX = labelX + labelWidth + 2 * PIXEL_PADDING / figureWidth;
    
    handles.panel_controls = uipanel(...
    'Parent',handles.main,...
    'Clipping','off',...
    'BorderType','none',...
    'Position',[0.1 0.2 panelWidth panelHeight],...
    'Tag','panel_controls' );

    handles.label_frameNumber = uicontrol(...
        'Parent', handles.panel_controls,...
        'Style', 'text',...
        'Units', 'normalized',...
        'HorizontalAlignment', 'right',...
        'Position', [ labelX 0.9 labelWidth editHeight ],...
        'String', 'Frame' );

    handles.edit_frameNumber = uicontrol(...
        'Parent', handles.panel_controls,...
        'Style','edit',...
        'Units', 'normalized',...
        'Enable', 'inactive',...
        'Position', [editX 0.9 editWidth editHeight] );
    
    handles.label_fps = uicontrol(...
        'Parent', handles.panel_controls,...
        'Style', 'text',...
        'Units', 'normalized',...
        'HorizontalAlignment', 'right',...
        'Position', [ labelX 0.7 labelWidth editHeight ],...
        'String', 'Frames Per Second' );

    handles.edit_fps = uicontrol(...
        'Parent', handles.panel_controls,...
        'Style','edit',...
        'Units', 'normalized',...
        'BackgroundColor', 'white',...
        'Tag', 'edit_fps',...
        'String', handles.DEFAULT_FPS,...
        'Position', [editX 0.7 editWidth editHeight] );
    
    %%% END Control Panel
    
    %%% Main Axes
    % THIS IS THE ONLY GRAPHICS OBJECT THAT IS IN UNITS OF PIXELS (other
    % than the figure itself)
    % the maximum axes height is the control panel height (in pixels)
    controlPanelBounds = getpixelposition(handles.panel_controls);
    panelPixelWidth = controlPanelBounds(3);
    panelPixelHeight = controlPanelBounds(4);
    panelPixelY = controlPanelBounds(2);
    
    heightScale = panelPixelHeight / handles.imageHeight;
    widthScale = panelPixelWidth / handles.imageWidth;
    
    % choose the smallest scale factor as the overall magnification
    % (with an upper bound set by MAX_MAGNIFICATION)
    magnification = min( [heightScale, widthScale, MAX_MAGNIFICATION] );
    
    
    axesHeight = handles.imageHeight * magnification;
    axesWidth = handles.imageWidth * magnification;
    axesX = figureWidth / 1.8;
    axesY = panelPixelY;
   
    axesNormCenterX = ( axesX + 0.5 * axesWidth ) / figureWidth;
    
    handles.axes_main = axes(...
        'Parent',handles.main,...
        'Units','pixels',...
        'Position',[axesX axesY axesWidth axesHeight],...
        'XTick', [],...
        'YTick', [],...
        'Tag','axes_main' );
    %%% END Main Axes
    
    %%% Movie Buttons
    
    buttonPixelWidth = 25;
    buttonPixelHeight = 25;
    
    panelPixelWidth = 5 * ( buttonPixelWidth + PIXEL_PADDING );
    panelPixelHeight = buttonPixelHeight + 2 * PIXEL_PADDING;
    
    panelWidth = panelPixelWidth / figureWidth;
    panelHeight = panelPixelHeight / figureHeight;
    
    panelX = axesNormCenterX - 0.5 * panelWidth;
    panelY = 0.05;
    buttonWidth = buttonPixelWidth / panelPixelWidth;
    buttonHeight = buttonPixelHeight / panelPixelHeight;
    
    buttonY = PIXEL_PADDING / panelPixelHeight;
    playX = (1 - buttonWidth) / 2;
    nextX = playX + buttonWidth + 0.01;
    previousX = playX - buttonWidth - 0.01;
    lastX = playX + 2 * ( buttonWidth + 0.01 );
    firstX = playX - 2 * ( buttonWidth + 0.01 );
    
    
    handles.panel_movie = uipanel(...
        'Parent',handles.main,...
        'Clipping','off',...
        'Position',[panelX panelY panelWidth panelHeight],...
        'Tag','panel_controls' );

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
    
   
end