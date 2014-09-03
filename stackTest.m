function stackTest( )
%STACKTEST Summary of this function goes here
%   Detailed explanation goes here


    handles = createGUI();
    handles.colormap = 'gray';
    
        [fileName, filePath] = uigetfile('*.h5','open file - HDF5 (*.h5)'); % open file
%         filePath = pwd;
%         fileName = '\arbscan11_movie.h5';
        fullFileName = [filePath fileName];


    % just pull the image stack from this file
    info = h5info(fullFileName);
    for groupIndex = 1 : length(info.Groups)
        groupName = info.Groups(groupIndex).Name;
        
        foundIndex = strfind(groupName, 'ImageCh');
        
        if ~isempty(foundIndex)
            imageGroup = groupName;
        end
    end
 
    groupInfo = h5info(fullFileName, imageGroup);
    handles.imageSize = groupInfo.Datasets(1).Dataspace.Size;
    handles.nFrames = length(groupInfo.Datasets);
    
    handles.imageStack = zeros( handles.imageSize(1), handles.imageSize(2), ...
                            handles.nFrames);
    
    for datasetIndex = 1 : handles.nFrames   
        datasetPath = sprintf('%s/%s', imageGroup, groupInfo.Datasets(datasetIndex).Name); 
        handles.imageStack(:, :, datasetIndex) = ...
                            transpose( h5read(fullFileName, datasetPath) );    
    end
    
     handles = populateGUI(handles);
     
     guidata(handles.main, handles);
     
     drawFrame(handles, 0, 1);

end

function animateFrames(~, ~, handles)
    eof = drawFrame(handles, 1);
    
    if eof
        play_callback(handles.main, []);
    end
   
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

    if frameNumber == handles.nFrames
        % this is the last frame, return end of file (eof)
        eof = true;
    elseif frameNumber > handles.nFrames
        % beyond the last frame
        frameNumber = 1;
        eof = true;
        return; 
    else
        eof = false;
    end
    
    set(handles.main, 'CurrentAxes', handles.axes_main);
    imagesc(handles.imageStack(:,:,frameNumber));
    %axis off
    colormap(handles.colormap); 
    
    set(handles.edit_frameNumber, 'String', frameNumber);

end


function play_callback(hObject, ~)

persistent lastCommandIsPlay;
    
    handles = guidata(hObject);
    
    % get the requested frames per second
    fps = 12;
    
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


function handles = createGUI()
    handles.main = figure(...
        'Units', 'pixels',...
        'Position', [100, 100, 600, 600],...
        'Color',[0.941176470588235 0.941176470588235 0.941176470588235],...
        'Colormap',[0 0 0.5625;0 0 0.625;0 0 0.6875;0 0 0.75;0 0 0.8125;0 0 0.875;0 0 0.9375;0 0 1;0 0.0625 1;0 0.125 1;0 0.1875 1;0 0.25 1;0 0.3125 1;0 0.375 1;0 0.4375 1;0 0.5 1;0 0.5625 1;0 0.625 1;0 0.6875 1;0 0.75 1;0 0.8125 1;0 0.875 1;0 0.9375 1;0 1 1;0.0625 1 1;0.125 1 0.9375;0.1875 1 0.875;0.25 1 0.8125;0.3125 1 0.75;0.375 1 0.6875;0.4375 1 0.625;0.5 1 0.5625;0.5625 1 0.5;0.625 1 0.4375;0.6875 1 0.375;0.75 1 0.3125;0.8125 1 0.25;0.875 1 0.1875;0.9375 1 0.125;1 1 0.0625;1 1 0;1 0.9375 0;1 0.875 0;1 0.8125 0;1 0.75 0;1 0.6875 0;1 0.625 0;1 0.5625 0;1 0.5 0;1 0.4375 0;1 0.375 0;1 0.3125 0;1 0.25 0;1 0.1875 0;1 0.125 0;1 0.0625 0;1 0 0;0.9375 0 0;0.875 0 0;0.8125 0 0;0.75 0 0;0.6875 0 0;0.625 0 0;0.5625 0 0],...
        'IntegerHandle','off',...
        'MenuBar','none',...
        'Name','Image Stack Test',...
        'NumberTitle','off' );     
end

function handles = populateGUI(handlesIn)
    handles = handlesIn;
    PIXEL_PADDING = 10;
    
    figurePixelPosition = getpixelposition(handles.main);
    figurePixelSize = [figurePixelPosition(3), figurePixelPosition(4)];
    
    axesNormSize = handles.imageSize ./ figurePixelSize;
    
    if any(axesNormSize > 1)
        disp('image too big');
    end
    
    axesNormCenterX = 0.5;

    handles.axes_main = axes(...
        'Parent', handles.main,...
        'Units', 'normalized',...
        'Position', [ axesNormCenterX - axesNormSize(1)/2, axesNormCenterX - axesNormSize(2)/2, ...
                        axesNormSize(1), axesNormSize(2)]);
    
    buttonPixelWidth = 25;
    buttonPixelHeight = 25;
    
    panelPixelWidth = 5 * ( buttonPixelWidth + PIXEL_PADDING );
    panelPixelHeight = buttonPixelHeight + 2 * PIXEL_PADDING;
    
    panelWidth = panelPixelWidth / figurePixelSize(1);
    panelHeight = panelPixelHeight / figurePixelSize(2);
    
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
    
    handles.edit_frameNumber = uicontrol(...
        'Parent', handles.main,...
        'Style','edit',...
        'Units', 'normalized',...
        'Enable', 'inactive',...
        'Position', [0.5 0.95 0.05 0.05] );
end
