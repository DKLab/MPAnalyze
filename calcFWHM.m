function [width, point1, point2, coefficients] = calcFWHM(data, smoothing, fitToGaussianFlag)
% function which takes data and calculates the full-width, half max value
% half-max values are found looking in from the sides, i.e., the program will work
% even if the data dips to a lower value in the middle

if ~exist('fitToGaussianFlag', 'var')
    fitToGaussianFlag = false;
end

point1 = 0;
point2 = 0;
width = 0;
coefficients = [];

data = double(data);

if fitToGaussianFlag
    % find the FWHM by fitting the data to a Gaussian and calculating the
    % width from the fitting parameters
    GAUSS_FWHM = 2.3548;    % GAUSS_FWHM is just 2 * sqrt(2 * log(2))    
    
    X = 1 : length(data);
    Y = data;
    
    fitResult = fit(X', Y', 'gauss1');
%      figure, plot(fitResult);
%      hold on
%      plot(Y);
    coefficients = coeffvalues(fitResult);
    width = GAUSS_FWHM * coefficients(3);
    centerX = coefficients(2);
    
    point1 = centerX - width/2;
    point2 = centerX + width/2;
    
else
    % the remainder of this code is from the old version of calcFWHM.
    % the FWHM is calculated here by getting a vector of datapoints larger
    % than half the maximum value. The FWHM then just the length of this
    % vector
    
    % smooth data, if appropriate
    if nargin < 2
        % smoothing not passed in, set to default (none)
        smoothing = 1;
    end

    if smoothing > 1
        data = conv(data,rectwin(smoothing) ./ smoothing);
    end

    % subtract out baseline
    %mean_CM_INT=max(data (smoothing:smoothing+3));%% CM_implemented to define the intensity of the portion to see if light was flashed 20121126
    %data = data - min(data); %% used for normalization of the data CM
    %commentized it on the 20121126 because in case of smoothing the first and
    %the last points are equal to 0 therefore the minimum is always 0 and the
    %normalization does not happen because it subtracts 0
    baseline_to_sub=min(data(smoothing:(length(data)-smoothing)));
    data =data-baseline_to_sub; % The minimum is calculated on the second to the avant dernier point
    %assignin ('base','test_data',data); % CM_added 20121126 for test

    %%
    % calculating the full width at HALF MAXIMUM
    threshold = max(data)/2;

    aboveI = find(data > threshold);    % all the indices where the data is above half max

    if isempty(aboveI)
        % nothing was above threshold!
        width = 0;
        point1=0;
        point2=0;
        return
    end

    firstI = aboveI(1);                 % index of the first point above threshold
    lastI = aboveI(end);                % index of the last point above threshold

    % % CM 20130520 test
    % aboveI = find(data > threshold);
    % the_center_point=round(length(data))/2;
    % % vessel_mid_to_look=find (aboveI>(length(data)/2))
    % % vessel_mid_to_look=vessel_mid_to_look(1)
    % vessel_mid_to_look=length(data)/2;
    % % put a condition to make sure that there are point above and below
    % data_right=aboveI(find (aboveI>vessel_mid_to_look));
    % data_left=aboveI(find (aboveI<vessel_mid_to_look));

    % if (isempty(data_left) | isempty(data_right))
    %     width = 0;
    %      point1=0;
    %     point2=0;
    %     return
    % else
    % lastI = data_right(1) ;                % index of the first point above threshold
    % firstI = data_left(end);                % index of the last point above threshold


    % end

    % data_right=aboveI(vessel_mid_to_look:end)
    % data_left=aboveI(1:(vessel_mid_to_look-1))
    % lastI = data_right(1);                 % index of the first point above threshold
    % firstI = data_left(end);                % index of the last point above threshold
    % end test




    if (firstI-1 < 1) | (lastI+1) > length(data)
        % interpolation would result in error, set width to zero and just return ...
        width = 0;
         point1=0;
        point2=0;
        return
    end

    % use linear intepolation to get a more accurate picture of where the max was
    % find value difference between the point and the threshold value,
    % and scale this by the difference between integer points ...
    point1offset = (threshold-data(firstI-1)) / (data(firstI)-data(firstI-1));
    point2offset = (threshold-data(lastI)) / (data(lastI+1)-data(lastI));

    point1 = firstI-1 + point1offset;
    point2 = lastI + point2offset;

    width = point2-point1;
end

