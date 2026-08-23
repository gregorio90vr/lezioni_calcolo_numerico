function [M2D_VA_final,Str_VA_Currency,Str_VA_National] = ...
    RFR_09_VA_Overall(config, Str_VA_Currency, Str_VA_National)     
     
%   -----------------------------------------------------------------------   
%%  Explanation of this function 
%   -----------------------------------------------------------------------

    %   This funtion delivers the final values of the VA 
    
    %   The inputs are the weights ofr both portfolios 
    %  (central govts - other assets)
    %   and the three internal effective rates needed for the purpose
    %   calculated using as rate for the projection and discount
    %       yield before risk correction
    %       basic risk-free rates
    %       yield after risk correction

    %   The output is a 2-dimensional matrix
    %       rows = all possible country/currency, 
    %		   regardless the VA is calculated or not
    %	    first column  = currency VA
    %       second column = currency + country specific increase
    
        
%   =======================================================================
%%  1. Loading configuration, insurance market data and government curves  
%   =======================================================================
    
    %   Loading to workspace the configuration data
    %   -------------------------------------------    
    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
        %   number of the column in cell array
        %   config.RFR_Str_lists.C2D_list_curncy containing ISO3166 and ISO4217
        %   for each of the currencies considered
    

   %  mnemonics for formulas
   %  Matrix  M2D_weights  has two columns, with the weights of the 
   %  reference portfolios for government and corporate bonds curves
   
   govt = 1 ; 
   corp = 2 ;

   %    columns of the elements  'M2D_govts_IER'  and 'M2D_corps_IER'
   
   mkt_yield = 1 ;  
   rfr = 2 ;  
   yield_corrected = 3;
   

   %    creating the 2-dimensional matrix to store the outputs
   %    rows  = countries/currencies as in  config.RFR_Str_lists.C2D_list_curncy
   %    first column = currency VA; second column = currency + country
   
   M2D_VA_final = zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1), 2); 

        %       rows = all possible country/currency, 
        %	       regardless the VA is calculated or not
        %       first column  = currency VA
        %       second column = currency + country specific increase
   
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   %    Specific case for Iceland
   %    Calculation of the ISK VA is based on the HRK data
   %    cf. technical docution section 9.D
   row_ISK = strcmp('ISK', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));
   row_HRK = strcmp('HRK', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));
   
   Str_VA_Currency.Govts.M2D_govts_IER(row_ISK, :) = ...
                        Str_VA_Currency.Govts.M2D_govts_IER(row_HRK, :);
   
   Str_VA_Currency.Corps.M2D_corps_IER(row_ISK, :) = ...
                        Str_VA_Currency.Corps.M2D_corps_IER(row_HRK, :);
   
   Str_VA_National.Govts.M2D_govts_IER(row_ISK, :) = ...
                        Str_VA_National.Govts.M2D_govts_IER(row_HRK, :);
   
   Str_VA_National.Corps.M2D_corps_IER(row_ISK, :) = ...
                        Str_VA_National.Corps.M2D_corps_IER(row_HRK, :);
                    
%   =======================================================================
%%  2. Calculation of the currency   
%   =======================================================================


    %   2.1. Overall currency spread(before applying 65%) as if there is
    %        a VA for govts and a VA for corps
    %   -------------------------------------------------------------------
    
    %   This is a notional calculation that will be immediately replaced 
    %   in sub-section 2.2. 
    %   This first calculation is envisaged for analitical purposes
    %   The second calculations is the one reflected in the legal text
    %   Both of them are equivalent(always deliver the same outputs)   
    
    V1C_Currency_spread_after = ...
        Str_VA_Currency.M2D_weights(:, govt) .* ...
       (max(0, Str_VA_Currency.Govts.M2D_govts_IER(:, mkt_yield) - ...
                    Str_VA_Currency.Govts.M2D_govts_IER(:, rfr)) - ... 
          max(0, Str_VA_Currency.Govts.M2D_govts_IER(:, mkt_yield) - ...
                    Str_VA_Currency.Govts.M2D_govts_IER(:, yield_corrected))) + ... 
        Str_VA_Currency.M2D_weights(:, corp) .* ...
       (max(0, Str_VA_Currency.Corps.M2D_corps_IER(:, mkt_yield) - ...
                    Str_VA_Currency.Corps.M2D_corps_IER(:, rfr)) - ...
          max(0, Str_VA_Currency.Corps.M2D_corps_IER(:, mkt_yield) - ...
                    Str_VA_Currency.Corps.M2D_corps_IER(:, yield_corrected)));


    %   2.2. Overall currency spread(before applying 65%) as set out  
    %        in the Implementing Measures. The output is as in 2.1.
    %   -------------------------------------------------------------------
    
    V1C_Currency_spread_after = ...
        Str_VA_Currency.M2D_weights(:, govt) .* ...
       (max(0, Str_VA_Currency.Govts.M2D_govts_IER(:, mkt_yield) - ...
                    Str_VA_Currency.Govts.M2D_govts_IER(:, rfr))) + ... 
        Str_VA_Currency.M2D_weights(:, corp) .* ...
       (max(0, Str_VA_Currency.Corps.M2D_corps_IER(:, mkt_yield) - ...
                    Str_VA_Currency.Corps.M2D_corps_IER(:, rfr))) - ...
        Str_VA_Currency.M2D_weights(:, govt) .* ...
       (max(0, Str_VA_Currency.Govts.M2D_govts_IER(:, mkt_yield) - ...
                    Str_VA_Currency.Govts.M2D_govts_IER(:, yield_corrected))) - ...
        Str_VA_Currency.M2D_weights(:, corp) .* ...        
       (max(0, Str_VA_Currency.Corps.M2D_corps_IER(:, mkt_yield) - ...
                    Str_VA_Currency.Corps.M2D_corps_IER(:, yield_corrected)));
        

    
    M2D_VA_final(:, 1) = config.RFR_Str_lists.Parameters.VA_percentage_RCS * V1C_Currency_spread_after ;
    M2D_VA_final(:, 2) = config.RFR_Str_lists.Parameters.VA_percentage_RCS * V1C_Currency_spread_after ;
    
        %   rows = all possible country/currency, 
        %	       regardless the VA is calculated or not
        %	first column  = currency VA
        %   second column = currency + country specific increase
        
        %   Note that although the second column(total VA) at this stage
        %   has the same values as the first one(currency VA),
        %   at a later stage within this function(section 3)
        %   the values of the second column(total VA) will be increased
        %  (where relevant) with the country specific increase 

        %   'config.RFR_Str_lists.Parameters.VA_percentage_RCS'
        %   is a parameter set out in sheet  'Parameters'
        %   of excel file   'RFR_excel_confing.xlsx'
        %   and moved to  'config.RFR_Str_lists.Parameters'  in section 2.6
        %   at the end of fucntion   'RFR_01_basic_setting_config.m'

    
    %   2.3. Setting the same currency VA for all countries of the Eurozone
    %   --------------------------------------------------------------
    
    for k_run = 1:size(Str_VA_Currency.C1C_countries, 1)
             
        if strcmp('EUR', config.RFR_Str_lists.C2D_list_curncy(k_run, col_ISO4217))
            V1C_Currency_spread_after(k_run, :) =  V1C_Currency_spread_after(1);
            M2D_VA_final(k_run, :) =  M2D_VA_final(1, :);
        end
                
    end

    
    
%   =======================================================================
%%  3. Calculation of the currency + country VA   
%   =======================================================================

    
    %   3.1. Overall country spread(before applying 65%) as if there is
    %        a VA for govts and a VA for corps
    %   -------------------------------------------------------------------
    
    V1C_National_spread_after = ...
        Str_VA_National.M2D_weights(:, govt) .* ...
       (max(0, Str_VA_National.Govts.M2D_govts_IER(:, mkt_yield) - ...
                    Str_VA_National.Govts.M2D_govts_IER(:, rfr)) - ... 
          max(0, Str_VA_National.Govts.M2D_govts_IER(:, mkt_yield) - ...
                    Str_VA_National.Govts.M2D_govts_IER(:, yield_corrected))) + ... 
        Str_VA_National.M2D_weights(:, corp) .* ...
       (max(0, Str_VA_National.Corps.M2D_corps_IER(:, mkt_yield) - ...
                    Str_VA_National.Corps.M2D_corps_IER(:, rfr)) - ...
          max(0, Str_VA_National.Corps.M2D_corps_IER(:, mkt_yield) - ...
                    Str_VA_National.Corps.M2D_corps_IER(:, yield_corrected)));



    %   3.2. Overall country spread(before applying 65%) as set out  
    %        in the Implementing Measures. The output is as in 2.1.
    %   -------------------------------------------------------------------
    
    V1C_National_spread_after = ...
        Str_VA_National.M2D_weights(:, govt) .* ...
       (max(0, Str_VA_National.Govts.M2D_govts_IER(:, mkt_yield) - ...
                    Str_VA_National.Govts.M2D_govts_IER(:, rfr))) + ... 
        Str_VA_National.M2D_weights(:, corp) .* ...
       (max(0, Str_VA_National.Corps.M2D_corps_IER(:, mkt_yield) - ...
                    Str_VA_National.Corps.M2D_corps_IER(:, rfr))) - ...
        Str_VA_National.M2D_weights(:, govt) .* ...
       (max(0, Str_VA_National.Govts.M2D_govts_IER(:, mkt_yield) - ...
                    Str_VA_National.Govts.M2D_govts_IER(:, yield_corrected))) - ...
        Str_VA_National.M2D_weights(:, corp) .* ...        
       (max(0, Str_VA_National.Corps.M2D_corps_IER(:, mkt_yield) - ...
                    Str_VA_National.Corps.M2D_corps_IER(:, yield_corrected)));
    

    
    %   3.3. Adding the country specific increase of the currency VA
    %        according to Article 77d Directive 2009/138/EC
    %   -------------------------------------------------------------------
    
    
    for k_run = 1:size(Str_VA_Currency.C1C_countries, 1)
             
        if (V1C_National_spread_after(k_run) > 1.00)  && ...
           (V1C_National_spread_after(k_run) - 2 * V1C_Currency_spread_after(k_run) > 0)  
                
            M2D_VA_final(k_run, 2) = M2D_VA_final(k_run, 1) +  ...
                       config.RFR_Str_lists.Parameters.VA_percentage_RCS *  ... 
                      (V1C_National_spread_after(k_run)  - ...
                                 2 * V1C_Currency_spread_after(k_run));           
        end
                
    end

    
    %   Rounding VA   Section 11 parag 308 EIOPA Technical Documentation
    
    M2D_VA_final = round(M2D_VA_final * 100) / 100;    

    
%   =====================================================================================
%%  4. Countries with no reliable government bonds curves in the selected market provider
%       Sub-section 9.E, parag. 246 and table 11 of
%       EIOPA Technical Documentation(published October 27th, 2015)
%   =====================================================================================
    
    row_CY = strcmp('CY', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));    
    M2D_VA_final(row_CY,2) = M2D_VA_final(row_CY,1);

    row_EE = strcmp('EE', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));    
    M2D_VA_final(row_EE,2) = M2D_VA_final(row_EE,1);
    
    row_LVL = strcmp('LVL', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));    
    M2D_VA_final(row_LVL,2) = M2D_VA_final(row_LVL,1);
    
    row_LTL = strcmp('LTL', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));    
    M2D_VA_final(row_LTL,2) = M2D_VA_final(row_LTL,1);
    
    row_LU = strcmp('LU', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));    
    M2D_VA_final(row_LU,2) = M2D_VA_final(row_LU,1);
    
    row_MT = strcmp('MT', config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166));    
    M2D_VA_final(row_MT,2) = M2D_VA_final(row_MT,1);
 
%   =======================================================================
%%  5. Saving the workspace
%   =======================================================================

%     save(fullfile(config.RFR_Str_config.folders.path_RFR_99_Workspace, ...
%                         'RFR_08E_VA_Overall_workspace'))

end
