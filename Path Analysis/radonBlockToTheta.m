function [theta sep] = radonBlockToTheta(block,thetaAccuracy,thetaRange)
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
uniformityCorr = 3;     % 0 is none, 1 through 4 are polynomial degrees, and -1 uses the mean

% set a value for the range of thetas, if one was not passed in
if ~exist('thetaRange','var')
    thetas = 1:179;
else
    thetas = min(thetaRange):max(thetaRange);
end

% set a value for the accuracy, if one was not passed in
if ~exist('thetaAccuracy','var')
    thetaAccuracy = .05;
end

% check to make sure size is correct
if ndims(block) ~= 2 || size(block,1) < 2 || size(block,2) < 2
    error 'function radonBlockToTheta only works with 2d matrices'
end

block = double(block);              % make sure this is a double
block = block - mean(block(:));     % subtract off mean

degree = uniformityCorr;

blockMean = mean(block,1);
xaxis = 1:length(blockMean);

if degree == -1
    blockMeanFit = mean(block,1);         % use the mean
elseif degree == 0
    blockMeanFit = 0*xaxis;               % don't subtract anything out
else
    % use a polynomial
    p = polyfit(xaxis,blockMean,degree);
    if degree == 1          
        blockMeanFit = p(1)*xaxis + p(2);   % first order correction
    elseif degree == 2
        disp 'gets to here' 
        blockMeanFit = p(1)*xaxis.^2 + p(2)*xaxis + p(3);  % second order correction
    elseif degree == 3
        blockMeanFit = p(1)*xaxis.^3 + p(2)*xaxis.^2 + p(3)*xaxis + p(4);  % second order correction
    elseif degree == 4
        blockMeanFit = p(1)*xaxis.^4 + p(2)*xaxis.^3 + p(3)*xaxis.^2 + p(4)*xaxis + p(5);  % second order correction
    end
end

% remove
for i = 1:size(block,1)
    block(i,:) = block(i,:) - blockMeanFit;
end

block = block - mean(block(:));  % make sure mean is still zero

%% now, do the radon stuff
% initial transform, over entire theta range
rb = radon(block,thetas);            % take radon transform

vrb = var(rb);                       % look at the variance

%plot(vrb)
%plot(blockMeanFit)
%pause

vrbMean = mean(vrb);                 % the mean of the variance, used for sep

maxVarIndex = find(vrb==max(vrb));   % find where the max took place
                                     % note this could be more than one place!

thetaInitial = thetas(round(mean(maxVarIndex)));        % theta, accuarate to within 1 degree

% we now have a rough idea of the angle, search with higher accuracy around this point
searchAroundDegrees = 1.5;                              % number of degrees to search around answer
thetas_highRes = thetaInitial-searchAroundDegrees: ...
         thetaAccuracy: ...
         thetaInitial+searchAroundDegrees;              % new set of thetas - smaller range, more accurate

rb_highRes = radon(block,thetas_highRes);
vrb_highRes = var(rb_highRes);                          % look at the variance

maxVarIndex_highRes = find(vrb_highRes==max(vrb_highRes));      % find the indices of the max - could be more than one!
theta = mean(thetas_highRes(maxVarIndex_highRes));              % theta, high accuracy

sep = mean(vrb_highRes(maxVarIndex_highRes)) / vrbMean;  