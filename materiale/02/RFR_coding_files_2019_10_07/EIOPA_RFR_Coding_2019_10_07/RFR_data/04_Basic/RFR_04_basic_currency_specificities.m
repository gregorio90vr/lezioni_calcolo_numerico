function    [Str_assumptions,M2D_raw_curves, ...
              M2D_DLT] = ...
                      RFR_04_basic_currency_specificities ...
                (config, date_calc , Str_assumptions , ...
                   M2D_raw_curves  , M2D_DLT ) 
      

%%  SPECIAL CASES FOR THE CALCULATIONS
%       This function adjust the calcucations and inputs
%       in order to consider specific cases in the calculations
%   -----------------------------------------------------------------------
%   -----------------------------------------------------------------------


        
    
    %   Loading to workspace the configuration data
    %   -------------------------------------------    
    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166 ;
    
        %   number of the column in cell array
        %   'config.RFR_Str_lists.C2D_list_curncy'  containing 
        %   for each of the currencies / countries considered its ISO3166
        
    
    %   Loading to the workspace the historical series of interest rates 
    %   ----------------------------------------------------------------    
    
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads ;
    file_download = 'RFR_basic_curves' ;     

    %   serie of interest rates for the currency of each run

    eval( strcat ( ' load ( ''' , folder_download, '\', file_download , ''',''' , 'RFR_download_BBL_Mid' , ''')' ) )

    num_terms = size ( M2D_raw_curves , 2 ) ;
    
   
    %%  Special curve for Icelandic government bonds
    %   -------------------------------------------------------------------
 
    %   WARNING: When calculating the history of basic risk-free rates
    %   the batch process does not calculate for the Icelandic currency
    %   ( function  'VA_History_basic_RFR_batch_all_curves.m' )
    
    %   Function  'RFR_11_for_publication_excel_RFR_curves.m'
    %   contains a specific treatment for Icelandic currency
    
    %   Function  'RFR_13_for_publication_excel_PD_CoD_corps.m'
    %   contains a specific treatment for Icelandic currency

    
    
    
   
    %%  Special curve for Sweden convergence period
    %   -------------------------------------------------------------------
    
    %   Already considered in the configuration data
    %   Excel file  'RFR_excel_config.xlsx'
    
    %   Nevertheless this should be retained in this last step
    %   previous to the extrapolation, in order to prevent
    %   any previous overriding of the criteria
    
    row_SEK = strcmp( config.RFR_Str_lists.C2D_list_curncy( : , col_ISO3166) , 'SEK' ) == 1 ;

    Str_assumptions.VecCol_convergence (row_SEK ) = 10 ;
    
    
    
end

