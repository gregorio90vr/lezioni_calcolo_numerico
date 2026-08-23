function range = calcexcelrange(i,j,m,n)
% Calcula un rango de Excel en notación A1, 
% Empezando en al fila i columna j
% para incluir un rango de diemnsion m x n
% Tamaño mínimo del rango de 1 x 1
% Created by Hugo González Riera (november 2005)

% Construimos la primera fila
if (m<=0 || n<=0)
    error('MATLAB:xlswrite:CalculateRange',...
        'Minimun size of matrix is 1 x 1 (tamaño mínimo 1 x 1)');
end

firstrow=i;
lastrow=firstrow+m-1 ;
firstrow=num2str(firstrow);   
lastrow=num2str(lastrow);

% Construimos la primera columna.
try
    firstcol = dec2base27(j); 
catch
    error('MATLAB:xlswrite:CalculateRange',...
        'Data range must be between A1 and IV65536.');
end

%construimos la última columna
if (m==1 & n==1)
    range = [firstcol firstrow]; % rango final.
else
    
    try
        lastcol = dec2base27(j+n-1);
    
        range = [firstcol firstrow ':' lastcol lastrow]; % rango final.
    catch
        error('MATLAB:xlswrite:CalculateRange',...
            'Data range must be between A1 and IV65536.');
    end
end
%------------------------------------------------------------------------------
function s = dec2base27(d)

%   DEC2BASE27(D) returns the representation of D as a string in base 27,
%   expressed as 'A'..'Z', 'AA','AB'...'AZ', until 'IV'. Note, there is no zero
%   digit, so strictly we have hybrid base26, base27 number system.  D must be a
%   negative integer bigger than 0 and smaller than 2^52, which is the maximum
%   number of columns in an Excel worksheet.
%
%   Examples
%       dec2base(1) returns 'A'
%       dec2base(26) returns 'Z'
%       dec2base(27) returns 'AA'
%-----------------------------------------------------------------------------
b = 26;
symbols = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

d = d(:);
if d ~= floor(d) | any(d < 0) | any(d > 1/eps)
    error('MATLAB:xlswrite:Dec2BaseInput',...
        'D must be an integer, 0 <= D <= 2^52.');
end

% find the number of columns in new base
n = max(1,round(log2(max(d)+1)/log2(b)));
while any(b.^n <= d)
    n = n + 1;
end

% set b^0 column
s(:,n) = rem(d,b);
while n > 1 && any(d)
    if s(:,n) == 0
        s(:,n) = b;
    end
    if d > b
        % after the carry-over to the b^(n+1) column
        if s(:,n) == b
            % for the b^n digit at b, set b^(n+1) digit to b
            s(:,n-1) = floor(d/b)-1;
        else
            % set the b^(n+1) digit to the new value after the last carry-over.
            s(:,n-1) = rem(floor(d/b),b);
        end
    else
        s(:,n-1) = []; % remove b^(n+1) digit.
    end
    n = n - 1;
end
s = symbols(s);
%------------------------------------------------------------------------------
function d = base27dec(s)
%   BASE27DEC(S) returns the decimal of string S which represents a number in
%   base 27, expressed as 'A'..'Z', 'AA','AB'...'AZ', until 'IV'. Note, there is
%   no zero so strictly we have hybrid base26, base27 number system.
%
%   Examples
%       base27dec('A') returns 1
%       base27dec('Z') returns 26
%       base27dec('IV') returns 256
%-----------------------------------------------------------------------------

d = 0;
b = 26;
n = numel(s);
for i = n:-1:1
    d = d+(s(i)-'A'+1)*(b.^(n-i));
end
%-------------------------------------------------------------------------------
