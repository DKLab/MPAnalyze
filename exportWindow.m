function exportWindow( mpbus, domain, windowPeriod, showGUI )
%EXPORTWINDOW pulls data from an MPScope HDF5 file and saves it as frames
%that are the same height as the windowPeriod and the same width as the domain
%   Detailed explanation goes here
    IMAGE_SCALE_FACTOR = 2;
    
    if ~exist('showGUI','var')
        showGUI = true;
    end
    
    if showGUI
        imageWidth = (domain(2) - domain(1) + 1) * IMAGE_SCALE_FACTOR;
        imageHeight = windowPeriod * IMAGE_SCALE_FACTOR;
        handles = createGUI( imageWidth, imageHeight );
    end

    handles.domain = domain;
    handles.windowPeriod = windowPeriod;
    handles.mpbus = mpbus;
    
    handles = readFrames(handles);

    guidata(handles.main, handles);
end

function handles = readFrames(handlesIn)
    EXPORT_FILE_NAME = 'temp_export.mat';
    handles = handlesIn;
    domain = handles.domain;
     
    frameWidth = domain(2) - domain(1) + 1;
    frameHeight = handles.windowPeriod;
    nFrames = floor( handles.mpbus.ysize * handles.mpbus.numFrames / frameHeight );
    
    % TESTING -- just loading 100 frames for now
    %nFrames = 100;
    % END TESTING
    
    % initialize a waitbar
    waitbarHandle = waitbar(0, 'Exporting...');
    
    %exportFile = matfile(EXPORT_FILE_NAME, 'Writable', true);
    %exportFile.data = zeros(frameHeight, frameWidth, nFrames, 'int16' );
    handles.imageData = zeros(frameHeight, frameWidth, nFrames, 'int16' );
    handles.nFrames = nFrames;
    
    for frameIndex = 1 : nFrames
        finishLine = frameIndex * frameHeight;
        startingLine = finishLine - frameHeight + 1;
    
        frameData = handles.mpbus.readLines(startingLine : finishLine);
        frameDataCropped = frameData(: , domain(1) : domain(2));
        
        handles.imageData( :, :, frameIndex) = frameDataCropped;
        
        waitbar(frameIndex/nFrames, waitbarHandle, 'Exporting...');
    end
    
    close(waitbarHandle);
    
    set(handles.main, 'CurrentAxes', handles.axes_main);
    drawFrame(handles);  
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
    if isempty(frameNumber)
        frameNumber = startingFrame;
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
    colormap('gray'); 
    
    set(handles.edit_frameNumber, 'String', frameNumber);
end

function animateFrames(~, ~, handles)
    eof = drawFrame(handles, 1);
    
    if eof
        stop(timerfind);
    end
end

%%% CALLBACKS
function play_callback(hObject, ~)
    persistent lastCommandIsPlay;
    
    handles = guidata(hObject);
    
    if ~isfield(handles, 'animationTimer')
        handles.animationTimer = timer(...
           'ExecutionMode','fixedRate',...  
           'Period',0.1,...
           'TimerFcn',{@animateFrames,handles});
    end
    
    if isempty(lastCommandIsPlay)
        lastCommandIsPlay = false;
    end
    
    if lastCommandIsPlay
        stop(timerfind);
        lastCommandIsPlay = false;
        set(hObject, 'String', '>');
    else
        lastCommandIsPlay = true;
        start(handles.animationTimer);
        set(hObject, 'String', '||');
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
%%% END CALLBACKS

function handles = createGUI(imageWidth, imageHeight)
    FIGURE_WIDTH = 300;
    FIGURE_HEIGHT = 300;
    
    handles.main = figure(...
        'Units','pixels',...
        'Color',[0.941176470588235 0.941176470588235 0.941176470588235],...
        'Colormap',[0 0 0.5625;0 0 0.625;0 0 0.6875;0 0 0.75;0 0 0.8125;0 0 0.875;0 0 0.9375;0 0 1;0 0.0625 1;0 0.125 1;0 0.1875 1;0 0.25 1;0 0.3125 1;0 0.375 1;0 0.4375 1;0 0.5 1;0 0.5625 1;0 0.625 1;0 0.6875 1;0 0.75 1;0 0.8125 1;0 0.875 1;0 0.9375 1;0 1 1;0.0625 1 1;0.125 1 0.9375;0.1875 1 0.875;0.25 1 0.8125;0.3125 1 0.75;0.375 1 0.6875;0.4375 1 0.625;0.5 1 0.5625;0.5625 1 0.5;0.625 1 0.4375;0.6875 1 0.375;0.75 1 0.3125;0.8125 1 0.25;0.875 1 0.1875;0.9375 1 0.125;1 1 0.0625;1 1 0;1 0.9375 0;1 0.875 0;1 0.8125 0;1 0.75 0;1 0.6875 0;1 0.625 0;1 0.5625 0;1 0.5 0;1 0.4375 0;1 0.375 0;1 0.3125 0;1 0.25 0;1 0.1875 0;1 0.125 0;1 0.0625 0;1 0 0;0.9375 0 0;0.875 0 0;0.8125 0 0;0.75 0 0;0.6875 0 0;0.625 0 0;0.5625 0 0],...
        'IntegerHandle','off',...
        'MenuBar','none',...
        'Name','Path Analyze -- Export',...
        'NumberTitle','off',...
        'Position',[300 300 FIGURE_WIDTH FIGURE_HEIGHT],...
        'Tag','figure1',...
        'Visible','on' );
    
    axesHeight = imageHeight / FIGURE_HEIGHT;
    axesWidth =  imageWidth / FIGURE_WIDTH;
    axesX = (1 - axesWidth) / 2;
    axesY = (1 - axesHeight) / 1.5;
    
    handles.axes_main = axes(...
        'Parent',handles.main,...
        'Units','normalized',...
        'Position',[axesX axesY axesWidth axesHeight],...
        'XTick', [],...
        'YTick', [],...
        'Tag','axes_main' );
    
    %%% BUTTONS
    buttonWidth = 25 / FIGURE_WIDTH;
    buttonHeight = 25 / FIGURE_HEIGHT;
    buttonY = (1 - buttonHeight) / 10;
    playX = (1 - buttonWidth) / 2;
    nextX = playX + buttonWidth + 0.01;
    previousX = playX - buttonWidth - 0.01;
    lastX = playX + 2 * ( buttonWidth + 0.01 );
    firstX = playX - 2 * ( buttonWidth + 0.01 );
    
    handles.button_play = uicontrol(...
        'Parent',handles.main,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[playX buttonY buttonWidth buttonHeight],...
        'Callback', @play_callback,...
        'String','>' );
    
    handles.button_next = uicontrol(...
        'Parent',handles.main,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[nextX buttonY buttonWidth buttonHeight],...
        'Callback', @next_callback,...
        'String','>>' );
    
    handles.button_previous = uicontrol(...
        'Parent',handles.main,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[previousX buttonY buttonWidth buttonHeight],...
        'Callback', @previous_callback,...
        'String','<<' );
    
    handles.button_first = uicontrol(...
        'Parent',handles.main,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[firstX buttonY buttonWidth buttonHeight],...
        'Callback', @first_callback,...
        'String','|<<' );

    handles.button_last = uicontrol(...
        'Parent',handles.main,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[lastX buttonY buttonWidth buttonHeight],...
        'Callback', @last_callback,...
        'String','>>|' );
    %%% END BUTTONS
    
    handles.edit_frameNumber = uicontrol(...
        'Parent', handles.main,...
        'Style','edit',...
        'Units', 'normalized',...
        'Position', [playX 0.9 buttonWidth buttonHeight] );
end