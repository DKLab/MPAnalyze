function staDataStruct = staAnalyzer(varargin)

mpbus = varargin{1};
workspaceList = mpbus.variables();

if isempty(workspaceList)
    workspaceList = 'No Variables Found';
end

defaultDataStruct = struct(...
'dataVector', {workspaceList}, ...
'dataTimeVector', {workspaceList}, ... 
'stimVector', {workspaceList}, ... 
'stimTimeVector', {workspaceList}, ... 
'stimWidth_sec', 2, ... 
'baseLineWidth_sec', 17, ... 
'micrometersPerMillivolt', 0.24, ... 
'previewCycle', 0.5, ... 
'filterSize_sec', 0, ...
'cyclesToReject', 0, ...
'autoRejectCycles', false, ...
'searchWindowSize', 800, ...
'rejectLastCycle', true, ...
'verbose', true);

labelStruct = struct(...
'dataVector', 'Data Vector', ...
'dataTimeVector', 'Data Time Vector', ... 
'stimVector', 'Stim Vector', ... 
'stimTimeVector', 'Stim Time Vector', ... 
'stimWidth_sec', 'Stim Width (sec)', ... 
'baseLineWidth_sec', 'Baseline Width (sec)', ... 
'micrometersPerMillivolt', 'Micrometers Per Milivolt', ... 
'previewCycle', 'Preview Cycle', ... 
'filterSize_sec', 'Filter Size (sec)', ... 
'cyclesToReject', 'Cycles To Reject', ...
'autoRejectCycles', 'Auto Reject Cycles?', ...
'searchWindowSize', 'Search Window Size', ...
'rejectLastCycle', 'Reject last cycle?', ...
'verbose', 'Display errors/warnings in Command Window');

[staDataStruct, success] = mpbus.gui(defaultDataStruct, labelStruct); 
% % windowAStartTime = staDataStruct.windowAStartTime;
% % windowAStopTime = staDataStruct.windowAStopTime;
% % windowBStartTime = staDataStruct.windowBStartTime;
% % windowBStopTime = staDataStruct.windowBStopTime;

if ~success
    disp('There was a problem getting user parameters for staAnalyzer.m');
    staDataStruct = [];
    return;
end


% turn the data struct into local variables
dataVector = mpbus.input(staDataStruct.dataVector);
dataTimeVector = mpbus.input(staDataStruct.dataTimeVector); 
stimVector = mpbus.input(staDataStruct.stimVector); 
stimTimeVector = mpbus.input(staDataStruct.stimTimeVector); 
stimWidth_sec = staDataStruct.stimWidth_sec; 
baseLineWidth_sec = staDataStruct.baseLineWidth_sec; 
micrometersPerMillivolt = staDataStruct.micrometersPerMillivolt; 
previewCycle = staDataStruct.previewCycle; 
filterSize_sec = staDataStruct.filterSize_sec; 
cyclesToReject = staDataStruct.cyclesToReject;
autoRejectCycles = staDataStruct.autoRejectCycles;
searchWindowSize =  staDataStruct.searchWindowSize;
rejectLastCycle = staDataStruct.rejectLastCycle;
verbose = staDataStruct.verbose;



stimTimeStep = median(diff(stimTimeVector(:)));
stimWidth = round(stimWidth_sec / stimTimeStep); %num data points in a single stimulation
baseLineWidth = round(baseLineWidth_sec / stimTimeStep); % num data points in a stimCycle in StimVector
% % stimDataPerFrame = Data_from_mpfile.DPPFrame3;
% % dataFrameTime = 1./Data_from_mpfile.Frame_Rate;

dataVector_um = dataVector*micrometersPerMillivolt;
timeStep = median(diff(dataTimeVector));

%Make all vectors vertical
if size(stimVector,1)<size(stimVector,2),
    stimVector = stimVector';
end
%---
if size(stimTimeVector,1)<size(stimTimeVector,2),
    stimTimeVector = stimTimeVector';
end
%---
if size(dataVector_um,1)<size(dataVector_um,2),
    dataVector_um = dataVector_um';
end

%---
if size(dataTimeVector,1)<size(dataTimeVector,2),
    dataTimeVector = dataTimeVector';
end

% not sure why this code is even here -- force auto reject?
%{
autoRejectFlag = false;
if isempty(cyclesToReject),
    autoRejectFlag = true;
end%if isempty...
%}
autoRejectFlag = autoRejectCycles;

if cyclesToReject == 0,
    cyclesToReject = [];
end%if cyclesToReject == 0,


% Attempt to Median Filter the stimVector at half its width
% may need to reduce the width even further if medfilt2 is giving Out of
% Memory Errors

function filteredData = call_medfilt2( data, width )
    try
        filteredData = medfilt2( data , width );
    catch exception
        switch exception.identifier
            case 'MATLAB:nomem'
                disp('medfilt2 encountered an out of memory error');
                disp('reducing width by a factor of 2 and trying again...');
                width = [round( width(1) / 2 ),1];
                filteredData = call_medfilt2( data, width );
            otherwise
                errorMessage = getReport(exception, 'extended', ...
                                                    'hyperlinks', 'on');
                disp(errorMessage);
        end
    end
    
end

filtStimVector = call_medfilt2(abs(stimVector),[round(stimWidth/2),1]);

baseLine = mean(abs(filtStimVector(1:round(baseLineWidth*0.8))));
baseLineStd = std(abs(filtStimVector(1:round(baseLineWidth*0.8))));

% the gate vector indicates locations where stimulus occured and should
% exclude noise. Instead of using the filtered stimulus vector, just use
% the original
maxValue = max(stimVector);
threshold = maxValue / 2;
gateVector = stimVector>threshold;


figure(1);plot(filtStimVector,'r.');hold on
figure(1);plot(stimVector,'b.');
figure(1);plot(gateVector,'g-');hold off
ylabel('Stimulation Intensity[arbs]');
xlabel('Stimulation sample number[data pixels]');
 


startIndex = 1;


numStimPoints = numel(stimTimeVector);
numdataPoints = numel(dataTimeVector);

for timeIter = 1:numdataPoints,
    thisTime = dataTimeVector(timeIter);
    startPoint = startIndex;
    stopPoint = startIndex+searchWindowSize-1;
    if stopPoint>numStimPoints,
        stopPoint = numStimPoints;
    end%if stopPoint>numStimPoints,
    searchWindow = stimTimeVector(startPoint:stopPoint);
    [minDiff,minPos] = min((searchWindow-thisTime).^2);
    if minPos == searchWindowSize,
        disp([num2str(timeIter),'error - need bigger searchWindowSize']);
    end%if minPos == searchWindowSize,
    bestMatch = minPos + startIndex -1;
    bestMatchVector(timeIter) = bestMatch;
    minDiffVector(timeIter) = minDiff;
    startIndex = startIndex + minPos - 1;
end%for timeIter = 1:numPoints,




%Find Trigger On
reducedGateVector = gateVector(bestMatchVector);
triggerPoints = find(diff(reducedGateVector)==1);
triggerSep = median(diff(triggerPoints));

if rejectLastCycle
    numCycles = numel(triggerPoints) - 1;  %Assume last cycle is incomplete
else
    numCycles = numel(triggerPoints);
end
cycleWidth = round(triggerSep);
cycleTime = cycleWidth*timeStep;


if autoRejectFlag == true,
    %autoReject cycles
    cycleMean = [];
    cycleStd = [];
    cycleMax = [];
    cycleMin = [];
    for cycleIter = 1:numCycles,
        thisTrigger = triggerPoints(cycleIter);
        startPoint = round(thisTrigger - cycleWidth * previewCycle);
        stopPoint = startPoint+cycleWidth-1;
        cycleData = dataVector_um(startPoint:stopPoint);
        cycleMean(cycleIter) = mean(cycleData);
        cycleStd(cycleIter) = std(cycleData);
        cycleMax(cycleIter) = max(cycleData);
        cycleMin(cycleIter) = min(cycleData);
    end
    minStd = min(cycleStd);
    medianMean = median(cycleMean);
    highRejectThreshold = medianMean + 5 * minStd;
    lowRejectThreshold = medianMean - 5 * minStd;
    cyclesToReject = find(or(cycleMax>highRejectThreshold,cycleMin < lowRejectThreshold));
end%if autoRejectFlag == true;
    
    
% the following line always rejects the last cycle (the last cycle # is
% equal to the number of trigger points):
%       cyclesToReject = unique([cyclesToReject,numel(triggerPoints)]);
% replace with code that does not automatically reject the last cycle
% unless requested from the user parameters
if rejectLastCycle
    cyclesToReject = unique([cyclesToReject,numel(triggerPoints)]);
else
    cyclesToReject = unique(cyclesToReject);
end

cyclesToUse = [1:numCycles];
cyclesToUse = cyclesToUse(~ismember(cyclesToUse,cyclesToReject));
numCyclesToUse = numel(cyclesToUse);





for rejectIter = 1:numel(cyclesToReject)
    cycleCounter = cyclesToReject(rejectIter);
    thisTrigger = triggerPoints(cycleCounter);
    startPoint = round(thisTrigger - cycleWidth * previewCycle);
    stopPoint = startPoint+cycleWidth-1;
    graySeq = zeros(round(stopPoint-startPoint+1),1);
    graySeq(1:2:end) = 1;
    figure(2);p1 = plot([startPoint:stopPoint],graySeq*max(dataVector_um),'k-');hold on
    set(p1,'Color',[0.75,0.75,0.75]);
end%for rejectIter = 1:numel(cyclesToReject)


figure(2);plot(dataVector_um,'r-');
figure(2);plot(reducedGateVector*max(dataVector_um),'g-');hold off
myTitle = ['Rejected Cycles : ',num2str(cyclesToReject)];
ylabel('[micrometers] or [micrometers/second]');
xlabel('Data sample number [pixels]');
title(myTitle);



staMatrix = zeros(cycleWidth,numCyclesToUse);%stimulus triggered average matrix
cycleCounter = 0;
for cycleIter = cyclesToUse,
    cycleCounter = cycleCounter+1;
    thisTrigger = triggerPoints(cycleIter);
    startPoint = round(thisTrigger - cycleWidth * previewCycle);
    stopPoint = startPoint+cycleWidth-1;
    
    % ensure start point and stop point do not exceed the dimensions of
    % dataVector_um
    if startPoint <= 0
        startPoint = 1;
    end
    maxStopPoint = length(dataVector_um);
    if stopPoint > maxStopPoint
        stopPoint = maxStopPoint;
    end
    fprintf('cycleCounter: %d\n', cycleCounter);
    fprintf('start point: %d, stop point: %d\n', startPoint,stopPoint);
    fprintf('thisTrigger - cycleWidth * previewCycle -- %d - %d * %d\n',...
        thisTrigger, cycleWidth, previewCycle);
    disp('-------------------------------------');
    % because start and stop point may not always be the same distance
    % apart, ensure that the data vector is the correct size before trying
    % to insert it into the staMatrix
    dataSlice = dataVector_um(startPoint:stopPoint);
    dataSize = (stopPoint - startPoint + 1);
    expectedSize = size(staMatrix, 1);
    if dataSize < expectedSize 
        dataSlice = padarray(dataSlice, [expectedSize - dataSize, 0], 'post');
        % also make sure staGate is the same size as staMatrix
        gateSlice = padarray(reducedGateVector(startPoint:stopPoint), ...
                            [expectedSize - dataSize, 0], 'post');
    else
        gateSlice = reducedGateVector(startPoint:stopPoint);
    end
    
    staMatrix(:,cycleCounter) = dataSlice;
    staGate = gateSlice;
end

if median(staMatrix(:))<0,
    staMatrix = -1 * staMatrix;
end

% staMatrix = imfilter(staMatrix,ones(filterSize,1),'symmetric')./filterSize;



%%

numCyclesToUse = size(staMatrix,2);
cycleTime = cycleWidth*timeStep;
staTime = linspace(-previewCycle , (1-previewCycle), cycleWidth)*cycleTime;
staMean = mean(staMatrix,2);
staSTD = std(staMatrix,0,2);
staSTERR = staSTD/sqrt(numCyclesToUse);

filterSize = filterSize_sec./timeStep;
filterSize = max(1,round(filterSize));
staMean = imfilter(staMean,ones(filterSize,1),'symmetric')./filterSize;
staSTD = imfilter(staSTD,ones(filterSize,1),'symmetric')./filterSize;
staSTERR = imfilter(staSTERR,ones(filterSize,1),'symmetric')./filterSize;


figure(3);plot(staTime,staMean,'r-');hold on
figure(3);plot(staTime,staMean+staSTERR,'b-');
figure(3);plot(staTime,staMean-staSTERR,'b-');
figure(3);plot(staTime,staGate*max(staMatrix(:)),'g-');hold off
set(gca,'Ylim',[min(staMean-staSTERR),max(staMean+staSTERR)]);
ylabel('[micrometers] or [micrometers/second]');
xlabel('Time [seconds]');

staDataStruct.creationDate = datestr(now);
staDataStruct.staMatrix = staMatrix;
staDataStruct.staTime = staTime;
staDataStruct.staMean = staMean;
staDataStruct.staSTD = staSTD;
staDataStruct.staSTERR = staSTERR;
staDataStruct.staGate = staGate;
staDataStruct.cycleWidth = cycleWidth;
staDataStruct.timeStep = timeStep;
staDataStruct.cyclesToReject = cyclesToReject; %replaces [] if auoReject was used

  

 %v1 = staMatrix;
 %v2 = staMatrix;
 %v3 = staMatrix;
 %staMatrix = cat(2,v1,v2,v3);
    
    
    
    
    
    
end
    