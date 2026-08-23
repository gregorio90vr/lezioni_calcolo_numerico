

function RFR_06B_Bid_Ask_statistics_writing_excel_results  ...
                    (RFR_Str_config, RFR_Str_lists, date_calc, ...
                      VecRow_terms  , M3D_stats_bid_ask_spread)
 




%  ------------------------------------------------------------------------
%%  1. Writing in excel controls volatility for all currencies. Str_vola
%  ------------------------------------------------------------------------  
    
%    RFR_config_mat_file = RFR_01_basic_setting_config;
%    load(RFR_config_mat_file)

    col_ISO3166 = RFR_Str_lists.Str_numcol_curncy.ISO4217;
        
        %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing ISO3166
        %   for each of the currencies / countries considered 

    file_storage = fullfile(RFR_Str_config.folders.path_RFR_07_DVA,...
                                     'RFR_Bid_Ask_Statistics.xlsx');

    
    num_writings = 4 * length (VecRow_terms) + 1; 

    sheet_id = cell (num_writings, 1);
    data_id  = cell (num_writings, 1);
    range_id = cell (num_writings, 1);

    counter_writings = 0;
   
    
    
    for k_run = VecRow_terms        
        
        name_sheet = strcat('Bid_ASk_', num2str (VecRow_terms (k_run)), 'Y');     

        %   ===================================================================        
       
        
        counter_writings = counter_writings + 1;
        sheet_id{counter_writings} = name_sheet;
        aux = cell(100,100); 
        data_id{counter_writings} = aux;
        range_id{counter_writings} = calcexcelrange(11, 2, size(aux,1), size(aux,2));

        
        counter_writings = counter_writings + 1;
        sheet_id{counter_writings} = name_sheet;
        aux = M3D_stats_bid_ask_spread (:, k_run, :);
        aux = reshape (aux , size(M3D_stats_bid_ask_spread,1), ...
                               size(M3D_stats_bid_ask_spread,3));
        aux = aux';
            control_empties = sum(aux(:, :) == 0, 2);
            rows_non_empties = (control_empties < 7);
            aux = aux (rows_non_empties, :);
        
        if isempty(aux)
           aux ={'No currency with market data for this maturity'};
        end
        
        data_id{counter_writings} = aux;
        range_id{counter_writings} = calcexcelrange(11, 3, size(aux,1), size(aux,2));

        
        counter_writings = counter_writings + 1;
        sheet_id{counter_writings} = name_sheet;
        aux = RFR_Str_lists.C2D_list_curncy (:, col_ISO3166);
        aux = aux (rows_non_empties, :);
            %   vector  'rows_non_empties'  calculated just above
        
        if isempty(aux)
           aux ={''};
        end
        
        data_id{counter_writings} = aux;
        range_id{counter_writings} = calcexcelrange(11, 2, size(aux,1), size(aux,2));
        
        
        counter_writings = counter_writings + 1;
        sheet_id{counter_writings} = name_sheet;
        aux ={'Zero observations' , 'Median non-zero spreads', ...
                'Percentile 80 non-zero spreads', 'Maximum spread ', ...
                'Average non-zero spreads', 'Last non-zero spread' , ...
                'Zero observations' , 'Median non-zero spreads', ...
                'Percentile 80 non-zero spreads', 'Maximum spread ', ...
                'Average non-zero spreads', 'Last non-zero spread'};
        data_id{counter_writings} = aux;
        range_id{counter_writings} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    end
        
    
    counter_writings = counter_writings + 1;
    sheet_id{counter_writings} = 'Master';
    aux ={strcat('Reference date__' , datestr(date_calc, 'dd-mm-yyyy'))};
    data_id{counter_writings} = aux;
    range_id{counter_writings} = calcexcelrange(2, 5, size(aux,1), size(aux,2));
    

    text_waitbar = 'Writing Bid_Ask spread statistics --> RFR_Bid_Ask_Statistics.xlsx';
    
    xlswrite_mult (file_storage , data_id  , sheet_id  , range_id ,  text_waitbar);

end
