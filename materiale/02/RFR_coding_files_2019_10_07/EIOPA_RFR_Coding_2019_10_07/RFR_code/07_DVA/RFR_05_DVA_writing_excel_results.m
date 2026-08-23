

function RFR_05_DVA_writing_excel_results ...
                        (RFR_config_mat_file, VecRow_terms, Str_vola)




%  ------------------------------------------------------------------------
%%  1. Writing in excel controls volatility for all currencies. Str_vola
%  ------------------------------------------------------------------------  

    load(RFR_config_mat_file)
              
    col_ISO3166 = RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_ISO4217 = RFR_Str_lists.Str_numcol_curncy.ISO4217;
    %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy' containing ISO3166 and ISO4217 
        %   for each of the currencies / countries considered.
    
    file_storage = fullfile(RFR_Str_config.folders.path_RFR_07_DVA,...
                                     'RFR_DVA_control.xlsx');

    
    load(fullfile(RFR_Str_config.folders.path_RFR_99_Workspace, ...
                                         'RFR_DVA_workspace'))

    
    %   Creation of a column vector controling countries to process
    %   For the purpose of this function euro zone countries are excluded
    
    VecCol_with_curves = ~strcmp(RFR_Str_lists.C2D_list_curncy(:,col_ISO4217), 'EUR');
    
    %   Euro currency as a whole should be included
    VecCol_with_curves(1)= 1;
    
    
    num_writings = 2 + (12 * sum(VecCol_with_curves)); 

    sheet_id = cell (num_writings, 1);
    data_id  = cell (num_writings, 1);
    range_id = cell (num_writings, 1);

    counter_writings = 0;
    
    num_currencies = size(RFR_Str_lists.C2D_list_curncy, 1);

    
    for counter_curncy = 1:num_currencies

        if VecCol_with_curves(counter_curncy) == 0            
            continue
        end
        
        if sum(Str_vola.M3D_par_mkt_rates (26 : end, 1, counter_curncy))== 0
            
                Str_vola.M3D_par_mkt_rates (26 : end, 1, counter_curncy) = ...
                    Str_vola.M3D_par_mkt_rates (26 : end, 1, 1);
                
                Str_vola.M3D_fwd_vola (26:end, 1, counter_curncy) = ...
                    Str_vola.M3D_fwd_vola (26:end, 1, 1);
                Str_vola.M3D_fwd_rates (26:end, 1, counter_curncy)= ...
                    Str_vola.M3D_fwd_rates (26:end, 1, 1);
                
        end
        
        
        
        name_sheet = strcat(RFR_Str_lists.C2D_list_curncy { counter_curncy, col_ISO3166 }, '_spot');     

        %   ===================================================================        
        
        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = cell(100,100); 
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 11, 7, size(aux,1), size(aux,2));

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = m2xdate (Str_vola.M3D_par_mkt_rates (26 : end, 1, counter_curncy));
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = VecRow_terms;
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 10, 3, size(aux,1), size(aux,2));

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = Str_vola.M3D_par_mkt_rates (26 : end , 2:end, counter_curncy) / 100;
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 11, 3, size(aux,1), size(aux,2));


        %   ===================================================================

        name_sheet = strcat(RFR_Str_lists.C2D_list_curncy { counter_curncy, col_ISO3166 }, '_vola');     

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = cell(100,100); 
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 11, 7, size(aux,1), size(aux,2));

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = m2xdate(Str_vola.M3D_fwd_vola (26:end, 1, counter_curncy));
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = VecRow_terms;
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 10, 3, size(aux,1), size(aux,2));

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = Str_vola.M3D_fwd_vola (26:end, 2:end, counter_curncy);
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 11, 3, size(aux,1), size(aux,2));


        %   ===================================================================


        name_sheet = strcat(RFR_Str_lists.C2D_list_curncy { counter_curncy, col_ISO3166 }, '_fwd');     

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = cell(100,100); 
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 11, 7, size(aux,1), size(aux,2));

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = m2xdate(Str_vola.M3D_fwd_rates (26:end, 1, counter_curncy));
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = VecRow_terms;
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 10, 3, size(aux,1), size(aux,2));

        counter_writings = counter_writings + 1;
        sheet_id { counter_writings } = name_sheet;
        aux = Str_vola.M3D_fwd_rates (26:end, 2:end, counter_curncy);
        data_id  { counter_writings } = aux;
        range_id { counter_writings } = calcexcelrange( 11, 3, size(aux,1), size(aux,2));

        
    end
    
        %   ===================================================================


    name_sheet = 'Charts_data';     

    counter_writings = counter_writings + 1;
    sheet_id { counter_writings } = name_sheet;
    aux = cell(40,1); 
    data_id  { counter_writings } = aux;
    range_id { counter_writings } = calcexcelrange( 11, 7, size(aux,1), size(aux,2));

    counter_writings = counter_writings + 1;
    sheet_id { counter_writings } = name_sheet;
    positions = (VecCol_with_curves == 1);
    aux = RFR_Str_lists.C2D_list_curncy (positions, col_ISO3166);
    data_id  { counter_writings } = aux;
    range_id { counter_writings } = calcexcelrange( 11, 7, size(aux,1), size(aux,2));
         
    xlswrite_mult (file_storage , data_id  , sheet_id  , range_id  );

end

