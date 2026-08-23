function [sanitizedCol] = sanitizeNaN(tableCol, method)
%SANITIZENAN Replaces table columns with NaN cells with the nearest previous value. 

    if nargin < 2
        method = 'previous';
    end
    
    if ~any(strcmpi(method,{'previous','zero'}))
        error('Selected method is invalid.');
    end

    sanitizedCol = zeros(size(tableCol));
    
    if strcmpi(method,'zero')
        sanitizedCol(~isnan(tableCol)) = tableCol(~isnan(tableCol));
    else
        if size(tableCol,1) == 2
            sanitizedCol = tableCol;
            sanitizedCol(2,isnan(sanitizedCol(2,:))) = ...
                sanitizedCol(1,isnan(sanitizedCol(2,:)));
        else
            xq = 1:size(tableCol,1);

            for iCol=1:size(tableCol,2)  
                x = xq(~isnan(tableCol(:,iCol)));

                sanitizedCol(:,iCol) = interp1(x,tableCol(x,iCol),xq,...
                    'previous','extrap');
            end
        end
    end
end

