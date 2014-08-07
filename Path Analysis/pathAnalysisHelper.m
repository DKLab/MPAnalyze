function pathAnalysisHelper(analysisObject)

% Stand-alone function for calculating the diameter, intensity, and radon
% of .mpd data from two photon scanning
% program is a helper function of arbitrary scan and associated programs
% (PathGUI, PathAnalysisGUI, etc.)
% the analysisObject is a datastructure, specifying the
% information needed to do an analysis


if length(analysisObject) > 1
    % array was passed in, loop through this, then return
    for i = 1:length(analysisObject)
        pathAnalysisHelper(analysisObject(i));
    end
    return;
end

%% analysisObject has the following elements:

fullFileName         = analysisObject.fullFileName;
firstIndexThisObject = analysisObject.firstIndexThisObject;
lastIndexThisObject  = analysisObject.lastIndexThisObject;
assignName           = analysisObject.assignName;
windowSize           = analysisObject.windowSize;
windowStep           = analysisObject.windowStep;
analysisType         = analysisObject.analysisType;
imageCh              = analysisObject.imageCh;
mpbus                = analysisObject.mpbus;

assignName(assignName == ' ') = '_';       % change spaces to underscores
assignName(assignName == '-') = '_';       % change dash/minus to underscores
%assignin ('base','analysisObject_CM',analysisObject); %%to check the content CM 20121126
%scanVelocity = analysisObject.scanVelocity; % only use if needed

success = mpbus.open(fullFileName);
if ~success
    fprintf('Read Failure\n');
    return;
end


mpbus.activeChannel = imageCh;

% get the first 1000 lines, and associated info
disp(['Ch' num2str(imageCh) ',' assignName ':'])
scanDataLinesK = mpbus.readLines(1:1000);


dt = 1/mpbus.header.PixelRate_Hz;                    % pixel clock
nPointsPerLine = mpbus.xsize;                        % points (pixels) each scan line
nLines = mpbus.numFrames * mpbus.ysize;    % total number of lines in data
timePerLine = nPointsPerLine * dt;                            % time spent scanning each line

% numbers for conversions ...
%   secondsPerRow is the time it takes to scan each line,
%   mvPerCol is the pixel spacing over scan regions, in millivolts
secsPerRow = timePerLine;                                 % in seconds
mvPerCol = (analysisObject.scanVelocity) * 1e3;           % in mV

scanResult1d = mean(scanDataLinesK);

scanResult1d = scanResult1d(:);            % make a column vector

%% setup specific to different kinds of analysis !!!!! ?????
if strcmp(analysisType,'diameter')
    typicalDiam = scanResult1d(firstIndexThisObject:lastIndexThisObject);
    offset = min(typicalDiam);                           % find the baseline
    threshold = max(typicalDiam - offset) / 2 + offset;  % threshold is half max, taking offset into account
    smoothing = 3;          % smooth data before taking width careful because the smoothing create a edge...
    %assignin ('base','smoothing_CM',smoothing)
    mpbus.output('smoothing_CM',smoothing);
elseif strcmp(analysisType,'intensity')
    % no setup

elseif strcmp(analysisType,'radon')
    % set initial range
    %jdd
    thetaRange = [0:179];
    %thetaRange = [20:159];

elseif strcmp(analysisType,'radonSym')
    error 'radonSym not currently implemented'
end

%% loop through data, creating blocks to analyse



nLinesPerBlock = round(windowSize / (nPointsPerLine * dt));   % how many lines in each block?

%FIXME DEBUG:
fprintf('last index: %d, step: %d, total size: %d\n',  nLines-nLinesPerBlock, windowStep / (nPointsPerLine * dt), ...
    (nLines-nLinesPerBlock)/ (windowStep / (nPointsPerLine * dt)));
fprintf('windowStep: %d, dt: %d\n', windowStep, dt);
windowStartPoints = round(1:windowStep / (nPointsPerLine * dt) : nLines-nLinesPerBlock);  % where do the windows start (in points?)

% cut down the window
%jdd - shorten the analysis, for testing
%windowStartPoints = windowStartPoints(1:1000); %%to remove if not in testing

analysisData = 0*windowStartPoints;      % create space to hold data
intensityData_CM_from_max_or= 0*windowStartPoints;% create space to hold data CM_20121126
point1_vector = 0*windowStartPoints;
point2_vector = 0*windowStartPoints;
analysisDataSep = analysisData;          % holds the separation (only needed for Radon)
%intensityData_CM = 0*windowStartPoints; % create space to hold data CM_20121126

disp(['calculating ' analysisType '(displaying percent done) ...'])

%% check the length of the data to define if it is analysable , if not it
%% uses only the start of the data CM
lastline_touse =floor(1e9/nPointsPerLine); % magic number 2^20 These lines were added to allow the program to stop before crashing CELINE MATEO 20111116
%lastline_touse =floor(0.5e9/nPointsPerLine); % magic number 2^20
tempCM = windowStartPoints(end);
length (windowStartPoints)
disp([' The windowstartpointend value is ' num2str(tempCM)])
if windowStartPoints(end) > lastline_touse
    disp([' data too long, was ' num2str(windowStartPoints(end)) ' cutting to ' num2str(lastline_touse) ])
    windowStartPoints = windowStartPoints(find(lastline_touse>windowStartPoints));
    tempCM = windowStartPoints(end);
    disp([' The windowstartpointend value is ' num2str(tempCM)])
    length (windowStartPoints)
end

% suppress debug statements during the for loop
mpbus.verbose = false;

%% loop through the data, calculating relevant variable creating blocks to
%% analyse
nchar=fprintf('ca commence');
elapsed = 0;
for i = 1:length(windowStartPoints)
    if ~mod(i,round(length(windowStartPoints)/50))
        %         disp((['  ' num2str(round(100*i/length(windowStartPoints))) ' % ' ...
        %             num2str(windowStartPoints(i)) ' out of ' num2str(lastline_touse)]))
        fprintf(repmat('\b',1,nchar))
        string_to_display=['' num2str(round(100*i/length(windowStartPoints))),' percent ', num2str(windowStartPoints(i)) ' out of ' num2str(lastline_touse)];
        nchar=fprintf(string_to_display);
    end

    w = windowStartPoints(i);         % which line to start this window?

    tic;
    % old
    %{
    blockData = hdfRead(fullFileNameHDF,'lines',imageCh, ...
        w:w-1+nLinesPerBlock);
    %}
    blockData = mpbus.readLines(w:w-1+nLinesPerBlock);
    elapsed = elapsed + toc;
    blockDataMean = mean(blockData,1);      % take mean of several frames
    blockDataMean_lat= mean(blockData,2);
   %{
    if imageCh == 1
        blockDataMean = mean(blockData.Ch1,1);   % take mean of several frames imageCh == 1
        blockDataMean_lat= mean(blockData.Ch1,2);
    elseif imageCh == 2
        blockDataMean = mean(blockData.Ch2,1);   % take mean of several frames imageCh == 2 with no index cut
        blockDataMean_lat= mean(blockData.Ch2,2);
        %assignin('base',[assignName '_' 'CMimage' num2str(imageCh) '_' analysisType],blockData.Ch2);%CM to visualise the data
    elseif imageCh == 3
        blockDataMean = mean(blockData.Ch3,1);   % take mean of several frames imageCh == 3
    elseif imageCh == 4
        blockDataMean = mean(blockData.Ch4,1);   % take mean of several frames imageCh == 4
    end
    %}
    % l=max (max(line_8_CMimage2_diameter(:,26:27)))

    blockDataMean = blockDataMean(firstIndexThisObject:lastIndexThisObject);  % cut out only portion for this object
    %blockDataMax= blockDataMax(firstIndexThisObject:firstIndexThisObject+4); %% 4first columns for the analysis of the light intensity
    intensityData_CM_from_max_or (i) = max(blockDataMean_lat(:));   % take mean of several frames imageCh == 2

    % assignin('base',[assignName '_' 'CMimagemean' num2str(imageCh) '_' analysisType],blockDataMean);%CM to visualise the data
    %blockDataCut = blockData.Ch1(:,firstIndexThisObject:lastIndexThisObject);
    %{
    if imageCh == 1
        blockDataCut = blockData.Ch1(:,firstIndexThisObject:lastIndexThisObject);
    elseif imageCh == 2
        blockDataCut = blockData.Ch2(:,firstIndexThisObject:lastIndexThisObject);
    elseif imageCh == 3
        blockDataCut = blockData.Ch3(:,firstIndexThisObject:lastIndexThisObject);
    elseif imageCh == 4
        blockDataCut = blockData.Ch4(:,firstIndexThisObject:lastIndexThisObject);
    end
    %}
     blockDataCut = blockData(:,firstIndexThisObject:lastIndexThisObject);
    %jdd
    %if i==1
    %    assignin('base','b1',blockDataCut);
    %    return
    %end

    if strcmp(analysisType,'diameter')
        [analysisData(i) point1_vector(i) point2_vector(i)] = calcFWHM(blockDataMean,smoothing);

        %  [analysisData(i) intensityData_CM(i)] = calcFWHM(blockDataMean);
        %analysisData(i) = calcFWHM(blockDataMean,smoothing,threshold);
        % [analysisData(i) intensityData_CM(i)] = calcFWHM(blockDataMean,smoothing);

    elseif strcmp(analysisType,'intensity')
        analysisData(i) = mean(blockDataMean);
    elseif strcmp(analysisType,'radon')
        thetaAccuracy = .05;
        [theta sep] = radonBlockToTheta(blockDataCut,thetaAccuracy,thetaRange);
        analysisData(i) = theta;
        analysisDataSep(i) = sep;
        % look around previous value for theta
        % this speeds things up, but can also cause the data to "hang"
        % on incorrect values
        %thetaRange = [theta-10:theta+10];
    end
end

% done suppressing debug statements
mpbus.verbose = true;

%FIXME: Debug
fprintf('elapsed time is: %d', elapsed);
%% post-processing, if necessary

if strcmp(analysisType,'radon')
    % convert this to a more usable form
    %   (timePerLine) holds vertical spacing info
    %   (scanVelocity*1e3) is distance between pixels (in ROIs), in mV
    % note that theta is actually reported angle from vertical, so
    %    vertical lines (stalls) have theta of zero
    %    horizontal lines (very fast) have theta of 90
    %    (angle is measured ccw from vertical)
    %
    %            cols    mvPerCol     row          mv
    %  tand() =  ---- * --------  * ----------  =  ---
    %            row      col       secsPerRow     sec
    %
    % the units of mv/sec can be converterd into a speed by noting that mv
    % corresponds to a distance

    speedData = (tand(analysisData)) * mvPerCol / secsPerRow;    % note this is taken in degrees
    %assignin('base',[assignName '_' 'ch' num2str(imageCh) '_radon_mv_per_s'],speedData);   % mv / second
    %assignin('base',[assignName '_' 'ch' num2str(imageCh) '_radon_theta'],analysisData);   % degrees from vertical
    %assignin('base',[assignName '_' 'ch' num2str(imageCh) '_radon_sep'],analysisDataSep);   % degrees from vertical
    mpbus.output( sprintf('%s_ch%d_radon_mv_per_s',assignName,imageCh), speedData );
    mpbus.output( sprintf('%s_ch%d_radon_theta',assignName,imageCh), analysisData );
    mpbus.output( sprintf('%s_ch%d_radon_sep',assignName,imageCh), analysisDataSep );
    
elseif strcmp(analysisType,'diameter')
    analysisData = analysisData * mvPerCol;     % convert units (currently in pixels) to millivolts
    %assignin('base',[assignName '_' 'ch' num2str(imageCh) '_diameter_mv'],analysisData);   % mv / second
    %assignin('base',[assignName '_' 'ch' num2str(imageCh) '_MAX_int_mv'],intensityData_CM_from_max_or);   % mv / second
    %assignin('base',[assignName '_' 'ch' num2str(imageCh) '_point1_vector'],point1_vector);   % mv / second
    %assignin('base',[assignName '_' 'ch' num2str(imageCh) '_point2_vector'],point2_vector);   % mv / second
    midline=(point2_vector+point1_vector)/2;
    %assignin('base',[assignName '_' 'ch' num2str(imageCh) '_midline_vector'],midline);   % mv / second
    %assignin('base',[assignName '_' 'ch' num2str(imageCh) '_Mean_int_mv'],intensityData_CM);   % mv / second
    mpbus.output( sprintf('%s_ch%d_diameter_mv',assignName,imageCh), analysisData );
    mpbus.output( sprintf('%s_ch%d_MAX_int_mv',assignName,imageCh), intensityData_CM_from_max_or );
    mpbus.output( sprintf('%s_ch%d_point1_vector',assignName,imageCh), point1_vector );
    mpbus.output( sprintf('%s_ch%d_point2_vector',assignName,imageCh), point2_vector );
    mpbus.output( sprintf('%s_ch%d_midline_vector',assignName,imageCh), midline );
    %mpbus.output( sprintf('%s_ch%d_Mean_int_mv',assignName,imageCh), intensityData_CM );

else
    % other analysis, besides radon or diameter (i.e., intensity)
    assignName(assignName == ' ') = '_';                           % change spaces to underscores
    assignName(assignName == '-') = '_';                           % change dash/minus to underscores
    %assignin('base',[assignName '_' 'ch' num2str(imageCh) '_' analysisType],analysisData);
    mpbus.output( sprintf('%s_ch%d_%s',assignName,imageCh,analysisType), analysisData );
end

% make a time axis that matcheds the diameter info
time_axis = windowSize/2 + windowStep*(0:length(analysisData)-1);
%assignin('base',[assignName '_time_axis'],time_axis);
mpbus.output( sprintf('%s_time_axis', assignName), time_axis );
disp ' ... done'


