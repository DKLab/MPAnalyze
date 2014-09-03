function [width, point1, point2, coefficients, halfMax] = calcFWHM(data, smoothing, fitToGaussianFlag)
% function which takes data and calculates the full-width, half max value
% half-max values are found looking in from the sides, i.e., the program will work
% even if the data dips to a lower value in the middle

    if ~exist('fitToGaussianFlag', 'var')
        fitToGaussianFlag = false;
    end

    point1 = 0;
    point2 = 0;
    width = 0;
    halfMax = 0;
    coefficients = [];

    data = double(data);

    if fitToGaussianFlag
        % NEW METHOD: use the maximum from the fitted gaussian to determine the
        % half max threshold, and count pixels to determine width

        X = 1 : length(data);
        Y = data;

        fitResult = fit(X', Y', 'gauss1');
        coefficients = coeffvalues(fitResult);
        halfMax = coefficients(1)/2;
        [width, point1, point2] = countWidth(data, halfMax);

       %{
        % OLD METHOD (calculatnig FWHM from the width fitting parameter)
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
        %}

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

        halfMax = max(data)/2;
        [width, point1, point2] = countWidth(data, halfMax);
    end
end

function [width, point1, point2] = countWidth(data, halfMaxThreshold)
     % calculating the full width at HALF MAXIMUM

    aboveI = find(data > halfMaxThreshold);    % all the indices where the data is above half max

    if isempty(aboveI)
        % nothing was above threshold!
        width = 0;
        point1 = 0;
        point2 = 0;
        return;
    end

    firstI = aboveI(1);                 % index of the first point above threshold
    lastI = aboveI(end);                % index of the last point above threshold


    if (firstI-1 < 1) || (lastI+1) > length(data)
        % interpolation would result in error, set width to zero and just return ...
        width = 0;
        point1 = 0;
        point2 = 0;
        return
    end

    % use linear intepolation to get a more accurate picture of where the max was
    % find value difference between the point and the threshold value,
    % and scale this by the difference between integer points ...
    point1offset = ( halfMaxThreshold - data(firstI-1) ) /...
                    ( data(firstI) - data(firstI-1) );
                
    point2offset = ( halfMaxThreshold-data(lastI) ) /...
                    ( data(lastI+1) - data(lastI) );

    point1 = firstI-1 + point1offset;
    point2 = lastI + point2offset;

    width = point2-point1;
end
