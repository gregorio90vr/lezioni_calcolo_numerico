function    RFR_14_for_publication_excel_SW_Qb(config, ER_no_VA, ...
    ER_with_VA, date_calc)
              

%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------

    %   This function writes in excel file 'RFR_for_publication_Qb_SW.xlsx'
    %   the relevant outputs for the Smith Wilson extrapolation
    
%  ------------------------------------------------------------------------

%  ========================================================================
%%  1. Loading variables common to the following steps within this function
%  ========================================================================
    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
        
    num_curves = size(config.RFR_Str_lists.C2D_list_curncy, 1);

    
%  ========================================================================
%%  1. Writing excel file referred to central government bonds VA Currency
%  ========================================================================

    
    file_output = fullfile(config.RFR_Str_config.folders.path_RFR_08_Results, ...
                          'RFR_for_publication_Qb_SW.xlsx');     

    %   We need to write as many times as there are curves
    %   Multiplication by 2 to have curves with and without VA
    %   The 5 remaining writing actions are for additional information
    %  (like date of publication)
    num_writings = 5 + num_curves * 2; 
    
    sheet_output = cell(num_writings, 1);
    data_output  = cell(num_writings, 1);
    range_output = cell(num_writings, 1);
    
    counter = 0;

    
    %  Labels for each country in row 10
    %  -------------------------------------------------------------------- 
                
    C1C_Currency_Markets_id = config.RFR_Str_lists.C2D_list_curncy(:, col_ISO3166);
    
    for count_country = 1 : 1 : length(C1C_Currency_Markets_id)
             
        code_curncy = C1C_Currency_Markets_id{count_country} ; 
        
        if ~strcmp(code_curncy, 'EUR')
            
            if strcmp(code_curncy, 'GBP')
                C1C_Currency_Markets_id{count_country} = 'UK';                
            else
                C1C_Currency_Markets_id{count_country} = code_curncy(1:2);
            end
            
        else
            C1C_Currency_Markets_id{count_country} = code_curncy;  
        end
       
    end    
        
    
    %   -------------------------------------------------------------------
    %%  1.1.  Worksheet  'SW_Qb_no_VA'
    %   -------------------------------------------------------------------
    %   With structure ER_no_VA.C1C_parameters_SW
    
    name_sheet = 'SW_Qb_no_VA';
    
            
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(300, 300);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 2, size(aux,1), size(aux,2));

    colum_ini = 0;
    
    for k = 1:num_curves  
               
        counter = counter + 1;
        sheet_output{counter} = name_sheet;
        
        if ~isempty(cell2mat(ER_no_VA.V1C_time_parameters_SW(k)))
            aux = cell2mat(ER_no_VA.V1C_time_parameters_SW(k))';
        else
            aux ={'N/A'};
        end
        
        data_output{counter} = aux;
        range_output{counter} = calcexcelrange(11, colum_ini + 3*k, size(aux,1), size(aux,2));
              
        counter = counter + 1;
        sheet_output{counter} = name_sheet;
        aux = C1C_Currency_Markets_id(k);
        data_output{counter} = aux;
        range_output{counter} = calcexcelrange(10, colum_ini + 3*k + 1, size(aux,1), size(aux,2));
      
        counter = counter + 1;
        sheet_output{counter} = name_sheet;
        
        if ~isempty(cell2mat(ER_no_VA.C1C_parameters_SW(k)))
            aux = cell2mat(ER_no_VA.C1C_parameters_SW(k));
        else
            aux ={'N/A'};
        end
        
        data_output{counter} = aux;
        range_output{counter} = calcexcelrange(11, colum_ini + 3*k + 1, size(aux,1), size(aux,2));

    end

    
     
    %   -------------------------------------------------------------------
    %%  1.2.  Worksheet  'SW_Qb_with_VA'
    %   -------------------------------------------------------------------
    %   With structure ER_with_VA.C1C_parameters_SW
    
    name_sheet = 'SW_Qb_with_VA';
    
            
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(300, 300);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 2, size(aux,1), size(aux,2));

    colum_ini = 0;
    
    for k = 1:num_curves  
               
        counter = counter + 1;
        sheet_output{counter} = name_sheet;
        
        if ~isempty(cell2mat(ER_with_VA.V1C_time_parameters_SW(k)))
            aux = cell2mat(ER_with_VA.V1C_time_parameters_SW(k))';
        else
            aux ={'N/A'};
        end
        
        data_output{counter} = aux;
        range_output{counter} = calcexcelrange(11, colum_ini + 3*k, size(aux,1), size(aux,2));
              
        counter = counter + 1;
        sheet_output{counter} = name_sheet;
        aux = C1C_Currency_Markets_id(k);
        data_output{counter} = aux;
        range_output{counter} = calcexcelrange(10, colum_ini + 3*k + 1, size(aux,1), size(aux,2));      

        counter = counter + 1;
        sheet_output{counter} = name_sheet;
        
        if ~isempty(cell2mat(ER_with_VA.C1C_parameters_SW(k)))
            aux = cell2mat(ER_with_VA.C1C_parameters_SW(k));
        else
            aux ={'N/A'};
        end  
        
        data_output{counter} = aux;
        range_output{counter} = calcexcelrange(11, colum_ini + 3*k + 1, size(aux,1), size(aux,2));

    end

    
    % last writing of the date of calculation in the main worksheet
    
    name_sheet = 'SW_Qb_no_VA';     

    counter = counter + 1;
    sheet_output{counter}    = name_sheet;
    aux ={datestr(date_calc, 'dd-mm-yyyy')};
    data_output{counter}    = aux;
    range_output{counter}    = calcexcelrange(4, 15, size(aux,1), size(aux,2));
     
    
    % last writing of the date of calculation in the main worksheet
    
    name_sheet = 'SW_Qb_with_VA';     

    counter = counter + 1;
    sheet_output{counter}    = name_sheet;
    aux ={datestr(date_calc, 'dd-mm-yyyy')};
    data_output{counter}    = aux;
    range_output{counter}    = calcexcelrange(4, 15, size(aux,1), size(aux,2));
    
    
    text_waitbar = 'Writing parameters Smith Wilson --> RFR_for_publication_Qb_SW.xlsx';
    
    xlswrite_mult_msg(file_output, data_output, sheet_output, ...
        range_output, text_waitbar);

end

