function frameResults = diameter( imageData )
%DIAMETER Find the Full Width Half Maximum of extracted scan data
%(imageData) then return the calculation in the results struct.
%   return a struct for every frame (frameResults) and a vector that has a
%   datapoint for every frame (diameterVector)

    SMOOTHING = 1;
    FWHM_TO_DIAMETER = 1;   % will be a lookup table in the future
    
    % the user can choose to do a fast calculation (width is based on
    % threshold values) or a slow calculation (data is fit to a gaussian
    % and the width is determined from the resulting fitting parameters)
    title = 'Calculate Diameter';
    line1 = [ 'The diameter will be calculated from the Full Width at Half Maximum ', ...
              'of the extracted image data. The Half Maximum is just 1/2 of the Full Maximum.'];
    line2 = 'Would you like to simply use the maximum value in each window as the Full Maximum (fast)?';
    line3 = 'Or fit the data to a Gaussian distribution and use that to determine the Full Maximum (slow)?';
    qstring = sprintf('%s\n\n%s\n%s', line1, line2, line3);
    fast = 'Simple max (fast)';
    slow = 'Gaussian (slow)';
    answer = questdlg(qstring, title, fast, slow, fast); 
    
    switch answer
        case fast
            fitToGaussianFlag = false;
        case slow
            fitToGaussianFlag = true;
        otherwise
            disp('Diameter calculation canceled.');
            return;
    end
    
    frameResults = struct(...
        'image', [],...
        'leftWidthPoint', 0,...
        'rightWidthPoint', 0,...
        'centerPoint', 0,...
        'fwhm', 0,...
        'coefficients', 0 );
    
    nFrames = size(imageData, 3);
    diameterVector = zeros(nFrames, 1);
    
    % initialize a waitbar
    waitbarHandle = waitbar(0, 'Time Remaining: ',...
                            'Name', 'Calculating Diameter...',...
                            'WindowStyle', 'modal' );
    startTime = clock;                   
    
    for frameIndex = 1 : nFrames
        dataVector = mean(imageData(:,:,frameIndex));
        
        % subtract the offset first
        dataVector = dataVector - min(dataVector);

        [fwhm, leftWidthPoint, rightWidthPoint, coefficients, halfMax] = ...
                          calcFWHM(dataVector, SMOOTHING, fitToGaussianFlag);
        

        widthDifference = (FWHM_TO_DIAMETER - 1) * fwhm;
        diameterVector(frameIndex) = FWHM_TO_DIAMETER * fwhm; 
        
        frameResults(frameIndex).image = dataVector;
        frameResults(frameIndex).fwhm = fwhm;
        frameResults(frameIndex).coefficients = coefficients;

        frameResults(frameIndex).leftWidthPoint = ...
            floor(leftWidthPoint - widthDifference / 2 );
        
        frameResults(frameIndex).rightWidthPoint = ...
            ceil(rightWidthPoint + widthDifference / 2 );
        
        frameResults(frameIndex).centerPoint = ...
            [ (leftWidthPoint + rightWidthPoint)/2, halfMax ]; 
        
        % also, calculate how much time is remaining
        currentTime = clock;
        elapsedTime = etime(currentTime, startTime);
        secondsPerFrame = elapsedTime / frameIndex;
        secondsRemaining = floor(( nFrames - frameIndex ) * secondsPerFrame);
        waitbarMessage = sprintf('About %d seconds remaining.', secondsRemaining);
        
        waitbar(frameIndex/nFrames, waitbarHandle, waitbarMessage);
    end
    
    close(waitbarHandle);

end

