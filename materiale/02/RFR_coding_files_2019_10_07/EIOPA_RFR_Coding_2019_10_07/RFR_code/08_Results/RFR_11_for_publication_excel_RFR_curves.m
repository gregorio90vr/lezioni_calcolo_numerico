function RFR_11_for_publication_excel_RFR_curves ...
           (config, date_calc, Str_assumptions, ...
               ER_no_VA, ER_with_VA, Str_VA_Currency)
              

%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------
%
%   This function copy paste the data from Matlab to Excel file 
%   " RFR_for_publication_RFR_curves.xlsx "
%   For all sheets of the function, information about Coupon_freq, LLP
%   Convergence, UFR, alpha, CRA, VA are pasted 

%  ------------------------------------------------------------------------
%  ------------------------------------------------------------------------



%  ------------------------------------------------------------------------
%%  1. Loading variables common to the following steps within this function
%  ------------------------------------------------------------------------
  

    % 1.A. Creating variables containing relevant folders and files for...  
    % --------------------------------------------------------------------- 
    col_name_country = config.RFR_Str_lists.Str_numcol_curncy.name_country;
    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166     ;
    col_SWP_GVT = config.RFR_Str_lists.Str_numcol_curncy.SWP_GVT     ;
    col_LLP_GVT = config.RFR_Str_lists.Str_numcol_curncy.LLP_GVT     ;
    col_LLP_SWP = config.RFR_Str_lists.Str_numcol_curncy.LLP_SWP     ;
    col_VA_used = config.RFR_Str_lists.Str_numcol_curncy.VA_calculation;
    
%   col_convergence  = config.RFR_Str_lists.Str_numcol_curncy.convergence ;
%   col_UFR          = config.RFR_Str_lists.Str_numcol_curncy.UFR         ;

        %   number of the column in cell array
        %   'config.RFR_Str_lists.config.RFR_Str_lists.C2D_list_curncy'  containing 
        %   for each of the currencies / countries considered 
        %   the information identified in the name of each variable
    

    %   Names of the folder and the file where
    %   the final curves will be stored     -------------------------------
    
    folder_final_curves = config.RFR_Str_config.folders.path_RFR_08_Results;
    
        %   path where final interest rates curves will be stored
        
    file_storage = fullfile(folder_final_curves, ...
        'RFR_for_publication_RFR_curves.xlsx');
    
    
    
    M2D_assumptions = [ Str_assumptions.VecCol_coupon_freq, ... 
                        Str_assumptions.VecCol_LLP, ...
                        Str_assumptions.VecCol_convergence, ...
                        Str_assumptions.VecCol_UFR  ];
    
    num_countries = size(config.RFR_Str_lists.C2D_list_curncy, 1);    
    With_Outputs =(1 : num_countries);
    
%  ------------------------------------------------------------------------
%%  2. Loop for each currency in order to prepare currency specific inputs
%  ------------------------------------------------------------------------ 
        
     
    
        %   first row of this cell array contains the headings identifiers
        %   of the content of each column
        
    CellCol_names_curves    = cell(num_countries, 1);     

    CellCol_id_countries    = cell(num_countries, 1);
    
    
    
    for count_country = 1:num_countries
        
        
        % 2.A.  Filling in variables whose content is currency specific
        %       but it does not depends on whether the curve to use 
        %       is either 'swap' or 'govt'
        % ----------------------------------------------------------------- 
        
        finan_asset = config.RFR_Str_lists.C2D_list_curncy(count_country, col_SWP_GVT);
        finan_asset = finan_asset{1};    %  from cell array to character
        
        code_curncy = config.RFR_Str_lists.C2D_list_curncy{ count_country, col_ISO3166 } ; 
        
        if ~strcmp(code_curncy, 'EUR')
            CellCol_id_countries{count_country} = code_curncy(1:2);
        else
            CellCol_id_countries{count_country} = code_curncy;  
        end
                         
        
        
        %   2.B. Name of each curve
        %       (including their respective parameters)             
        %   ----------------------------------------------------------            

        if strcmp(config.RFR_Str_lists.C2D_list_curncy{count_country,col_SWP_GVT}, 'SWP')
            LLP_string = num2str(config.RFR_Str_lists.C2D_list_curncy{count_country,col_LLP_SWP});
        else
            LLP_string = num2str(config.RFR_Str_lists.C2D_list_curncy{count_country,col_LLP_GVT});
        end
        
        % 19/03/2015: modification of the instruction below. See folder
        % Log_changes
        CellCol_names_curves(count_country) = ...
           { strcat(CellCol_id_countries{ count_country }, '_', ...
                       num2str(day (date_calc)), '_', ...
                       num2str(month(date_calc)), '_', ...
                       num2str(year(date_calc)), '_', ...
                       finan_asset, ...
                       '_LLP_',  num2str(Str_assumptions.VecCol_LLP(count_country)),...
                       '_EXT_',  num2str(Str_assumptions.VecCol_convergence(count_country)),...
                       '_UFR_',  num2str(Str_assumptions.VecCol_UFR(count_country))) };

            %   right part of the instruction should be between{ }
            %   because it will work as a cell array

             
    end
    
       
%  ------------------------------------------------------------------------
%%  A. Writing MARKET rates in excel file 'RFR_Final_curves'
%  ------------------------------------------------------------------------        
%   From the structure ER_no_VA.M2D_SW_spot_rates


    name_sheet = 'RFR_spot_no_VA';     

    num_writings = 2;  %   just initizialtize the cell arrays below
                        %   in this way their size will increase  IN ROWS
                        %   according the outputs to write, 
                        %   without being exposed to a failure 
                        %  (e.g. empty rows of the arrays)
                        %   Warning.- num_writings=1 will lead to increase 
                        %   cell arrays in columns and the there will be
                        %   only one writing

    
    sheet_market = cell(num_writings, 1);
    data_market  = cell(num_writings, 1);
    range_market = cell(num_writings, 1);
    
    counter = 0;
   
        
    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = cell(200,100);
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange(2, 3, size(aux,1), size(aux,2));
        
    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(With_Outputs, col_name_country)';
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange(2, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = CellCol_names_curves(With_Outputs)';
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange(3, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = [{ 'Coupon_freq' };{ 'LLP' }       ;{ 'Convergence' }; ...
          { 'UFR' }        ;{ 'alpha' } ;{ 'CRA' };{ 'VA' } ];        
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange(4, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = M2D_assumptions(With_Outputs, :)';
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange(4, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = ER_no_VA.VecCol_alpha_fit(With_Outputs)';
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange(8, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = 100 * ER_no_VA.VecRow_CRA(With_Outputs);
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange(9, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = repmat({''},1,num_countries);
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));
          
    counter = counter + 1;
    sheet_market{counter}    = name_sheet;
    aux = ER_no_VA.VecRow_maturities(1:60)';
    data_market{counter}    = aux;
    range_market{counter}    = calcexcelrange(11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_market{counter} = name_sheet;
    aux = ER_no_VA.M2D_SW_spot_rates(With_Outputs, :)';
    aux = round(aux * 100000) / 100000;
    data_market{counter} = aux;
    range_market{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2)); 

    
    
    text_waitbar ='Writing basic RFR curves without VA --> RFR_for_publication_RFR_curves.xlsx';
    
    xlswrite_mult_msg(file_storage, data_market, sheet_market, range_market, text_waitbar);
    
   

%  ------------------------------------------------------------------------
%%  B Writing Rates_net_CRA´in excel file 'RFR_Final_curves'
%  ------------------------------------------------------------------------        
%   From the structure ER_with_VA.M2D_SW_spot_rates


    name_sheet = 'RFR_spot_with_VA';     

    num_writings = 2;  %   just initizialtize the cell arrays below
                        %   in this way their size will increase  IN ROWS
                        %   according the outputs to write, 
                        %   without being exposed to a failure 
                        %  (e.g. empty rows of the arrays)
                        %   Warning.- num_writings=1 will lead to increase 
                        %   cell arrays in columns and the there will be
                        %   only one writing

                        
    sheet_RFR_with_VA  = cell(num_writings, 1);
    data_RFR_with_VA   = cell(num_writings, 1);
    range_RFR_with_VA  = cell(num_writings, 1);
    
    counter = 0;
   
        
    counter = counter + 1;
    sheet_RFR_with_VA{counter} = name_sheet;
    aux = cell(200,100);
    data_RFR_with_VA{counter} = aux;
    range_RFR_with_VA{counter} = calcexcelrange(2, 3, size(aux,1), size(aux,2));
        
    counter = counter + 1;
    sheet_RFR_with_VA{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(With_Outputs, col_name_country)';

    data_RFR_with_VA{counter} = aux;
    range_RFR_with_VA{counter} = calcexcelrange(2, 3, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_RFR_with_VA{counter} = name_sheet;
    aux = CellCol_names_curves(With_Outputs)';
    data_RFR_with_VA{counter} = aux;
    range_RFR_with_VA{counter} = calcexcelrange(3, 3, size(aux,1), size(aux,2));
   
    counter = counter + 1;
    sheet_RFR_with_VA{counter} = name_sheet;
    aux = [{ 'Coupon_freq' };{ 'LLP' }       ;{ 'Convergence' }; ...
          { 'UFR' }        ;{ 'alpha' } ;{ 'CRA' };{ 'VA' } ];        

    data_RFR_with_VA{counter} = aux;
    range_RFR_with_VA{counter} = calcexcelrange(4, 2, size(aux,1), size(aux,2));
  
    counter = counter + 1;
    sheet_RFR_with_VA{counter} = name_sheet;
    aux = M2D_assumptions(With_Outputs, :)';
    data_RFR_with_VA{counter} = aux;
    range_RFR_with_VA{counter} = calcexcelrange(4, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_RFR_with_VA{counter} = name_sheet;
    aux = ER_with_VA.VecCol_alpha_fit(With_Outputs)';
    data_RFR_with_VA{counter} = aux;
    range_RFR_with_VA{counter} = calcexcelrange(8, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_RFR_with_VA{counter} = name_sheet;
    aux = 100 * ER_with_VA.VecRow_CRA(With_Outputs);
    data_RFR_with_VA{counter} = aux;
    range_RFR_with_VA{counter} = calcexcelrange(9, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_RFR_with_VA{counter} = name_sheet;
    aux = 100 * ER_with_VA.VecRow_VA_total(With_Outputs);
    
    % Identifying the currencies for which no VA is calculated
    vaCalculated = logical(cell2mat(config.RFR_Str_lists.C2D_list_curncy(:,col_VA_used)));
    aux = num2cell(aux, 1);
    aux(~vaCalculated) ={'n/a'};
    
    %   Continue normal function
    data_RFR_with_VA{counter} = aux;
    range_RFR_with_VA{counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));
                
    counter = counter + 1;
    sheet_RFR_with_VA{counter}    = name_sheet;
    aux = ER_with_VA.VecRow_maturities';
    data_RFR_with_VA{counter}    = aux;
    range_RFR_with_VA{counter}    = calcexcelrange(11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_RFR_with_VA{counter} = name_sheet;
    aux = ER_with_VA.M2D_SW_spot_rates(With_Outputs, :)';
    aux = round(aux * 100000) / 100000;
    data_RFR_with_VA{counter} = aux;
    range_RFR_with_VA{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2)); 

    
    
    % last writing of the date of calculation in the main worksheet
    
    name_sheet = 'Main_Menu';     

    counter = counter + 1;
    sheet_RFR_with_VA{counter}    = name_sheet;
    aux ={ datestr(date_calc, 'dd-mm-yyyy') };
    data_RFR_with_VA{counter}    = aux;
    range_RFR_with_VA{counter}    = calcexcelrange(1, 1, size(aux,1), size(aux,2));
     
    
    
    text_waitbar ='Writing RFR curves WITH VA --> RFR_for_publication_RFR_curves.xlsx';
    
    xlswrite_mult_msg(file_storage, data_RFR_with_VA, sheet_RFR_with_VA,...
        range_RFR_with_VA, text_waitbar);
    
    
