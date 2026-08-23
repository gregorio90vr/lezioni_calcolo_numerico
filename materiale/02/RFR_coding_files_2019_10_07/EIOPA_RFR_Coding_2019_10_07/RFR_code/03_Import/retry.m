function [res] = retry(func, n)
%RETRY -> Retry function func n times until a non-empty result is obtained

    res = [];
    
    for i=1:n
       res =  func();
       
       if ~isempty(res)
           break
       end
    end
end

