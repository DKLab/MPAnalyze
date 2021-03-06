function [transform, transformAngle, separability] = ...
        radonTransform(block, uniformityCorrection, angleRange, angleAccuracy, isFirstRun)
% function takes a block of data (typically a stack of linescans across the relevant part of a vessel)
% and returns the angle (theta, in degrees) from vertical of the streaks in that block
%   vertical lines will have a theta of 0, and
%   horizontal lines will have a theta of 90
%   (the radon transform is in degrees)
%
% sep is the separability, which is defined as the (max variance)/(mean variance)
% over the thetaRange
%
% uniformity correction
%  if the block of data is not uniform (i.e., brigher to one side or the other)
%  the Radon transform will tend to see this as a stack of vertical lines
%  the solution is to fit a low-order polynomial (typically 2nd order) to
%  the mean intensity along the horizonatal axis, and subtarct this from
%  the image
SEARCH_AROUND_DEGREES = 1.5;
persistent lastMaxVarianceIndex;
% the sum and count are used to compute a running average
persistent lastMaxVarianceIndexSum;
persistent lastMaxVarianceIndexCount;


if ~exist( 'uniformityCorrection', 'var') 
    uniformityCorrection = 3;     % CHANGE: -1 is none, 0+ is the maximum degree
                                  % of the polynomial used to fit to the
                                  % data s.t. degree = 0 is just the mean
end

% set a value for the range of thetas, if one was not passed in
if ~exist('angleRange','var')
    angleVector_rough = 1:179;
else
    angleVector_rough = min(angleRange):max(angleRange);
end

% set a value for the accuracy, if one was not passed in
if ~exist('angleAccuracy','var')
    angleAccuracy = .05;
end

% check to make sure size is correct
if ndims(block) ~= 2 || size(block,1) < 2 || size(block,2) < 2
    error 'function radonBlockToTheta only works with 2d matrices'
end

block = double(block);              % make sure this is a double
block = block - mean(block(:));     % subtract off mean


blockMean = transpose(mean(block,2));
xaxis = 1:length(blockMean);


% the uniformityCorrection is the degree of the polynomial that will be
% used to ensure that the mean intensity of the block is uniform
% when unifomityCorrection is -1, nothing is subtracted.
% when uniformityCorrection is 0, the mean is subtracted
if uniformityCorrection >= 0
    p = polyfit( xaxis, blockMean, uniformityCorrection);
    blockMeanFit = transpose(polyval(p, xaxis));
else
    blockMeanFit = zeros( length(xaxis), 1 );
end


% remove
% pre/post block for debugging
for i = 1:size(block,1)
   block(:,i) = block(:,i) - blockMeanFit;
end


block = block - mean(block(:));  % make sure mean is still zero


%% now, do the radon stuff
% initial transform, over entire theta range
transform = radon( block, angleVector_rough);            % take radon transform
variance_rough = var(transform);% look at the variance

%{
% trying something new:
% instead of finding the max variance, find a few places that are close to
% the max variance.
maxThreshold = max(variance_rough) * 1;

maxVarIndex = find(variance_rough >= maxThreshold);   % find where the max took place
                                     % note this could be more than one place!
% output the indicies of where the max variance occurs
maxVarianceRows = maxVarIndex;
%}

% Using findpeaks to find all local maxima instead of using max to find the
% global maxima
minPeakHeight = max(variance_rough) / 4;
[peaks, maxVarianceIndex] = findpeaks(variance_rough, 'minPeakHeight', minPeakHeight);

if isempty(lastMaxVarianceIndex) || exist('isFirstRun', 'var') && isFirstRun
    % this is the first frame to be calculated, lastMaxVarianceIndex hasn't
    % been set yet so:
    % just set the lastMaxVarianceIndex to the maxVarianceIndex
    % coresponding to the largest peak
    
    [maxValue, maxIndex] = max(variance_rough);
    lastMaxVarianceIndex = maxIndex;
    lastMaxVarianceIndexSum = maxIndex;
    lastMaxVarianceIndexCount = 1;
end

% choose the index that is closest to the last index
[smallestDifference, closestIndex] = min((maxVarianceIndex - lastMaxVarianceIndex).^2);
closestMaxVarianceIndex = maxVarianceIndex(closestIndex);

% set the new lastMaxVarianceIndex by updating the running average
lastMaxVarianceIndexSum = lastMaxVarianceIndexSum + closestMaxVarianceIndex;
lastMaxVarianceIndexCount = lastMaxVarianceIndexCount + 1;
lastMaxVarianceIndex = lastMaxVarianceIndexSum / lastMaxVarianceIndexCount;

angle_rough = angleVector_rough( round(mean(closestMaxVarianceIndex)) );        % theta, accuarate to within 1 degree

% we now have a rough idea of the angle, search with higher accuracy around this point
angleVector = angle_rough - SEARCH_AROUND_DEGREES: ...
         angleAccuracy: ...
         angle_rough + SEARCH_AROUND_DEGREES;              % new set of thetas - smaller range, more accurate

transform_precise = radon( block, angleVector );
variance = var( transform_precise );                          % look at the variance


maxVarIndex = find( variance == max(variance) );      % find the indices of the max - could be more than one!

transformAngle = mean( angleVector(maxVarIndex) );              % theta, high accuracy

separability = mean( variance(maxVarIndex) ) / mean( variance );