function RFR_12_for_publication_excel_VA ...
                   (config, Str_VA_Currency, Str_VA_National, date_calc) 
              

%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------

    %   This function writes in excel file 'RFR_VA_for_publication.xlsx'
    %   the relevant outputs for the currency VA and country VA
    
%  ------------------------------------------------------------------------
%  ------------------------------------------------------------------------



%  ========================================================================
%%  0. Loading variables common to the following steps within this function
%  ========================================================================

    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    col_VA_used = config.RFR_Str_lists.Str_numcol_curncy.VA_calculation;

%  ========================================================================
%%  1. Writing excel file referred to central government bonds VA Currency
%  ========================================================================

    
    file_output = fullfile(config.RFR_Str_config.folders.path_RFR_08_Results, ...
                          'RFR_for_publication_VA.xlsx');     

    num_writings = 2;  %   just initialize the cell arrays below
                        %   in this way their size will increase  IN ROWS
                        %   according the outputs to write, 
                        %   without being exposed to a failure 
                        %  (e.g. empty rows of the arrays)
                        %   Warning.- num_writings=1 will lead to increase 
                        %   cell arrays in columns and the there will be
                        %   only one writing

    
    sheet_output = cell(num_writings, 1);
    data_output  = cell(num_writings, 1);
    range_output = cell(num_writings, 1);
    
    counter = 0;


       
    
    %   -------------------------------------------------------------------
    %%  1.1. Worksheet  'VA_Currency_Weights'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_Currency.M2D_weights
    
    name_sheet = 'VA_Currency_Weights';

    
    
    
    %   logical vector identifying the rows to write in sheets
    %   with information referred to Currency Representative Portfolios
    %   ----------------------------------------------------------------        
   
    vaCalculated = logical(cell2mat(config.RFR_Str_lists.C2D_list_curncy(:,col_VA_used)));
    rows_to_write_Curncy = ...
               ~strcmp('EUR', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO4217)) & ...
               ~strcmp('LIC', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166)) & ...
               vaCalculated;
    
    rows_to_write_Curncy(1) = 1;  %  in order to write the Euro

    
    
    %   logical vector identifying the rows to write in sheets
    %   with information referred to National Representative Portfolios
    %   ----------------------------------------------------------------    
    
    rows_to_write_National =  vaCalculated;     
    rows_to_write_National(1) = 0;  %  in order to not write the Euro
    
    
    %   List of information to write
    %   -------------------------------------------------------------------

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(100, 100);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 1, size(aux,1), size(aux,2));
                
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy((rows_to_write_Curncy), col_ISO4217);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));
               
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_Currency.M2D_weights (rows_to_write_Curncy, :);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));


    
    
   
    %   -------------------------------------------------------------------
    %%  1.1. Worksheet  'VA_National_Weights'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_Currency.M2D_weights
    
    name_sheet = 'VA_National_Weights';
      
    
    %  Labels for each country in column B
    %  -------------------------------------------------------------------- 
                
    C1C_National_Markets_id = config.RFR_Str_lists.C2D_list_curncy(:, col_ISO3166);
    
    for count_country = 1 : 1 : length(C1C_National_Markets_id)
             
        code_curncy = C1C_National_Markets_id{ count_country } ; 
        
        if ~strcmp(code_curncy, 'EUR')
            
            if strcmp(code_curncy, 'GBP')
                C1C_National_Markets_id{ count_country } = 'UK';                
            else
                C1C_National_Markets_id{ count_country } = code_curncy(1:2);
            end
            
        else
            C1C_National_Markets_id{count_country} = code_curncy;  
        end
       
    end    
        
 
    
    %   List of information to write
    %   -------------------------------------------------------------------

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(100, 100);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 1, size(aux,1), size(aux,2));
                
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = C1C_National_Markets_id(rows_to_write_National);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));
               
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_National.M2D_weights(rows_to_write_National, :);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(rows_to_write_National, col_ISO4217);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 6, size(aux,1), size(aux,2));

    
    
    
    
    
    %   -------------------------------------------------------------------
    %%  2.1.  Worksheet  'VA_C_Govts_Comp'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_Currency.Govts.M2D_govts_portfolio
    
    name_sheet = 'VA_C_Govts_Comp';

   
    %  Labels for each issuer in row 10
    %  -------------------------------------------------------------------- 
              
    C1R_Currency_Govts_Issuers_id = Str_VA_Currency.Govts.C1R_govts_issuers;
    

    for count_country = 1:length(C1R_Currency_Govts_Issuers_id)
             
        code_curncy = C1R_Currency_Govts_Issuers_id{ count_country } ; 
        
        if ~strcmp(code_curncy, 'EUR')
            
            if strcmp(code_curncy, 'GBP')
                C1R_Currency_Govts_Issuers_id{ count_country } = 'UK';                
            else
                C1R_Currency_Govts_Issuers_id{ count_country } = code_curncy(1:2);
            end
            
        else
            C1R_Currency_Govts_Issuers_id{count_country} = code_curncy;  
        end
      
        
    end      
   
    
    %   List of information to write
    %   -------------------------------------------------------------------
    
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(100, 100);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 2, size(aux,1), size(aux,2));
               
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = C1R_Currency_Govts_Issuers_id ;
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_Currency.C1C_countries(rows_to_write_Curncy);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_Currency.Govts.M2D_govts_portfolio(rows_to_write_Curncy, :);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
 
    
    
    
    %   -------------------------------------------------------------------
    %%  2.2.  Worksheet  'VA_C_Govts_Dur'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_Currency.Govts.M2D_govts_durations
    
    name_sheet = 'VA_C_Govts_Dur';
    
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(100, 100);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 2, size(aux,1), size(aux,2));
               
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = C1R_Currency_Govts_Issuers_id;
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_Currency.C1C_countries(rows_to_write_Curncy);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_Currency.Govts.M2D_govts_durations(rows_to_write_Curncy, :);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    %   -------------------------------------------------------------------
    %%  2.3.  Worksheet  'VA_Currency_Govts_EUR_Duration'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_Currency.Govts.M2D_govts_durations
    
    name_sheet = 'VA_Currency_Govts_EUR_Duration';

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_Currency.ECB;
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(12, 3, size(aux,1), size(aux,2));

    %   -------------------------------------------------------------------
    %%  3.1.  Worksheet  'VA_N_Govts_Comp'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_National.Govts.M2D_govts_portfolio
    
    name_sheet = 'VA_N_Govts_Comp';
    

     
    %  Labels for each issuer in row 10
    %  -------------------------------------------------------------------- 
              
    C1R_National_Govts_Issuers_id = Str_VA_National.Govts.C1R_govts_issuers;
    

    for count_country = 1:length(C1R_National_Govts_Issuers_id)
             
        code_curncy = C1R_National_Govts_Issuers_id{ count_country } ; 
        
        if ~strcmp(code_curncy, 'EUR')
            
            if strcmp(code_curncy, 'GBP')
                C1R_National_Govts_Issuers_id{ count_country } = 'UK';                
            else
                C1R_National_Govts_Issuers_id{ count_country } = code_curncy(1:2);
            end
            
        else
            C1R_National_Govts_Issuers_id{ count_country } = code_curncy;  
        end
      
        
    end   
    
    
   
    %  Labels for each market in column B
    %  -------------------------------------------------------------------- 
               
    C1R_National_Markets_id = Str_VA_National.C1C_countries;
   

    for count_country = 1:length(C1R_National_Markets_id)
             
        code_curncy = C1R_National_Markets_id{ count_country } ; 
        
        if ~strcmp(code_curncy, 'EUR')
            
            if strcmp(code_curncy, 'GBP')
                C1R_National_Markets_id{ count_country } = 'UK';                
            else
                C1R_National_Markets_id{ count_country } = code_curncy(1:2);
            end
            
        else
            C1R_National_Markets_id{ count_country } = code_curncy;  
        end
      
        
    end   
    
    
    
    
    %   List of information to write
    %   -------------------------------------------------------------------
        
    
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(100, 100);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = C1R_National_Govts_Issuers_id;
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = C1R_National_Markets_id(rows_to_write_National);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_National.Govts.M2D_govts_portfolio(rows_to_write_National, :);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    
    
    %   -------------------------------------------------------------------
    %%  3.2.  Worksheet  'VA_N_Govts_Dur'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_National.Govts.M2D_govts_durations
    
    name_sheet = 'VA_N_Govts_Dur';
    
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(100, 100);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = C1R_National_Govts_Issuers_id;
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = C1R_National_Markets_id(rows_to_write_National);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_National.Govts.M2D_govts_durations(rows_to_write_National, :) ;
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    
    
    
    
    
    
    
    
    %   -------------------------------------------------------------------
    %%  4.1.  Worksheet  'VA_C_Corps_Comp'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_Currency.Corps.M2D_corps_portfolio
    
    name_sheet = 'VA_C_Corps_Comp' ;

    %  Labels for each issuer in row 10
    %  -------------------------------------------------------------------- 
         
    C1R_Currency_Corps_Issuers_id = Str_VA_Currency.Corps.C1R_corps_issuers ;

    
    for count_country = 15 : 1 : length ( C1R_Currency_Corps_Issuers_id )
             
        code_curncy = C1R_Currency_Corps_Issuers_id { count_country }  ; 
        
        if strcmp( code_curncy , 'EUR' ) == 0
            
            if strcmp( code_curncy , 'GBP' ) == 1
                C1R_Currency_Corps_Issuers_id { count_country } = 'UK' ;                
            else
                C1R_Currency_Corps_Issuers_id { count_country } = code_curncy ( 1:2 ) ;
            end
            
        else
            C1R_Currency_Corps_Issuers_id { count_country } = code_curncy ;  
        end
      
        
    end        

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = cell( 100 , 100 ) ;
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 10, 2, size(aux,1) , size(aux,2) ) ;

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = C1R_Currency_Corps_Issuers_id  ;
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 10, 3, size(aux,1) , size(aux,2) ) ;

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = Str_VA_Currency.C1C_countries(rows_to_write_Curncy);
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 11, 2, size(aux,1) , size(aux,2) ) ;

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = Str_VA_Currency.Corps.M2D_corps_portfolio(rows_to_write_Curncy,:);
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 11, 3, size(aux,1) , size(aux,2) ) ;
    
    
    %   -------------------------------------------------------------------
    %%  4.2.  Worksheet  'VA_C_Corps_Dur'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_Currency.Corps.M2D_corps_durations
    
    name_sheet = 'VA_C_Corps_Dur' ;
    
    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = cell( 100 , 100 ) ;
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 10, 2, size(aux,1) , size(aux,2) ) ;

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = C1R_Currency_Corps_Issuers_id  ;
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 10, 3, size(aux,1) , size(aux,2) ) ;

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = Str_VA_Currency.C1C_countries(rows_to_write_Curncy);
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 11, 2, size(aux,1) , size(aux,2) ) ;

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = Str_VA_Currency.Corps.M2D_corps_durations(rows_to_write_Curncy,:);
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 11, 3, size(aux,1) , size(aux,2) ) ;

    %   -------------------------------------------------------------------
    %%  4.3.  Worksheet  'VA_N_Corps_Comp'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_Currency.Corps.M2D_corps_portfolio
    
    name_sheet = 'VA_N_Corps_Comp' ;
    
    
    
    %  Labels for each issuer in row 10
    %  -------------------------------------------------------------------- 
         
    C1R_National_Corps_Issuers_id = Str_VA_National.Corps.C1R_corps_issuers;

    
    for count_country = 15 : 1 : length(C1R_National_Corps_Issuers_id)
             
        code_curncy = C1R_National_Corps_Issuers_id{ count_country } ; 
        
        if ~strcmp(code_curncy, 'EUR')
            
            if strcmp(code_curncy, 'GBP')
                C1R_National_Corps_Issuers_id{ count_country } = 'UK';                
            else
                C1R_National_Corps_Issuers_id{ count_country } = code_curncy(1:2);
            end
            
        else
            C1R_National_Corps_Issuers_id{ count_country } = code_curncy;  
        end
      
        
    end        
    
        
    
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(100, 100);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = C1R_National_Corps_Issuers_id ;
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = C1R_National_Markets_id( rows_to_write_National,: ) ;
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 11, 2, size(aux,1) , size(aux,2) ) ;

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = Str_VA_National.Corps.M2D_corps_portfolio( rows_to_write_National,: ) ;
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 11, 3, size(aux,1) , size(aux,2) ) ;
    
    
    %   -------------------------------------------------------------------
    %%  4.4.  Worksheet  'VA_N_Corps_Dur'
    %   -------------------------------------------------------------------
    %   With structure Str_VA_Currency.Corps.M2D_corps_durations
    
    name_sheet = 'VA_N_Corps_Dur' ;
    
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(100, 100);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 2, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = C1R_National_Corps_Issuers_id ;
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = C1R_National_Markets_id(rows_to_write_National,:);
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 11, 2, size(aux,1) , size(aux,2) ) ;

    counter = counter + 1 ;
    sheet_output { counter } = name_sheet ;
    aux = Str_VA_National.Corps.M2D_corps_durations(rows_to_write_National,:);
    data_output  { counter } = aux ;
    range_output { counter } = calcexcelrange( 11, 3, size(aux,1) , size(aux,2) ) ;
    
    % last writing of the date of calculation in the main worksheet
    
    name_sheet = 'Main_Menu';     

    counter = counter + 1;
    sheet_output{counter}    = name_sheet;
    aux ={ datestr(date_calc, 'dd-mm-yyyy') };
    data_output{counter}    = aux;
    range_output{counter}    = calcexcelrange( 1, 1, size(aux,1), size(aux,2));

    text_waitbar = 'Writing info representative portfolios --> RFR_for_publication_VA';
    
    xlswrite_mult_msg(file_output , data_output  , sheet_output  , range_output, text_waitbar);

end

