function RFR_13_for_publication_excel_PD_CoD_corps ...
                       (config, Str_PD_CoD_outputs, ...
                        Str_VA_Currency, Str_LTAS, date_calc)
              

%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------

    %   This function writes in excel file 'RFR_for_publication_PD_CoD'
    %   the relevant outputs for the LTAS and FS(PD and CoD)
    
%  ------------------------------------------------------------------------
%  ------------------------------------------------------------------------



%  ========================================================================
%%  1. Loading variables common to the following steps within this function
%  ========================================================================

    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
    col_EEA = config.RFR_Str_lists.Str_numcol_curncy.EEA;
    FS_percent_LTAS_Govts_EEA = config.RFR_Str_lists.Parameters.FS_percent_LTAS_Govts_EEA;
    FS_percent_LTAS_Govts_non_EEA = config.RFR_Str_lists.Parameters.FS_percent_LTAS_Govts_non_EEA;
      
    
    num_curves = size(config.RFR_Str_lists.C2D_list_curncy , 1);

    FS_Finan = zeros(num_curves, 7);
    FS_Nonfinan = zeros(num_curves , 7);
    maturity = 5;
    
%  ========================================================================
%%  1. Writing excel file referred to central government bonds VA Currency
%  ========================================================================

    
    file_output = fullfile(config.RFR_Str_config.folders.path_RFR_08_Results, ...
                          'RFR_for_publication_PD_CoD.xlsx');     

                      
    num_writings = 2;  %   just initizialtize the cell arrays below
                        %   in this way their size will increase  IN ROWS
                        %   according the outputs to write, 
                        %   without being exposed to a failure 
                        %  (e.g. empty rows of the arrays)
                        %   Warning.- num_writings=1 will lead to increase 
                        %   cell arrays in columns and the there will be
                        %   only one writing                        
                        
    sheet_output = cell(num_writings , 1);
    data_output  = cell(num_writings , 1);
    range_output = cell(num_writings , 1);
    
    counter = 0;



    
    %   -------------------------------------------------------------------
    %%  1.1. Worksheet  'LTAS_Govts'
    %   -------------------------------------------------------------------
    %   With structure Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec
    
    name_sheet = 'LTAS_Govts';
  
    %  Labels for each country in column B
    %  -------------------------------------------------------------------- 
                
    C1C_Currency_Markets_id = config.RFR_Str_lists.C2D_list_curncy(: , col_ISO3166);
    
    for count_country = 1 : 1 : length(C1C_Currency_Markets_id)
             
        code_curncy = C1C_Currency_Markets_id { count_country } ; 
        
        if ~strcmp(code_curncy, 'EUR')
            
            if strcmp(code_curncy, 'GBP')
                C1C_Currency_Markets_id { count_country } = 'UK';                
            else
                C1C_Currency_Markets_id { count_country } = code_curncy(1:2);
            end
            
        else
            C1C_Currency_Markets_id { count_country } = code_curncy;  
        end
       
    end    
                
    
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = cell(100 , 100);
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 2, size(aux,1) , size(aux,2));
                        
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = C1C_Currency_Markets_id;
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 2, size(aux,1) , size(aux,2));
               
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(: , 1 : 30);
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 3, size(aux,1) , size(aux,2));

    
    %   -------------------------------------------------------------------
    %%  1.2.  Writing Worksheet  'LTAS_Corps'
    %   -------------------------------------------------------------------
    %   With structure Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec
    
    name_sheet = 'LTAS_Corps';
    
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = cell(100 , 100);
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 3, size(aux,1) , size(aux,2));
                    
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(: , 1 : 30);
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 3, size(aux,1) , size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  1.3.  Writing Worksheet  'LTAS_Basic'
    %   -------------------------------------------------------------------
    %   With structure Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread
    
    name_sheet = 'LTAS_Basic_RFR';
    
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = cell(100 , 100);
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 2, size(aux,1) , size(aux,2));
                        
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = C1C_Currency_Markets_id;
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 2, size(aux,1) , size(aux,2));
               
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = real(Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread(: , 1 : 30));
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 3, size(aux,1) , size(aux,2));

     
    
    
    %   -------------------------------------------------------------------
    %%  1.4.  Writing Worksheet  'LTAS_Specifics'
    %   -------------------------------------------------------------------
    %   With structure Str_LTAS.Corps.DKK_Nykredit_LTAS_spread
    
    name_sheet = 'LTAS_Specifics';
    
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = cell(100 , 100);
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 2, size(aux,1) , size(aux,2));
                        
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = { 'LTAS DKK Nykredit index' };
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 2, size(aux,1) , size(aux,2));
               
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = Str_LTAS.Corps.DKK_Nykredit_LTAS_spread;
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 4, size(aux,1) , size(aux,2));
   
    
    
    
    
     %   -------------------------------------------------------------------
    %%  1.5.  Writing Worksheet  'FS_Govts'
    %   -------------------------------------------------------------------
    %   With structure Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec
    
    % For the production version from March 2016 onwards an extra worksheet
    % labeled 'FS_Govts' has been added.
    % This worksheet contains the fundamental spread(rounded to 2
    % decimals) for government bonds for publication purposes only.
    % Based on the LTAS stored in Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec
    % the FS is calculated taking account of the EEA/non_EAA criterium to set the
    % FS_percentage(either 30% for EEA or 35% for non_EEA.
   
    name_sheet = 'FS_Govts';
    
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = cell(100 , 100);
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 2, size(aux,1) , size(aux,2));
                        
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    aux = C1C_Currency_Markets_id;
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 2, size(aux,1) , size(aux,2));
               
    counter = counter + 1;
    sheet_output { counter } = name_sheet;
    
    FS_Govts = cell(size(Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(:, 1:30)));
    for count_country = 1 : 1 : length(C1C_Currency_Markets_id)
        if sum(Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(count_country, 1:30) == 0) == 30
            FS_Govts(count_country, :) = {'n/a'};
        else
            if strcmp(config.RFR_Str_lists.C2D_list_curncy(count_country, col_EEA), 'EEA')
                FS_Govts(count_country, :) = num2cell(max(0,round(100 * FS_percent_LTAS_Govts_EEA * Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(count_country, 1:30))/100));
            else
                FS_Govts(count_country, :) = num2cell(max(0,round(100 * FS_percent_LTAS_Govts_non_EEA * Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(count_country, 1:30))/100));
            end
        end 
    end
    
    aux = FS_Govts;    
    data_output  { counter } = aux;
    range_output { counter } = calcexcelrange(11, 3, size(aux,1) , size(aux,2));

    
    %   -------------------------------------------------------------------
    %%  1.6.  Writing Financial PD, CoD and FS
    %   -------------------------------------------------------------------
    %   With structure Str_PD_CoD_outputs
    
    for k = 1 : 1 : num_curves  
        id_country = config.RFR_Str_lists.C2D_list_curncy {k, col_ISO3166};
 
        
        if strcmp(id_country, 'ISK')
            continue
        end
        
        if strcmp(config.RFR_Str_lists.C2D_list_curncy{k,col_ISO4217}, 'EUR') &&(k > 1)
            continue
        end
  
        
        name_sheet = id_country;
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = cell(300 , 300);
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(1, 2, size(aux,1) , size(aux,2));
        
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Financial. Probability of default(probability)' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 7 , 3 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Maturity' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 11 , 1 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Credit quality steps' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 9 , 6 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(0 : 1 : 6);
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(10, 3 , size(aux,1) , size(aux,2));

        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(1 : 1 : 30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(11, 2 , size(aux,1) , size(aux,2));
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = Str_PD_CoD_outputs.(id_country).Finan.PD_prob(1:7,1:30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(11, 3 , size(aux,1) , size(aux,2));
      

       
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Financial. Probability of default(percentages)' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 7, 13 , size(aux,1) , size(aux,2));
      
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Maturity' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 11 , 11 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Credit quality steps' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 9 , 16 , size(aux,1) , size(aux,2));
    
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(0 : 1 : 6);
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(10, 13 , size(aux,1) , size(aux,2));

        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(1 : 1 : 30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(11, 12 , size(aux,1) , size(aux,2));
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = Str_PD_CoD_outputs.(id_country).Finan.PD_bp(1:7,1:30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(11, 13 , size(aux,1) , size(aux,2));
      

       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Financial. Fundamental spread(percentages)' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 7, 23 , size(aux,1) , size(aux,2));
      
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Maturity' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 11 , 21 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Credit quality steps' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 9 , 26 , size(aux,1) , size(aux,2));
    
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(0 : 1 : 6);
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(10, 23 , size(aux,1) , size(aux,2));

        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(1 : 1 : 30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(11, 22 , size(aux,1) , size(aux,2));
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = Str_PD_CoD_outputs.(id_country).Finan.FS_bp(1:7,1:30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(11, 23 , size(aux,1) , size(aux,2));
      

       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Financial. Cost of downgrade(percentages)' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 7, 33 , size(aux,1) , size(aux,2));
      
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Maturity' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 11 , 31 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Credit quality steps' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 9 , 36 , size(aux,1) , size(aux,2));
    
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(0 : 1 : 6);
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(10, 33 , size(aux,1) , size(aux,2));

        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(1 : 1 : 30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(11, 32 , size(aux,1) , size(aux,2));
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = Str_PD_CoD_outputs.(id_country).Finan.CoD_bp(1:7,1:30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(11, 33 , size(aux,1) , size(aux,2));
          

        
               
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { id_country };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(10, 2 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =  { id_country };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(10, 12 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =  { id_country };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(10, 22 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =  { id_country };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(10, 32 , size(aux,1) , size(aux,2));


        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =  { 'Undertakings will calculate the FS other than PD as maximum of(CoD; and FS - PD)' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(6, 40 , 1 , 1);

    end

    %   -------------------------------------------------------------------
    %%  1.7.  Writing Non Financial
    %   -------------------------------------------------------------------
    %   With structure Str_PD_CoD_outputs
    
    for k = 1 : 1 : num_curves  
              
        id_country = config.RFR_Str_lists.C2D_list_curncy { k , col_ISO3166 };
        
        name_sheet = id_country;
        id_country = config.RFR_Str_lists.C2D_list_curncy { k , col_ISO3166 };
        
        if strcmp(id_country, 'ISK')
            continue
        end
        
        if strcmp(config.RFR_Str_lists.C2D_list_curncy{k, col_ISO4217}, 'EUR') &&(k > 1)
            continue
        end
        
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Non-financial. Probability of default(probability)' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(47 , 3 , size(aux,1) , size(aux,2));
      
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Maturity' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 51 , 1 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Credit quality steps' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 49 , 6 , size(aux,1) , size(aux,2));
           
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(0 : 1 : 6);
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(50, 3 , size(aux,1) , size(aux,2));

        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(1 : 1 : 30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(51, 2 , size(aux,1) , size(aux,2));
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = Str_PD_CoD_outputs.(id_country).Nonfinan.PD_prob(1:7,1:30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(51, 3 , size(aux,1) , size(aux,2));

        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Non-financial. Probability of default(percentages)' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(47, 13 , size(aux,1) , size(aux,2));
     
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Maturity' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 51 , 11 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Credit quality steps' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 49 , 16 , size(aux,1) , size(aux,2));
    
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(0 : 1 : 6);
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(50, 13 , size(aux,1) , size(aux,2));

        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(1 : 1 : 30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(51, 12 , size(aux,1) , size(aux,2));
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = Str_PD_CoD_outputs.(id_country).Nonfinan.PD_bp(1:7,1:30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(51, 13 , size(aux,1) , size(aux,2));
      

       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Non-financial. Fundamental spread(percentages)' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(47, 23 , size(aux,1) , size(aux,2));
     
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Maturity' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 51 , 21 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Credit quality steps' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 49 , 26 , size(aux,1) , size(aux,2));
    
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(0 : 1 : 6);
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(50, 23 , size(aux,1) , size(aux,2));

        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(1 : 1 : 30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(51, 22 , size(aux,1) , size(aux,2));
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = Str_PD_CoD_outputs.(id_country).Nonfinan.FS_bp(1:7,1:30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(51, 23 , size(aux,1) , size(aux,2));
      

       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Non-financial. Cost of downgrade(percentages)' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(47, 33 , size(aux,1) , size(aux,2));
     
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Maturity' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 51 , 31 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'Credit quality steps' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 49 , 36 , size(aux,1) , size(aux,2));
    
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(0 : 1 : 6);
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(50, 33 , size(aux,1) , size(aux,2));

        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =(1 : 1 : 30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(51, 32 , size(aux,1) , size(aux,2));
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = Str_PD_CoD_outputs.(id_country).Nonfinan.CoD_bp(1:7,1:30)';
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(51, 33 , size(aux,1) , size(aux,2));
          
              
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =  { id_country };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(50, 2 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =  { id_country };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(50, 12 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =  { id_country };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(50, 22 , size(aux,1) , size(aux,2));
       
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =  { id_country };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(50, 32 , size(aux,1) , size(aux,2));


        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux =  { 'Undertakings will calculate the FS other than PD as maximum of(CoD; and FS - PD)' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange(46, 40 , 1 , 1);

        %   located at the end to set the pointer to left-upper corner
        %   when the file is open
        
        counter = counter + 1;
        sheet_output { counter } = name_sheet;
        aux = { 'CORPORATE BONDS' };
        data_output  { counter } = aux;
        range_output { counter } = calcexcelrange( 4 , 2 , size(aux,1) , size(aux,2));      
        
    end

    % last writing of the date of calculation in the main worksheet
    
    name_sheet = 'Main';     

    counter = counter + 1;
    sheet_output { counter }    = name_sheet;
    aux = { datestr(date_calc , 'dd-mm-yyyy') };
    data_output  { counter }    = aux;
    range_output { counter }    = calcexcelrange( 1 , 1 , size(aux,1) , size(aux,2));

    text_waitbar = 'Writing info PD, CoD and FS --> RFR_for_publication_PD_CoD.xlsx';
    
    xlswrite_mult_msg(file_output, data_output, sheet_output, range_output, text_waitbar);

end

