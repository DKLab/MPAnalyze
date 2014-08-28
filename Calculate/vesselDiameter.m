function width = vesselDiameter( imageFrame )
%DIAMETER Calculate the diameter of a blood vessel from cropped line scan
%data. First get the Full Width at Half Maximum (FWHM) and then multiply by
%2/sqrt(3) to get the width of the vessel
%   The image of the blood vessel is formed by the convolution of a
%   cylindar (the vessel) and an ellipsoid (the excitation region of the
%   two photon microscope). For vessels with a radius >> excitation region
%   width, the excitation region can be approximated as a Dirac delta
%   function such that the convolution of the delta function and a half
%   circle is just the same half circle. The FWHM of a half circle is
%   sqrt(3)/2 times its diameter. So to calculate the diameter of the
%   blood vessel, we can just find its FWHM and divide by sqrt(3)/2 to get 
%   the vessel diameter.

    frameWidth = size(imageFrame, 2);
    frameHeight = size(imageFrame, 1);
   
    SMOOTHING = 1;
    dataVector = mean(imageFrame);
    
    [fwhm, leftBoundary, rightBoundary] = calcFWHM(dataVector, SMOOTHING);
    
    
end


