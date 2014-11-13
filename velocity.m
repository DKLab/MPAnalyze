function results = velocity( imageStack )
%VELOCITY Calculates the Radon transform of a stack of image frames and
%returns a struct array that will be used by Path Analyze to display the
%results

    % UNIFORMITY_CORRECTION is the degree of the polynomial used to fit to
    % the mean intensity of the image. The polynomial is then subtracted
    % from the image to ensure uniform intensity (this is needed for the
    % Radon transform)
    UNIFORMITY_CORRECTION = 3;
    
    nFrames = size( imageStack, 3 );

    % initialize a waitbar
    waitbarHandle = waitbar(0, 'Time Remaining: ',...
                            'Name', 'Calculating Velocity...',...
                            'WindowStyle', 'modal' );
    startTime = clock;                   
    
    results(nFrames) = struct(...
        'transform', [],...
        'angle', 0,...
        'separability', 0);
    
    for frameIndex = 1 : nFrames
       
        % transpose and flip the image so that the Radon Transfrom returns
        % an angle relative to the horizontal (positive x) axis of the
        % unflipped, untransposed image
        block = flipud(transpose(imageStack(:,:,frameIndex)));
        
        [transform, angle, separability] = ...
            radonTransform( block, UNIFORMITY_CORRECTION, 1:179, 0.5, frameIndex == 1);
        
        % convert the angle from degrees to radians
        results(frameIndex).angle = angle * pi / 180;
        results(frameIndex).separability = separability;
        results(frameIndex).transform = transform;
     
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

