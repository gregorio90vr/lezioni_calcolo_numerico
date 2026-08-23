

function RFR_03B_DVA_statistics_writing_excel_results  ...
                   (RFR_Str_config, RFR_Str_lists, date_calc, ...
                      VecRow_terms  , M3D_statistics)

%  ------------------------------------------------------------------------
%%  1. Writing in excel controls volatility for all currencies. Str_vola
%  ------------------------------------------------------------------------  
    
%    RFR_config_mat_file = RFR_01_basic_setting_config;

%    load(RFR_config_mat_file)

    
    file_storage = fullfile(RFR_Str_config.folders.path_RFR_07_DVA,...
                                     'RFR_DLT_Statistics.xlsx');

    
    num_writings = 4 * length(VecRow_terms) + 1; 

    sheet_id = cell(num_writings, 1);
    data_id  = cell(num_writings, 1);
    range_id = cell(num_writings, 1);

    counter_writings = 0;

    for k_run = VecRow_terms        
        
        name_sheet = strcat('DLT_stats_', num2str(VecRow_terms(k_run)), 'Y');     

        %   ===================================================================        
       
        
        counter_writings = counter_writings + 1;
        sheet_id{counter_writings} = name_sheet;
        aux = cell(100,100); 
        data_id{counter_writings} = aux;
        range_id{counter_writings} = calcexcelrange(11, 2, size(aux,1), size(aux,2));

        
        counter_writings = counter_writings + 1;
        sheet_id{counter_writings} = name_sheet;
        aux = M3D_statistics(:, k_run + 1, :);
        aux = reshape(aux , size(M3D_statistics,1), ...
                               size(M3D_statistics,3));
        aux = aux';
        
        if k_run > 10
            control_empties = sum(aux(:, [2 3 5 6 8 9 10 11]) == 0, 2);
            rows_non_empties =(control_empties < 7);
            aux = aux(rows_non_empties, :);
        end
        
        if isempty(aux)
           aux ={'No currency with market data for this maturity'};
        end
        
        data_id{counter_writings} = aux;
        range_id{counter_writings} = calcexcelrange(11, 3, size(aux,1), size(aux,2));

        
        counter_writings = counter_writings + 1;
        sheet_id{counter_writings} = name_sheet;       
        col_ISO3166 = RFR_Str_lists.Str_numcol_curncy.ISO3166;
        aux = RFR_Str_lists.C2D_list_curncy(:, col_ISO3166);
        
        if k_run > 10
            aux = aux(rows_non_empties, :);
            %   vector  'rows_non_empties'  calculated just above
        end
        
        if isempty(aux)
           aux ={''};
        end
        
        data_id{counter_writings} = aux;
        range_id{counter_writings} = calcexcelrange(11, 2, size(aux,1), size(aux,2));
        
        
        counter_writings = counter_writings + 1;
        sheet_id{counter_writings} = name_sheet;
        aux ={'Zero observations' , 'Median zero spot rate', 'Linear growth', ...
                'Interquartile range / Median for rates' , 'Num. Rates Outliers', ...
                'Last 21-days volat', ...
                'Interquartile range / Median for diffs' , 'Num. Diffs Outliers', ...
                'Last Roll measure' , 'Perctile 90 Roll', ...
                'Perctile 90 log returns'};
        data_id{counter_writings} = aux;
        range_id{counter_writings} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    end
        
    
    counter_writings = counter_writings + 1;
    sheet_id{counter_writings} = 'Master';
    aux = {strcat('Reference date__' , datestr(date_calc, 'dd-mm-yyyy'))};
    data_id{counter_writings} = aux;
    range_id{counter_writings} = calcexcelrange(2, 5, size(aux,1), size(aux,2));

    text_waitbar = 'Writing DLT statistics --> RFR_DLT_Statistics.xlsx';
    
    xlswrite_mult(file_storage , data_id  , sheet_id  , range_id ,  text_waitbar);

end