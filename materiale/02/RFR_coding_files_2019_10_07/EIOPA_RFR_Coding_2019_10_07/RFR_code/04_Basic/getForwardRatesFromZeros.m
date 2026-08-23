function forwardRates = getForwardRatesFromZeros(zeroRates, tenors)
%GETFORWARDRATESFROMZEROS calculates the implied forward rates from given zero rates
% forwardRates = getForwardRatesFromZeros(zeroRates, tenors) takes annually 
% compounded zero coupon bond rates and their corresponding tenors and 
% converts them into their implied forward rates.
%
% Input: - zeroRates: nx1 double vector of annually compounded zero coupon
%                bond rates.
%        - tenors: nx1 double vector of tenors corresponding to the zero
%                coupon bond rates as given in zeroRates. It is assumed
%                that they are in strictly increasing order.
%
% Output: - forwardRates: nx1 double vector of annually compounded forward
%                rates as implied by the the zero coupon bond rates given
%                in the input of the function.

    discountRates = (1+zeroRates).^(-tenors);
    forwardRates = [zeroRates(1);...
        (discountRates(1:end-1)./discountRates(2:end)).^(1./diff(tenors))-1];
end