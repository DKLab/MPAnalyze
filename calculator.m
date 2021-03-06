function calculator( mpbus, domain, windowPeriod, defaultColormap )
%CALCULATOR pulls data from an MPScope HDF5 file and saves it as frames
%that are the same height as the windowPeriod and the same width as the domain

    
    handles = struct();
    handles.IMAGE_SCALE_FACTOR = 1;
    handles.FWHM_TO_DIAMETER = 1; % / 0.866;
    
    if ~exist('mpbus', 'var')
        handles.mpbus = MPBus();
    else
        handles.mpbus = mpbus;
    end
    
    scanData = handles.mpbus.scanData;
    handles.savedCalculationFlag = isfield(scanData, 'savedCalculation');
    
    if ~exist('domain', 'var')
        domain = [0,0];
    end
    
    if ~exist('windowPeriod', 'var')
        windowPeriod = 0;
    end
    
    if ~exist('defaultColormap', 'var')
        defaultColormap = 'gray';       % default colormap
    end
    
    
    handles.DEFAULT_FPS = 12;
    handles.colormap = defaultColormap;
    handles.domain = domain;
    handles.windowPeriod = windowPeriod;
    handles.showGUI = true;     % TODO: REMOVE showGUI (I've decided that the GUI should always be displayed)
    handles.frameNumber = 1;
    handles.frameOffset = 0;        % used for cropping frames
    handles.filename = '';
    handles.nFrames = 0;
    
    
    
    initialize(handles);
    
end

function initialize(handles)
    figureWidth = 500;
    figureHeight = 300;

    handles = createFigure( handles, figureWidth, figureHeight );
    
    if handles.savedCalculationFlag
        % load the saved calculation
        handles = openFile(handles);
        
        handles = populateGUI(handles, figureWidth, figureHeight);
        guidata(handles.main, handles);
    else
        % no saved calculation, get image data
        
        % if domain and period are not set then calculator() was not called
        % from PathAnalyze -- in that case prompt the user to open a file
        if any(handles.domain == 0)
            % prompt user to open a saved calculation
            handles = openFile(handles);
            handles = populateGUI(handles, figureWidth, figureHeight);
            
            % show the diameter plot (and output the diameter vector)
            diameterVector = [handles.diameter.fwhm] .* handles.FWHM_TO_DIAMETER;
            outputDiameter(handles, diameterVector);
        else
            % extract the image from line scan data provided by the MPBus
            % that was passed in from Path Analyze
             handles.imageWidth = (handles.domain(2) - handles.domain(1) + 1)...
                                * handles.IMAGE_SCALE_FACTOR;
             handles.imageHeight = handles.windowPeriod * handles.IMAGE_SCALE_FACTOR;
             
             handles = populateGUI(handles, figureWidth, figureHeight);
             handles = readFrames(handles);
        end

        % return focus to this figure
        figure(handles.main);
        
        guidata(handles.main, handles);

    end

    % set the default colormap
    selectColormap(handles.main, [], handles.colormap);  
    
    % update the saveRange edit box
    saveRange_callback(handles.edit_saveRange, []);

end

function handles = readFrames(handlesIn)
    % read in image data
    handles = handlesIn;
    domain = handles.domain;
    frameWidth = domain(2) - domain(1) + 1;
    frameHeight = handles.windowPeriod;
    nFrames = floor( handles.mpbus.ysize * handles.mpbus.numFrames / frameHeight );
    
    
    % TESTING -- just loading 100 frames for now
    %nFrames = 200;
    % END TESTING
    
    % initialize a waitbar
    waitbarHandle = waitbar(0, 'Time Remaining: ',...
                            'Name', 'Extracting...',...
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
    
    set(handles.main, 'CurrentAxes', handles.axes_main);
    imagesc(handles.imageData(:,:,frameNumber));
    axis off
    colormap(handles.colormap); 
    
    % also draw any diameter calculation results
    if isfield(handles, 'diameter')
        diameterStruct = handles.diameter(frameNumber);
        
        set(handles.main, 'CurrentAxes', handles.axes_results);
        cla
        plot(diameterStruct.image);
        set(gca,'xtick',[], 'ytick',[], 'xlim', [1, handles.imageWidth]);
        hold on
        
        % draw the FWHM lines as well
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
    handles = guidata(hObject);
    
    SMOOTHING = 1;
    
    % the user can choose to do a fast calculation (width is based on
    % threshold values) or a slow calculation (data is fit to a gaussian
    % and the width is determined from the resulting fitting parameters)
    title = 'Calculate Diameter';
    line1 = 'Do you want to calculate the diameter by counting pixels (fast)?';
    line2 = 'Or by fitting to a Gaussian (slow)?';
    qstring = sprintf('%s\n%s', line1, line2);
    fast = 'Count Pixels (fast)';
    slow = 'Gaussian (slow)';
    answer = questdlg(qstring, title, fast, slow, fast); 
    
    fitToGaussianFlag = strcmp(answer, slow);
    
    handles.diameter = struct(...
        'image', [],...
        'leftWidthPoint', 0,...
        'rightWidthPoint', 0,...
        'centerPoint', 0,...
        'fwhm', 0,...
        'coefficients', 0 );
    
    diameterVector = zeros(handles.nFrames, 1);
    
    % initialize a waitbar
    waitbarHandle = waitbar(0, 'Time Remaining: ',...
                            'Name', 'Calculating Diameter...',...
                            'WindowStyle', 'modal' );
    startTime = clock;                   
    
    for frameIndex = 1 : handles.nFrames
        dataVector = mean(handles.imageData(:,:,frameIndex));
        
        % subtract the offset first
        dataVector = dataVector - min(dataVector);

        [fwhm, leftWidthPoint, rightWidthPoint, coefficients, halfMax] = ...
                          calcFWHM(dataVector, SMOOTHING, fitToGaussianFlag);
        

        widthDifference = (handles.FWHM_TO_DIAMETER - 1) * fwhm;
        diameterVector(frameIndex) = handles.FWHM_TO_DIAMETER * fwhm; 
        
        handles.diameter(frameIndex).image = dataVector;
        handles.diameter(frameIndex).fwhm = fwhm;
        handles.diameter(frameIndex).coefficients = coefficients;

        handles.diameter(frameIndex).leftWidthPoint = ...
            floor(leftWidthPoint - widthDifference / 2 );
        
        handles.diameter(frameIndex).rightWidthPoint = ...
            ceil(rightWidthPoint + widthDifference / 2 );
        
        handles.diameter(frameIndex).centerPoint = ...
            [ (leftWidthPoint + rightWidthPoint)/2, halfMax ]; 
        
         % also, calculate how much time is remaining
        currentTime = clock;
        elapsedTime = etime(currentTime, startTime);
        secondsPerFrame = elapsedTime / frameIndex;
        secondsRemaining = floor(( handles.nFrames - frameIndex ) * secondsPerFrame);
        waitbarMessage = sprintf('About %d seconds remaining.', secondsRemaining);
        
        waitbar(frameIndex/handles.nFrames, waitbarHandle, waitbarMessage);
    end
    
    close(waitbarHandle);
    
    % make the results axes visible
    set(handles.axes_results, 'Visible', 'on');
    set(handles.main, 'CurrentAxes', handles.axes_main);
    drawFrame(handles);
    
    outputDiameter(handles, diameterVector, fitToGaussianFlag)
    
    guidata(handles.main, handles);
end

function outputDiameter(handles, diameterVector, fitToGaussianFlag)
    % output the total calculated diameter (diameterVector)
    
    if exist('fitToGaussianFlag', 'var')
        if fitToGaussianFlag
            calcType = 'gaussian';
        else
            calcType = 'fast';
        end
    else
        % calling this function with only 2 arguments will change the
        % output variable name to diameter_saved
        calcType = 'saved';
    end
    
    varName = sprintf('diameter_%s', calcType);
    handles.mpbus.output(varName, diameterVector, 'Path Analyze');
    
    % open a new window with the total diameter data
    figure, plot(diameterVector);
end

function calculateIntensity(hObject, ~)
end

function calculateVelocity(hObject, ~)
end

function openFile_Callback(hObject, ~)
    handles = guidata(hObject);
    
    handles = openFile(handles);
    
    guidata(handles.main, handles);
end

function handles = openFile(handlesIn)
    handles = handlesIn;
    
    if handles.savedCalculationFlag
        loadedStruct = handles.mpbus.scanData.savedCalculation;
        filename = ''; 
    else
        [filename, pathname, filterIndex] = uigetfile({'*.mat'},'Open File');
        if filterIndex > 0
            loadedStruct = load( [ pathname filename] );
        end
    end
    
    % the dataStruct is has been loaded from either a file or from the
    % MPBus -- where it was placed by calculatorWrapper()
    
    %dataStruct = extractData(loadedStruct);
    dataStruct = loadedStruct;  % for now until extractData is working
    
    if isfield(dataStruct, 'data')
        handles.imageData = dataStruct.data;
        handles.imageWidth = size(handles.imageData, 2);
        handles.imageHeight = size(handles.imageData, 1);
        handles.nFrames = size(handles.imageData, 3);
        handles.colormap = dataStruct.colormap;
        handles.diameter = dataStruct.diameter;
        
        %resize_callback(handles.main, []);
    else
        % the file selected was invalid
        errorString = sprintf('The file "%s" is not a saved calculation.',...
                                filename);
        errordlg(errorString,'File Error');
    end
    
end

function dataStruct = extractData(loadedStruct)
    % search through loadedStruct to find the correct fields
    foundRoot = isfield(loadedStruct, 'data') & ...
                isfield(loadedStruct, 'colormap') & ...
                isfield(loadedStruct, 'diameter');
            
    if foundRoot
        dataStruct = loadedStruct;
    else
        fieldnameList = fieldnames(loadedStruct);
        
        for fieldIndex = 1 : length(fieldnameList)
            
            
            
        end
    end

end

function saveFile(hObject, ~)
    handles = guidata(hObject);
    
    % first, find out if the user wants to save to file or save to a
    % Workspace
    title = 'Save';
    qstring = 'Do you want to save this data and calculation as a file or as a workspace variable?';
    answerFile = 'Save to File';
    answerVar = 'Save as Variable';
    answer = questdlg(qstring, title, answerFile, answerVar, answerVar);
    
    switch answer
        case answerFile
            saveAsVar = false;
        case answerVar
            saveAsVar = true;
        otherwise
            return;
    end
    
    if strcmp(handles.filename, '') && ~saveAsVar
        handles.filename = getFilename();
    end
        
    varName = sprintf('calculation_%s', strrep(date, '-', '_'));
    varValue = struct( 'data',  handles.imageData,...
                           'colormap', handles.colormap,...
                           'diameter', handles.diameter );

    if saveAsVar     
        handles.mpbus.output(varName, varValue, 'Calculator'); 
    else
        save(handles.filename, '-struct','varValue');
        
        % check to see that the file was saved successfully
        if MPBus.verifyFile(handles.filename, '.mat')
            title = 'Save Successful';
            message = sprintf('The calculation was successfully saved as:\n\n"%s"', handles.filename);
            msgbox( message, title ); 
        else
            title = 'Save Failed';
            message = sprintf('There was a problem saving the file\n\n"%s".', handles.filename);
            warndlg( message, title );
        end
    end
    
end

function saveAsFile(hObject, ~)
    % let the user choose a new filename, then save the file by calling
    % saveFile()
    handles = guidata(hObject);
   
    handles.filename = getFilename();   
    guidata(handles.main, handles);
    saveFile(handles.main, []);
  
end

function fullFileName = getFilename()
    defaultFilename = sprintf('calculation_%s.mat', strrep(date, '-', '_')); 
    [filename, path, filterIndex] = uiputfile(defaultFilename,'Save file as...');

    fullFileName = '';  % default
    
    if filterIndex > 0
        [~,~,extension] = fileparts(filename);
        if strcmp(extension, '.mat')
            fullFileName = [ path filename ];
        end
    end

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

function saveRange_callback(hObject, ~)
    % check to see that what the user entered into the 'remove frames' edit
    % box is a valid range
    handles = guidata(hObject);
    userInput = get(hObject, 'String');
    subStringList = regexp(userInput, ':', 'split');
   
    
    if length(subStringList) == 2

        handles.saveStart = floor(str2double(subStringList{1}));
        
        if strcmp(subStringList{2}, 'end')
            handles.saveEnd = handles.nFrames;
        else
            handles.saveEnd = floor(str2double(subStringList{2}));
        end

        if isnan(handles.saveStart) || isnan(handles.saveEnd)
            % an invalid range was specified
            handles.saveStart = 1;
            handles.saveEnd = handles.nFrames;
        else
            % saveStart and saveEnd are now numerical. Make sure they are within
            % the maximum possible range
            if handles.saveStart < 1
                handles.saveStart = 1;
            end

            if handles.saveEnd > handles.nFrames
                handles.saveEnd = handles.nFrames;
            end

            if handles.saveStart > handles.saveEnd
                swap = handles.saveStart;
                handles.saveStart = handles.saveEnd;
                handles.saveEnd = swap;
            end
        end

        
    elseif length(subStringList) == 1
        % just save 1 frame (no range)
        handles.saveStart = floor(str2double(subStringList{1}));
        
        if isnan(handles.saveStart)
            handles.saveStart = 1;
        end
        
        if handles.saveStart < 1
            handles.saveStart = 1;
        end
        
        if handles.saveStart > handles.nFrames
            handles.saveStart = handles.nFrames;
        end
        
        handles.saveEnd = handles.saveStart;
        
    else
        handles.saveStart = 1;
        handles.saveEnd = handles.nFrames;
    end
    
    set(hObject, 'String', sprintf('%d:%d', handles.saveStart, handles.saveEnd));
    guidata(handles.main, handles);
end

function saveButton_callback(hObject, ~)
    handles = guidata(hObject);
    
    % TODO save the frames
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
        'Name','Path Analyze Calculator',...
        'NumberTitle','off',...
        'Position',[300 400 figureWidth figureHeight],...
        'Tag','main',...
        'Visible','on',...
        'ResizeFcn', @resize_callback);
end

function handles = createMenu(handlesIn)
    handles = handlesIn;
    
    %%% UI MENU
    handles.menu_file = uimenu(...
        'Parent',handles.main,...
        'Label','File',...
        'Tag','menu_file' );
    
    handles.menu_open = uimenu(...
        'Parent',handles.menu_file,...
        'Accelerator','o',...
        'Callback',@openFile_Callback,...
        'Label','Open...',...
        'Tag','menu_open' );
    
    handles.menu_save = uimenu(...
        'Parent',handles.menu_file,...
        'Accelerator','s',...
        'Callback',@saveFile,...
        'Label','Save',...
        'Tag','menu_save' );
    
    handles.menu_saveAs = uimenu(...
        'Parent',handles.menu_file,...
        'Callback',@saveAsFile,...
        'Label','Save As...',...
        'Tag','menu_saveAs' );
    
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
   
end
function handles = populateGUI(handlesIn, figureWidth, figureHeight)
    MAX_MAGNIFICATION = 3;      % don't enlarge the image by a factor any
                                % larger than this
    PIXEL_PADDING = 5;
    
    handles = createMenu(handlesIn);
    
    %%% Control Panel
    panelWidth = 0.4;
    panelHeight = 0.7; 
    
    editWidth = 50 / ( panelWidth * figureWidth );
    editHeight = 20 / ( panelHeight * figureHeight );
    labelWidth = 2 * editWidth;
    labelX = 0;
    editX = labelX + labelWidth + 2 * PIXEL_PADDING / figureWidth;
    yLocations = 1 - (1:8) * editHeight;
    
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
        'Position', [ labelX yLocations(1) labelWidth editHeight ],...
        'String', 'Frame' );

    handles.edit_frameNumber = uicontrol(...
        'Parent', handles.panel_controls,...
        'Style','edit',...
        'Units', 'normalized',...
        'Enable', 'inactive',...
        'Position', [editX yLocations(1) editWidth editHeight] );
    
    handles.label_fps = uicontrol(...
        'Parent', handles.panel_controls,...
        'Style', 'text',...
        'Units', 'normalized',...
        'HorizontalAlignment', 'right',...
        'Position', [ labelX yLocations(3) labelWidth editHeight ],...
        'String', 'Frames Per Second' );

    handles.edit_fps = uicontrol(...
        'Parent', handles.panel_controls,...
        'Style','edit',...
        'Units', 'normalized',...
        'BackgroundColor', 'white',...
        'Tag', 'edit_fps',...
        'String', handles.DEFAULT_FPS,...
        'Position', [editX yLocations(3) editWidth editHeight] );
    
    %%% Remove Frames
    handles.label_save = uicontrol(...
        'Parent', handles.panel_controls,...
        'Style', 'text',...
        'Units', 'normalized',...
        'HorizontalAlignment', 'right',...
        'Position', [ labelX yLocations(5) labelWidth 1.5*editHeight ],...
        'String', 'Save frames (range)' );

    
    handles.edit_saveRange = uicontrol(...
        'Parent', handles.panel_controls,...
        'Style','edit',...
        'Units', 'normalized',...
        'BackgroundColor', 'white',...
        'Tag', 'edit_saveRange',...
        'String', '',...
        'Callback', @saveRange_callback,...
        'Position', [editX yLocations(5) editWidth editHeight] );
    
    saveButtonX = editX - labelWidth / 2;
    handles.button_save = uicontrol(...
        'Parent',handles.panel_controls,...
        'Style','pushbutton',...
        'Units','normalized',...
        'Position',[saveButtonX yLocations(7) labelWidth 1.3*editHeight],...
        'Callback', @saveButton_callback,...
        'String','Save Frames' );
    
    %%% END Crop
    %%% END Control Panel
    
    %%% Main Axes
    % THIS IS THE ONLY GRAPHICS OBJECT THAT IS IN UNITS OF PIXELS (other
    % than the figure itself)
    % the maximum axes height is the control panel height (in pixels)
    controlPanelBounds = getpixelposition(handles.panel_controls);
    panelPixelWidth = controlPanelBounds(3);
    panelPixelHeight = controlPanelBounds(4);
    panelPixelX = controlPanelBounds(1);
    panelPixelY = controlPanelBounds(2);
    
    heightScale = panelPixelHeight / handles.imageHeight;
    widthScale = panelPixelWidth / handles.imageWidth;
    
    % choose the smallest scale factor as the overall magnification
    % (with an upper bound set by MAX_MAGNIFICATION)
    magnification = min( [heightScale, widthScale, MAX_MAGNIFICATION] );
    
    
    axesHeight = handles.imageHeight * magnification;
    axesWidth = handles.imageWidth * magnification;
    axesX = panelPixelX + panelPixelWidth;
    axesY = panelPixelY;
   
    axesNormCenterX = ( axesX + 0.5 * axesWidth ) / figureWidth;
    
    handles.axes_main = axes(...
        'Parent',handles.main,...
        'Units','pixels',...
        'Position',[axesX axesY axesWidth axesHeight],...
        'XTick', [],...
        'YTick', [],...
        'Tag','axes_main' );
    
    % also create an axes for calculation results
    handles.axes_results = axes(...
        'Parent',handles.main,...
        'Units','pixels',...
        'Position',[(axesX + axesWidth + 30) axesY axesWidth axesHeight],...
        'XTick', [],...
        'YTick', [],...
        'Tag','axes_results',...
        'Visible', 'off' );
    
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