function RFR_15_internal_file_PD_CoD_govts ...
               (config, date_calc, Str_assumptions, ER_no_VA, ...
               Str_VA_Currency, Str_LTAS)
              

%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------

    %   This function writes AN INTERNAL excel file 
    
%  ------------------------------------------------------------------------
%  ------------------------------------------------------------------------



%  ------------------------------------------------------------------------
%%  1. Loading variables common to the following steps within this function
%  ------------------------------------------------------------------------
  

    % 1.A. Creating variables containing relevant folders and files for...  
    % --------------------------------------------------------------------- 

    col_name_country = config.RFR_Str_lists.Str_numcol_curncy.name_country;
    col_ISO3166      = config.RFR_Str_lists.Str_numcol_curncy.ISO3166     ;
    col_SWP_GVT      = config.RFR_Str_lists.Str_numcol_curncy.SWP_GVT     ;
    col_LLP_GVT      = config.RFR_Str_lists.Str_numcol_curncy.LLP_GVT     ;
    col_LLP_SWP      = config.RFR_Str_lists.Str_numcol_curncy.LLP_SWP     ;
    col_convergence  = config.RFR_Str_lists.Str_numcol_curncy.convergence ;
    col_UFR          = config.RFR_Str_lists.Str_numcol_curncy.UFR         ;

        %   number of the column in cell array
        %   'config.RFR_Str_lists.config.RFR_Str_lists.C2D_list_curncy'  containing 
        %   for each of the currencies / countries considered 
        %   the information identified in the name of each variable
    

    %   Names of the folder and the file where
    %   the final curves will be stored     -------------------------------
    
    folder_final_curves = config.RFR_Str_config.folders.path_RFR_08_Results;
    
        %   path where final interest rates curves will be stored
        
    file_output = fullfile(folder_final_curves, 'RFR_internal_PD_CoD_Govts.xlsx');
    
    
    
    M2D_assumptions = [ Str_assumptions.VecCol_coupon_freq, ... 
                        Str_assumptions.VecCol_LLP, ...
                        Str_assumptions.VecCol_convergence, ...
                        Str_assumptions.VecCol_UFR  ];
    
    With_Outputs = find(ER_no_VA.VecCol_alpha_fit ~= 0);
    
%  ------------------------------------------------------------------------
%%  2. Loop for each currency in order to prepare currency specific inputs
%  ------------------------------------------------------------------------ 
        
    num_currencies = size(config.RFR_Str_lists.C2D_list_curncy, 1);
    
        %   first row of this cell array contains the headings identifiers
        %   of the content of each column
        
    CellCol_names_curves = cell(num_currencies, 1);     

    
    for count_curncy = 1:num_currencies
        
        
        % 2.B.  Filling in variables whose content is currency specific
        %       but it does not depends on whether the curve to use 
        %       is either 'swap' or 'govt'
        % ----------------------------------------------------------------- 
        
        finan_asset = config.RFR_Str_lists.C2D_list_curncy(count_curncy, col_SWP_GVT);
        finan_asset = finan_asset{1};    %  from cell array to character
        
        code_curncy = config.RFR_Str_lists.C2D_list_curncy { count_curncy, col_ISO3166 } ;     
                    
        
        %   2.C. Name of each curve
        %       (including their respective parameters)             
        %   ----------------------------------------------------------            

        if strcmp(config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_SWP_GVT}, 'SWP')
            LLP_string = num2str(config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_LLP_SWP});
        else
            LLP_string = num2str(config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_LLP_GVT});
        end
        
        CellCol_names_curves(count_curncy) = ...
            {  strcat(code_curncy, '_', ...
                       num2str(day (date_calc)), '_', ...
                       num2str(month(date_calc)), '_', ...
                       num2str(year(date_calc)), '_', ...
                       finan_asset, ...
                       '_LLP_',  LLP_string,...
                       '_EXT_',  num2str(config.RFR_Str_lists.C2D_list_curncy { count_curncy, col_convergence }),...
                       '_UFR_',  num2str(config.RFR_Str_lists.C2D_list_curncy { count_curncy, col_UFR }))  };

            %   rigth part of the instruction should be between { }
            %   because it will work as a cell array

    end
    
       
%  ------------------------------------------------------------------------
%%  A. Writing MARKET rates in excel file 'RFR_Final_curves'
%  ------------------------------------------------------------------------        

    name_sheet = 'RFR_spot_no_VA';     

    num_writings = 9; 
    
    sheet_output = cell(num_writings, 1);
    data_output  = cell(num_writings, 1);
    range_output = cell(num_writings, 1);
    
    counter = 0;
   
        
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(200,100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
        
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(With_Outputs, col_name_country)';
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = CellCol_names_curves(With_Outputs)';
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange( 3, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = [ { 'Coupon_freq' }; { 'LLP' }       ; { 'Convergence' }; ...
            { 'UFR' }        ; { 'alpha_fit' } ; { 'CRA' }; { 'VA' } ];        
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange( 4, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = M2D_assumptions(With_Outputs, :)';
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange( 4, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = ER_no_VA.VecCol_alpha_fit(With_Outputs)';
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange( 8, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = [ 100 * ER_no_VA.VecRow_CRA(With_Outputs); 100 * ER_no_VA.VecRow_VA_total(With_Outputs) ];
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange( 9, 3, size(aux,1), size(aux,2));
          
    counter = counter + 1;
    sheet_output {counter}    = name_sheet;
    aux = ER_no_VA.VecRow_maturities(1:60)';
    data_output  {counter}    = aux;
    range_output {counter}    = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = ER_no_VA.M2D_SW_spot_rates(With_Outputs, :)';
    aux = round(aux * 100000) / 100000;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2)); 

        
   
    
    %   -------------------------------------------------------------------
    %%  1.1. Worksheet  'LTAS_Govts'
    %   -------------------------------------------------------------------
    
    name_sheet = 'FS_Govts';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));
                        
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.C1C_countries;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));
               
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(:, 1 : 30);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));

 
 
    text_waitbar = 'Writing info FS and PD for Government Bonds --> RFR_for_publication_PD_COD_Govts.xlsx';
    
    xlswrite_mult_msg(file_output, data_output, sheet_output, range_output,...
        text_waitbar);


end

