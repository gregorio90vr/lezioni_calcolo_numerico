function [curveTenors,curveSpotRates,curvePrices,curveForwardRates,...
    curveSwapRates,fittedAlpha,qbVector,cashFlowTimes] = ...
                RFR_06B_extrapol_scanning(couponFrequency, ...
                convergencePeriod, lastLiquidPoint, ultimateForwardRate, ...
                          convergenceTolerance, minAlpha, tenors, rates) 
%   This code performs the calculation of the Smith-Wilson 
%   interpolation and extrapolation methodology. 
                            
%   INPUTS  ---------------------------------------------------------------
%
%      couponFrequency - dimension: 1-by-1
%                    structure: scalar that contains the coupon frequency
%                               for the observed curve
%                    range      0 = zero; 1 = annual; 2; 3; 4; 12 = monthly
%
%      convergencePeriod  - dimension: 1-by-1
%                    structure: scalar that contains the number of years
%                               after the last liquid point(the highest maturity
%                               included in "VecCol_rates") at which
%                               convergence to the UFR should be achieved.
%
%       lastLiquidPoint        - dimension: 1-by-1
%                    structure: scalar that contains the LLP
%
%       ultimateForwardRate       - dimension: 1-by-1
%                    structure: scalar that contains the UFR level in
%                               percentages, e.g. 4.2.
%
%       convergenceTolerance   - dimension: 1-by-1
%                    structure: scalar that contains the convergence
%                               criteria for the forward curve, i.e. the accepted
%                               error at the horizon at which the forward rate should
%                               converge to the UFR. The number should be provided in
%                               percentages(the standard value is 1bp i.e. min_diff=0.01)
%
%      tenors      dimension: column vector maturies-by-1   
%                    structure: column = maturities in years, at which rates are observed
%                               
%      rates  dimension: column vector swap rates-by-1
%                              (or government bonds where relevant)
%                    structure: column = swap rates in percentages 
%                      (not decimal form, e.g. 1.4 for 1.4% and not 0.014)
%                    note    :the input swap rates should be adjusted for

%
%   0UTPUTS  --------------------------------------------------------------                              
% 
%       curveTenors         1 column vector with the maturities in years 
%                          (1, 2, 3, ... 150 years)
%
%       curveSpotRates  Column vector 150 rows with spot rates percentages
%       curveForwardRates(idem)
%       curvePrices       1 column vector with prices in percentages
%
%       fittedAlpha  - dimension: 1-by-1
%                    structure: scalar that holds the re-optimised value of
%                               the alpha parameter
%
%       qbVector  matrix with the parameters of Smith Wilson for alpha fit
%
%   -----------------------------------------------------------------------
  
    MAX_TENOR = 150;
    NOTIONAL_AMOUNT = 100;
    
    %% Calculation of the cash flow matrix
    nInstruments = size(rates, 1);

    if couponFrequency > 0        
        cashFlowTimes = (1/couponFrequency:1/couponFrequency:max(tenors));
        cashFlowsPerInstrument  = tenors .* couponFrequency;
    else
        cashFlowTimes = (1:max(tenors));
    end

    nCashflows = length(cashFlowTimes);
    cashFlowMatrix = zeros(nInstruments, nCashflows);

    for instrument = 1:nInstruments 
        if couponFrequency > 0
            cashFlowMatrix(instrument,:) = ...
                  [((rates(instrument) / couponFrequency) .* ones(1, cashFlowsPerInstrument(instrument)))...
                    zeros(1, nCashflows - cashFlowsPerInstrument(instrument))];
                
            cashFlowMatrix(instrument, tenors(instrument) * couponFrequency) = ...
                         cashFlowMatrix(instrument, tenors(instrument) * couponFrequency) + NOTIONAL_AMOUNT;
        else
            cashFlowMatrix(instrument, tenors(instrument)) = ...
                         NOTIONAL_AMOUNT * (1 + rates(instrument) / 100) ^ tenors(instrument); 
        end        
    end

    cashFlowMatrix = cashFlowMatrix ./ 100 ;
    convergenceTolerance = convergenceTolerance / 100;
    
    %% Calibration of the alpha parameter
    minUV = min(repmat(cashFlowTimes', 1, nCashflows), ...
                    repmat(cashFlowTimes, nCashflows, 1));
                      
    maxUV = max(repmat(cashFlowTimes', 1, nCashflows), ...
                    repmat(cashFlowTimes, nCashflows, 1)); 

    ultimateForwardIntensity = log(1 + ultimateForwardRate/100);
    
    discountFactors = exp(-ultimateForwardIntensity * cashFlowTimes');
    discountedCashFlows = cashFlowMatrix' .* repmat(discountFactors, 1, nInstruments);

    [fittedAlpha,qbVector] = optimizeAlpha();
    
    %% Calculation of measures for the whole curve
    if couponFrequency > 0
        curveTenors = (1/couponFrequency:1/couponFrequency:MAX_TENOR)';
        
        minUV = min(repmat(curveTenors,  1, lastLiquidPoint * couponFrequency ), ...
                        repmat((1/couponFrequency:1/couponFrequency:lastLiquidPoint), ...
                        length(curveTenors), 1));

        maxUV = max(repmat(curveTenors, 1, lastLiquidPoint * couponFrequency ), ...
                        repmat((1/couponFrequency:1/couponFrequency:lastLiquidPoint), ...
                        length(curveTenors), 1));
    else
        curveTenors = (1:MAX_TENOR)';
        minUV = min(repmat(curveTenors, 1, lastLiquidPoint), ...
                        repmat((1:lastLiquidPoint), length(curveTenors), 1));

        maxUV = max(repmat(curveTenors, 1, lastLiquidPoint), ...
                        repmat((1:lastLiquidPoint), length(curveTenors), 1));        
    end
            
    hMatrix = (fittedAlpha * minUV) - exp(-fittedAlpha * maxUV) .* ...
        sinh(fittedAlpha * minUV);
            
    curvePrices = exp(-ultimateForwardIntensity * curveTenors) .* ...
        (1 + hMatrix * qbVector);
    curveSwapRates = couponFrequency * (1-curvePrices) ./ cumsum(curvePrices);
    
    % Select only integer tenors
    if couponFrequency > 0
        tenorSelection = couponFrequency:couponFrequency:MAX_TENOR*couponFrequency;
    else
        tenorSelection = 1:1:MAX_TENOR;
    end
        
    curveTenors = curveTenors(tenorSelection);
    curvePrices = curvePrices(tenorSelection);
    curveSpotRates = exp(-log(curvePrices) ./ curveTenors) - 1;
    curveForwardRates = getForwardRatesFromZeros(curveSpotRates, curveTenors);   
    curveSwapRates = curveSwapRates(tenorSelection);
    
    % Keep the optimization in this way in order to be compliant with
    % previous versions.
    function [alpha,qbVector] = optimizeAlpha()
        steps = [0.1,0.01,0.001,0.0001,0.00001,0.000001];

        lowerBound = steps(1);
        upperBound = 1;
        
        for i=1:length(steps)
            for alpha = lowerBound:steps(i):upperBound
                [qbVector,calculatedForwardIntensity] = ...
                    getConvergenceParameters(alpha, minUV, maxUV, discountedCashFlows);

                diff_bp = ultimateForwardIntensity - calculatedForwardIntensity; 

                if abs(diff_bp) < convergenceTolerance   
                    break
                end
            end
            
            lowerBound = alpha-steps(i);
            upperBound = alpha;
        end
        
        if alpha < minAlpha
            alpha = minAlpha;

            [qbVector,~] = ...
                getConvergenceParameters(alpha, minUV, maxUV, discountedCashFlows);
        end
    end

    function [qb,convergenceForwardIntensity] = getConvergenceParameters(alpha, ...
            minUV, maxUV, discountedCashFlows)
        hMatrix = (alpha * minUV) - exp(-alpha * maxUV) .* sinh(alpha * minUV);

        E = inv(discountedCashFlows' * hMatrix * discountedCashFlows);
        qb = discountedCashFlows * (E * (1 - sum(discountedCashFlows))');

        kappa = (1 + alpha * (qb' * cashFlowTimes')) / ...
                (qb' * sinh(alpha * cashFlowTimes'));            

        convergenceForwardIntensity = ultimateForwardIntensity + ...
            alpha / (1 - kappa * exp(alpha * (lastLiquidPoint + convergencePeriod)));    
    end
end