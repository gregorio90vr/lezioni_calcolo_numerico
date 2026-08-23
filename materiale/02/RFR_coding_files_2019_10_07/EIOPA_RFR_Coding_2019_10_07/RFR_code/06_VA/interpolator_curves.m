

function [y_complete,x_complete] = interpolator_curves(y_original, x_original) 


%   ----------------------------------------------------------------------
%%  This funtions completes the terms of a curve until maturity 60
%   The output is a curve with 600 terms,(duration steps are decimals)
%   ----------------------------------------------------------------------


%   Preventing the case with no market rates as input or only one market rate
%   -------------------------------------------------------------------------

    posic_nonzeros =(y_original ~= 0);

    if sum(posic_nonzeros) <= 1
	
       %  either there is no market rates or there is a single market rate

       y_complete = zeros(1, 600);
       x_complete =(1:600);

       return
    end

    y_original = y_original(posic_nonzeros);
    x_original = x_original(posic_nonzeros);


%   Interpolation of market rates
%   -------------------------------------------------------------------------

    x_original = round(10 * x_original);
        %   In the case of corporate indices the durations is not integer
        %   With this instruction the first decimal is considered
        %   and the durations become integer

    x_complete =(1:600);

    y_complete =  interp1(x_original, y_original, x_complete, 'linear');
    

    
%   Extrapolated rates are equal to the last originally observed
%   --------------------------------------------------------------------------
    
    terms_to_extrapolate = x_complete(x_complete >= x_original(end));
        
    y_complete(terms_to_extrapolate) = y_original(end);
       


%   Rates below the first maturity are equal to the first rate
%   --------------------------------------------------------------------------

    terms_to_extrapolate = x_complete(x_complete <= x_original(1));
    
    y_complete(terms_to_extrapolate) = y_original(1);

end

