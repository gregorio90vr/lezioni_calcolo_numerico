load ws

C1C_import = fieldnames(Str_new_iBoxx_data);

M2D_sum_import = zeros(length(C1C_import), 6);

for k = 1:length(C1C_import)                
        M2D_sum_import(k,:) = sum(Str_new_iBoxx_data.(C1C_import{k})(:,2:end),1);
end

load('Str_Corporates.mat')

C1C_original = fieldnames(Str_Corporates_iBoxx_Bid);

M2D_sum_original = zeros(length(C1C_original), 6);

for k = 1:length(C1C_original)
       M2D_sum_original(k,:) = sum(Str_new_iBoxx_data.(C1C_original{k})(end-21:end,2:end), 1);
end

a=5;
