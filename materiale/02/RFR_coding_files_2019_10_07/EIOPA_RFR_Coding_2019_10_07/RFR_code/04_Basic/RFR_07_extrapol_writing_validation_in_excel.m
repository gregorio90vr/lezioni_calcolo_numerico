function RFR_07_extrapol_writing_validation_in_excel ...
               (config, date_calc, Str_assumptions, ...
                  ER, M2D_raw_curves)
              


%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------
%
%   This function writes the outputs of the extrapolation
%   in the internal excel file  'RFR_validation_file.xlsx'

%   Therefore the function only moves data(inputs, outputs,...)
%   from MatLab to Excel

%   Function 'xls_write_mult_msg.m'  is a home made function
%   It needs the ancillary functions in 01_Config

%   IMPORTANT: Excel file  'RFR_validation_file.xlsx' should be closed.

%  ------------------------------------------------------------------------
%  ------------------------------------------------------------------------



%  ------------------------------------------------------------------------
%%  1. Loading variables common to the following steps within this function
%  ------------------------------------------------------------------------
  

    % 1.A. Creating variables containing relevant folders and files for...  
    % --------------------------------------------------------------------- 
      
    col_name_country = config.RFR_Str_lists.Str_numcol_curncy.name_country;
    col_ISO3166      = config.RFR_Str_lists.Str_numcol_curncy.ISO3166     ;
  % col_Euro         = config.RFR_Str_lists.Str_numcol_curncy.Euro        ;    
  % col_ISO4217      = config.RFR_Str_lists.Str_numcol_curncy.ISO4217     ;
  % col_EEA          = config.RFR_Str_lists.Str_numcol_curncy.EEA         ;
  % col_gvt_coupon   = config.RFR_Str_lists.Str_numcol_curncy.gvt_coupon  ;    
  % col_swp_coupon   = config.RFR_Str_lists.Str_numcol_curncy.swp_coupon  ;
    col_SWP_GVT      = config.RFR_Str_lists.Str_numcol_curncy.SWP_GVT     ;
    col_LLP_GVT      = config.RFR_Str_lists.Str_numcol_curncy.LLP_GVT     ;
    col_LLP_SWP      = config.RFR_Str_lists.Str_numcol_curncy.LLP_SWP     ;
    col_convergence  = config.RFR_Str_lists.Str_numcol_curncy.convergence ;
    col_UFR          = config.RFR_Str_lists.Str_numcol_curncy.UFR         ;

        %   number of the column in cell array
        %   'config.RFR_Str_lists.C2D_list_curncy'  containing 
        %   for each of the currencies / countries considered 
        %   the information identified in the name of each variable
    
    %   Names of the folder and the file where
    %   the final curves will be stored     -------------------------------
    
    folder_final_curves = config.RFR_Str_config.folders.path_RFR_08_Results;
    
    %   path where final interest rates curves will be stored
        
    file_storage = fullfile(folder_final_curves, 'RFR_validation_file.xlsx');

    M2D_assumptions = [ Str_assumptions.VecCol_coupon_freq, ... 
                        Str_assumptions.VecCol_LLP, ...
                        Str_assumptions.VecCol_convergence, ...
                        Str_assumptions.VecCol_UFR  ];
    
    With_Outputs = find(ER.VecCol_alpha_fit ~= 0);
    
%  ------------------------------------------------------------------------
%%  2. Loop for each currency in order to prepare currency specific inputs
%  ------------------------------------------------------------------------ 
        
    num_currencies = size(config.RFR_Str_lists.C2D_list_curncy, 1);
    
        %   first row of this cell array contains the headings identifiers
        %   of the content of each column
        
    CellCol_names_curves = cell(num_currencies, 1);
        
    % Storing DLT points for the SW validation
    M2D_DLT = zeros(53, 150);   
    
    for count_curncy = 1 : num_currencies
        
        
        % 2.B.  Filling in variables whose content is currency specific
        %       but it does not depends on whether the curve to use 
        %       is either 'swap' or 'govt'
        % ----------------------------------------------------------------- 

            
        finan_asset = config.RFR_Str_lists.C2D_list_curncy(count_curncy, col_SWP_GVT);
        finan_asset = finan_asset{1};    %  from cell array to character
        
        code_curncy = config.RFR_Str_lists.C2D_list_curncy{count_curncy, col_ISO3166} ;     
                    

        
        %   2.C. Name of each curve
        %       (including their respective parameters)             
        %   ----------------------------------------------------------            
        if strcmp(config.RFR_Str_lists.C2D_list_curncy{count_curncy, col_SWP_GVT}, 'SWP')
            LLP_string = num2str(config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_LLP_SWP});
            Curncy_DLT = cell2mat(config.RFR_basic_ADLT_SWP(count_curncy,11:70));
            M2D_DLT(count_curncy,1:60) = Curncy_DLT;
        else
            LLP_string = num2str(config.RFR_Str_lists.C2D_list_curncy{count_curncy,col_LLP_GVT});
            Curncy_DLT = cell2mat(config.RFR_basic_ADLT_GVT(count_curncy,11:70));
            M2D_DLT(count_curncy,1:60) = Curncy_DLT;       
        end
        
       % 19/03/2015: modification of the instruction below. See folder
        % Log_changes
        CellCol_names_curves(count_curncy) = ...
           {strcat(code_curncy, '_', ...
                       num2str(day (date_calc)) , '_', ...
                       num2str(month(date_calc)) , '_', ...
                       num2str(year(date_calc)) , '_', ...
                       finan_asset, ...
                       '_LLP_' ,  num2str(Str_assumptions.VecCol_LLP(count_curncy)),...
                       '_EXT_' ,  num2str(Str_assumptions.VecCol_convergence(count_curncy)),...
                       '_UFR_' ,  num2str(Str_assumptions.VecCol_UFR(count_curncy)))};

            %   right part of the instruction should be between{}
            %   because it will work as a cell array

    end
    
       
%  ------------------------------------------------------------------------
%%  A. Writing MARKET rates in excel file 'RFR_validation_file.xlsx'
%  ------------------------------------------------------------------------        

    name_sheet = 'Market_data';     

    num_writings = 9; 
    
    sheet_market = cell(num_writings, 1);
    data_market  = cell(num_writings, 1);
    range_market = cell(num_writings, 1);
    
    counter = 0;
   
        
    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = cell(200,100);
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
        
    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(With_Outputs, col_name_country)';
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = CellCol_names_curves(With_Outputs)';
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange( 3, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = [{'Coupon_freq'};{'LLP'}       ;{'Convergence'}; ...
          {'UFR'}        ;{'alpha_fit'} ;{'CRA'};{'VA'} ];        
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange( 4, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = M2D_assumptions(With_Outputs, :)';
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange( 4, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = ER.VecCol_alpha_fit(With_Outputs)';
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange( 8, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = [ 100*ER.VecRow_CRA(With_Outputs); ER.VecRow_VA_total(With_Outputs) ];        
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange( 9, 3, size(aux,1), size(aux,2));
          
    counter = counter + 1;
    sheet_market{counter}    = name_sheet;
    aux = ER.VecRow_maturities(1:60)';
    data_market{counter}    = aux;
    range_market{counter}    = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = M2D_raw_curves(With_Outputs, :)' / 100;
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2)); 

    
    text_waitbar = 'Writing market info  --> RFR_validation_file.xlsx';
    
    xlswrite_mult_msg(file_storage, data_market, sheet_market,...
        range_market, text_waitbar);

 

%  ------------------------------------------------------------------------
%%  B Writing Rates_net_CRA´in excel file 'RFR_validation_file.xlsx'
%  ------------------------------------------------------------------------        

    name_sheet = 'Rates_net_CRA';     

    num_writings = 9; 
    
    sheet_netCRA  = cell(num_writings, 1);
    data_netCRA  = cell(num_writings, 1);
    range_netCRA = cell(num_writings, 1);
    
    counter = 0;
   
        
    counter = counter + 1;
    sheet_netCRA{counter} = name_sheet;
    aux = cell(200,100);
    data_netCRA{counter} = aux;
    range_netCRA{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
        
    counter = counter + 1;
    sheet_netCRA{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(With_Outputs, col_name_country)';
    data_netCRA{counter} = aux;
    range_netCRA{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_netCRA{counter} = name_sheet;
    aux = CellCol_names_curves(With_Outputs)';
    data_netCRA{counter} = aux;
    range_netCRA{counter} = calcexcelrange( 3, 3, size(aux,1), size(aux,2));
   
    counter = counter + 1;
    sheet_netCRA{counter} = name_sheet;
    aux = [{'Coupon_freq'};{'LLP'}       ;{'Convergence'}; ...
          {'UFR'}        ;{'alpha_fit'} ;{'CRA'};{'VA'} ];        

    data_netCRA{counter} = aux;
    range_netCRA{counter} = calcexcelrange( 4, 2, size(aux,1), size(aux,2));
  
    counter = counter + 1;
    sheet_netCRA{counter} = name_sheet;
    aux = M2D_assumptions(With_Outputs, :)';
    data_netCRA{counter} = aux;
    range_netCRA{counter} = calcexcelrange( 4, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_netCRA{counter} = name_sheet;
    aux = ER.VecCol_alpha_fit(With_Outputs)';
    data_netCRA{counter} = aux;
    range_netCRA{counter} = calcexcelrange( 8, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_netCRA{counter} = name_sheet;
    aux = [ ER.VecRow_CRA(With_Outputs); ER.VecRow_VA_total(With_Outputs) ];        
    data_netCRA{counter} = aux;
    range_netCRA{counter} = calcexcelrange( 9, 3, size(aux,1), size(aux,2));
                
    counter = counter + 1;
    sheet_netCRA{counter}    = name_sheet;
    aux = ER.VecRow_maturities';
    data_netCRA{counter}    = aux;
    range_netCRA{counter}    = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_netCRA{counter} = name_sheet;
    aux = ER.M2D_raw_rates_net_CRA(With_Outputs, :)' / 100;
    data_netCRA{counter} = aux;
    range_netCRA{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2)); 

    
    text_waitbar ='Writing rates net CRA  --> RFR_validation_file.xlsx';
    
    xlswrite_mult_msg(file_storage, data_netCRA, sheet_netCRA, ...
        range_netCRA, text_waitbar);
    
    
%  ------------------------------------------------------------------------
%%  C. Writing SPOT rates in excel file 'RFR_validation_file'
%  ------------------------------------------------------------------------        

    name_sheet = 'Spot_rates';     

    num_writings = 9; 
    
    sheet_spot = cell(num_writings, 1);
    data_spot  = cell(num_writings, 1);
    range_spot = cell(num_writings, 1);
    
    counter = 0;
    
        
    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = cell(200,100);
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(With_Outputs, col_name_country)';
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = CellCol_names_curves(With_Outputs)';
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 3, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = [{'Coupon_freq'};{'LLP'}       ;{'Convergence'}; ...
          {'UFR'}        ;{'alpha_fit'} ;{'CRA'};{'VA'} ];        
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 4, 2, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = M2D_assumptions(With_Outputs, :)';
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 4, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = ER.VecCol_alpha_fit(With_Outputs)';
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 8, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = [ ER.VecRow_CRA(With_Outputs); ER.VecRow_VA_total(With_Outputs) ];        
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 9, 3, size(aux,1), size(aux,2));
          
    counter = counter + 1;
    sheet_spot{counter}    = name_sheet;
    aux = ER.VecRow_maturities';
    data_spot{counter}    = aux;
    range_spot{counter}    = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = ER.M2D_SW_spot_rates(With_Outputs, :)';
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2)); 

    
    text_waitbar = 'Writing spot rates --> RFR_validation_file.xlsx';

    xlswrite_mult_msg(file_storage, data_spot, sheet_spot, ...
        range_spot, text_waitbar);


    
%  ------------------------------------------------------------------------
%%  D. Writing FORWARD rates in excel file 'RFR_validation_file'
%  ------------------------------------------------------------------------        

    name_sheet = 'Forward_rates';     

    num_writings = 9; 
    
    sheet_forward = cell(num_writings, 1);
    data_forward  = cell(num_writings, 1);
    range_forward = cell(num_writings, 1);
    
    counter = 0;
   
        
    counter = counter + 1;
    sheet_forward{counter} = name_sheet;
    aux = cell(200,100);
    data_forward{counter} = aux;
    range_forward{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
        
    counter = counter + 1;
    sheet_forward{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(With_Outputs, col_name_country)';
    data_forward{counter} = aux;
    range_forward{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_forward{counter} = name_sheet;
    aux = CellCol_names_curves(With_Outputs)';
    data_forward{counter} = aux;
    range_forward{counter} = calcexcelrange( 3, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_forward{counter} = name_sheet;
    aux = [{'Coupon_freq'};{'LLP'}       ;{'Convergence'}; ...
          {'UFR'}        ;{'alpha_fit'} ;{'CRA'};{'VA'} ];        
    data_forward{counter} = aux;
    range_forward{counter} = calcexcelrange( 4, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_forward{counter} = name_sheet;
    aux = M2D_assumptions(With_Outputs, :)';
    data_forward{counter} = aux;
    range_forward{counter} = calcexcelrange( 4, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_forward{counter} = name_sheet;
    aux = ER.VecCol_alpha_fit(With_Outputs)';
    data_forward{counter} = aux;
    range_forward{counter} = calcexcelrange( 8, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_forward{counter} = name_sheet;
    aux = [ ER.VecRow_CRA(With_Outputs); ER.VecRow_VA_total(With_Outputs) ];        
    data_forward{counter} = aux;
    range_forward{counter} = calcexcelrange( 9, 3, size(aux,1), size(aux,2));
      
    counter = counter + 1;
    sheet_forward{counter}    = name_sheet;
    aux =(ER.VecRow_maturities-1)';
    data_forward{counter}    = aux;
    range_forward{counter}    = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_forward{counter} = name_sheet;
    aux = ER.M2D_SW_forward_rates(With_Outputs, :)';
    data_forward{counter} = aux;
    range_forward{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2)); 

    
    text_waitbar = 'Writing forward rates --> RFR_validation_file.xlsx';
    
    xlswrite_mult_msg(file_storage, data_forward, sheet_forward,...
        range_forward, text_waitbar);

    

%  ------------------------------------------------------------------------
%%  E. Writing PRICES in excel file 'RFR_validation_file'
%  ------------------------------------------------------------------------        

    name_sheet = 'Prices';     

    num_writings = 9; 
    
    sheet_prices  = cell(num_writings, 1);
    data_prices  = cell(num_writings, 1);
    range_prices = cell(num_writings, 1);
    
    counter = 0;
   
        
    counter = counter + 1;
    sheet_prices{counter} = name_sheet;
    aux = cell(200,100);
    data_prices{counter} = aux;
    range_prices{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
        
    counter = counter + 1;
    sheet_prices{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(With_Outputs, col_name_country)';
    data_prices{counter} = aux;
    range_prices{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_prices{counter} = name_sheet;
    aux = CellCol_names_curves(With_Outputs)';
    data_prices{counter} = aux;
    range_prices{counter} = calcexcelrange( 3, 3, size(aux,1), size(aux,2));
   
    counter = counter + 1;
    sheet_prices{counter} = name_sheet;
    aux = [{'Coupon_freq'};{'LLP'}       ;{'Convergence'}; ...
          {'UFR'}        ;{'alpha_fit'} ;{'CRA'};{'VA'} ];        
    data_prices{counter} = aux;
    range_prices{counter} = calcexcelrange( 4, 2, size(aux,1), size(aux,2));
  
    counter = counter + 1;
    sheet_prices{counter} = name_sheet;
    aux = M2D_assumptions(With_Outputs, :)';
    data_prices{counter} = aux;
    range_prices{counter} = calcexcelrange( 4, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_prices{counter} = name_sheet;
    aux = ER.VecCol_alpha_fit(With_Outputs)';
    data_prices{counter} = aux;
    range_prices{counter} = calcexcelrange( 8, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_prices{counter} = name_sheet;
    aux = [ ER.VecRow_CRA(With_Outputs); ER.VecRow_VA_total(With_Outputs) ];        
    data_prices{counter} = aux;
    range_prices{counter} = calcexcelrange( 9, 3, size(aux,1), size(aux,2));
                
    counter = counter + 1;
    sheet_prices{counter}    = name_sheet;
    aux = ER.VecRow_maturities';
    data_prices{counter}    = aux;
    range_prices{counter}    = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_prices{counter} = name_sheet;
    aux = ER.M2D_SW_prices(With_Outputs, :)';
    data_prices{counter} = aux;
    range_prices{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2)); 

    
    text_waitbar ='Writing prices --> RFR_validation_file.xlsx';
    
    xlswrite_mult_msg(file_storage, data_prices, sheet_prices, ...
        range_prices, text_waitbar);
 
%  ------------------------------------------------------------------------
%%  F Writing Rates_net_CRA´in excel file 'RFR_validation_file'
%  ------------------------------------------------------------------------        

    name_sheet = 'DLT';     

    num_writings = 9; 
    
    sheet_DLT  = cell(num_writings, 1);
    data_DLT  = cell(num_writings, 1);
    range_DLT = cell(num_writings, 1);
    
    counter = 0;
   
        
    counter = counter + 1;
    sheet_DLT{counter} = name_sheet;
    aux = cell(200,100);
    data_DLT{counter} = aux;
    range_DLT{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
        
    counter = counter + 1;
    sheet_DLT{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(With_Outputs, col_name_country)';
    data_DLT{counter} = aux;
    range_DLT{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_DLT{counter} = name_sheet;
    aux = CellCol_names_curves(With_Outputs)';
    data_DLT{counter} = aux;
    range_DLT{counter} = calcexcelrange( 3, 3, size(aux,1), size(aux,2));
   
    counter = counter + 1;
    sheet_DLT{counter} = name_sheet;
    aux = [{'Coupon_freq'};{'LLP'}       ;{'Convergence'}; ...
          {'UFR'}        ;{'alpha_fit'} ;{'CRA'};{'VA'} ];        

    data_DLT{counter} = aux;
    range_DLT{counter} = calcexcelrange( 4, 2, size(aux,1), size(aux,2));
  
    counter = counter + 1;
    sheet_DLT{counter} = name_sheet;
    aux = M2D_assumptions(With_Outputs, :)';
    data_DLT{counter} = aux;
    range_DLT{counter} = calcexcelrange( 4, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_DLT{counter} = name_sheet;
    aux = ER.VecCol_alpha_fit(With_Outputs)';
    data_DLT{counter} = aux;
    range_DLT{counter} = calcexcelrange( 8, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_DLT{counter} = name_sheet;
    aux = [ ER.VecRow_CRA(With_Outputs); ER.VecRow_VA_total(With_Outputs) ];        
    data_DLT{counter} = aux;
    range_DLT{counter} = calcexcelrange( 9, 3, size(aux,1), size(aux,2));
                
    counter = counter + 1;
    sheet_DLT{counter}    = name_sheet;
    aux = ER.VecRow_maturities';
    data_DLT{counter}    = aux;
    range_DLT{counter}    = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_DLT{counter} = name_sheet;
    
    
    aux = transpose(M2D_DLT(With_Outputs, :));
    data_DLT{counter} = aux;
    range_DLT{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2)); 

    
    text_waitbar ='Writing DLT maturities  --> RFR_validation_file.xlsx';
    
    xlswrite_mult_msg(file_storage, data_DLT, sheet_DLT, range_DLT, text_waitbar);
    
    %  ------------------------------------------------------------------------
    %%  G. Writing swap data in excel file 'RFR_validation_file'
    %  ------------------------------------------------------------------------        

    name_sheet = 'Swap_rates';     

    num_writings = 9; 

    sheet_spot = cell(num_writings, 1);
    data_spot  = cell(num_writings, 1);
    range_spot = cell(num_writings, 1);

    counter = 0;


    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = cell(200,100);
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(With_Outputs, col_name_country)';
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 2, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = CellCol_names_curves(With_Outputs)';
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 3, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = [{'Coupon_freq'};{'LLP'}       ;{'Convergence'}; ...
          {'UFR'}        ;{'alpha_fit'} ;{'CRA'};{'VA'} ];        
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 4, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = M2D_assumptions(With_Outputs, :)';
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 4, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = ER.VecCol_alpha_fit(With_Outputs)';
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 8, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = [ ER.VecRow_CRA(With_Outputs); ER.VecRow_VA_total(With_Outputs) ];        
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange( 9, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_spot{counter}    = name_sheet;
    aux = ER.VecRow_maturities';
    data_spot{counter}    = aux;
    range_spot{counter}    = calcexcelrange( 11, 2, size(aux,1), size(aux,2));

    % Write swap rates
    
    counter = counter + 1;
    sheet_spot{counter} = name_sheet;
    aux = ER.M2D_SW_swap_rates(With_Outputs,:)';
    data_spot{counter} = aux;
    range_spot{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2)); 


    text_waitbar = 'Writing swap rate vectors --> RFR_validation_file.xlsx';

    xlswrite_mult_msg(file_storage, data_spot, sheet_spot,...
        range_spot, text_waitbar);

