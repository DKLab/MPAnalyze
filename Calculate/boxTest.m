function boxTest( )
%BOXTEST Testing -- a rectangular box moving through a cylinder
%   Detailed explanation goes here
x0 = -6;

syms x;
xCenter = zeros(30,1);
c = zeros(30,1);

for t = 0 : 10
    index = t + 1;
    
    xCenter(index) = x0 + t;
    c(index) = real(convolve(xCenter(index), t));
    
    hold on
    cla
    ezplot(rect(x, t), [-10, 10]);
    ezplot(vessel(x), [-10, 10]);
    
    plot(xCenter, c);

    title(sprintf('t = %d', t));
    hold off
    
    set(gca, 'YLim', [-10, 10]);
    animation(index) = getframe;
end
movie(animation, 4);



end

function y = convolve(x,t)
    XMIN = -20;
    XMAX = 20;
    %f = @(x,t) rect(x,t) .* vessel(x);
    
    yRect = rect(x,t);
    yVessel = vessel(x);
    
    y = rect(x,t) * vessel(x);
end

function y = vessel(x)
    RADIUS = 4;
    
    y = sqrt(RADIUS.^2 - x.^2);
end

function y = rect(x, t)
    SCALE = 0.5;
    HALF_WIDTH = 0.5;
    x0 = -6;
    y = SCALE * (heaviside(x - x0 - t + HALF_WIDTH) - heaviside(x - x0 - t - HALF_WIDTH)); 
end