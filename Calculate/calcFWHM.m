function [width, point1, point2] = calcFWHM(data,smoothing)
% function which takes data and calculates the full-width, half max value
% half-max values are found looking in from the sides, i.e., the program will work
% even if the data dips to a lower value in the middle

point1 = [];
point2 = [];

data = double(data);

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
%width = lastI-firstI; % CM 20th may

