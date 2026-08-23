function [Str_VA_outputs,Str_LTAS,Str_PD_CoD_outputs] = ...
                    RFR_08_VA_MA_main_function ...
       (date_calc, config, ER_no_VA, type_VA, Str_LTAS)
         

 %   These instructions are only for backtestin when the LTAS
 %   are frozen(e.g. to 31/12/2014). 
 %   They are coupled with the corresponding instructions 
 %   before executing the calculation of the internal effective rates
 %   for governments(step 4)
 %       date_calc_real = date_calc;   date_calc = 735964;


%   =======================================================================
%%  1. Loading configuration, insurance market data and government curves  
%   =======================================================================
    % to avoid LaTex messages in command window
    set(0, 'DefaulttextInterpreter', 'none');
        

    if ~strcmp(type_VA, 'Currency') && ~strcmp(type_VA, 'National')
            
        info = ['Process cancelled. Type  ' type_VA ' of the VA not recognized.'];
        RFR_log_register('06_VA', 'RFR_08_VA_main', 'ERROR', info, config);

        return  % the coding is interrupted
        
    end

    %   Loading to workspace the configuration data
    %   ------------------------------------------------------------------- 

    col_ISO3166 = config.RFR_Str_lists.Str_numcol_curncy.ISO3166;
    
        %   number of the column in cell array
        %   RFR_Str_lists.C2D_list_curncy containing ISO3166
        %   for each of the currencies / countries considered
   
        
    %   Loading to workspace insurance market data for the VA
    %   -----------------------------------------------------   
    
    folder_download = config.RFR_Str_config.folders.path_RFR_06_VA;    
    file_download = 'Str_VA_market_data';          
    
        %   Name of the MatLab structure with the historical sets of
        %   insurance market data for the calculation of the VA
        %  (weights, representative portfolios,...)
        
    load(fullfile(folder_download, file_download))
    
    file_download = 'Str_PD_CoD';          

        %   Name of the MatLab structure with the historical series of 
        %   default statistics(transition matrices)
        
    load(fullfile(folder_download, file_download))
    
   
    
    %   Factor to apply when referring corporate yields to euro corporate
    %   --------------------------------------------------------------------
      
    k_factor = config.RFR_Str_lists.Parameters.k_factor_corps_spreads ;
    
       %    k-factor = kappa as described on sub-section 10.C.4
       %    of EIOPA Technical Documentation(published October 27th, 2015) 
        
       %    This parameter is set out in sheet  'Parameters'
       %    of excel file   'RFR_excel_confing.xlsx'
       %    and moved to  'RFR_Str_lists.Parameters'  in section 2.6
       %    at the end of fucntion   'RFR_01_basic_setting_config.m'
    
       
    
%   =======================================================================
%%  2. Selection set of insurance market data to use for calculation of VA  
%   =======================================================================


    %   Selecting the relevant set according to date of calculation
    %   ----------------------------------------------------------------
    
    %   Insurance market data for different dates are stored in 
    %   MatLab structure  'Str_VA_market_data'
    %   Data for each date(e.g. 31_12_2011, 31_12_2013,...)
    %   are stored in an element of the structure named:
    
    %   For the currency VA
    %       VA_C_yyyymmdd   for example   Str_VA_market_data.VA_C_20131231
   
    %   For the country VA
    %       VA_N_yyyymmdd   for example   Str_VA_market_data.VA_N_20131231
    
    
    %   Within the MatLab structure 'Str_VA_market_data'
    %   there is a 2-dimensional matrix   'M2D_VA_dates'
    %   Matrix  M2D_VA_dates contains two columns
    %       first column: dates of reference of the available VA data sets
    %       second column: first date of application of each data set
    %          (i.e. data set referred to 20131231 might not be applicable
    %            to calculations before 20140630)
    %
    %  The date used for the comparison is based on the reference date.
    
    row_date_to_use = find(config.refDate >= M2D_VA_dates(:,2), 1, 'last');    
        %   identification of the row of the second column 'M2D_VA_dates'
        %   that gives the date of reference to use(date in first column)
        
    date_to_use = datestr(M2D_VA_dates(row_date_to_use, 1), 'yyyymmdd');
        %   identification of date of the set of insurance market data
        %   regarding the VA to use(first column)
    

        
    if strcmp('Currency', type_VA)   
       Str_VA_selected = Str_VA_market_data.(strcat('VA_C_', date_to_use));
    else
       Str_VA_selected = Str_VA_market_data.(strcat('VA_N_', date_to_use));
    end
             %   from now on, the set of VA insurance market data
             %   is in MatLab structure named   'Str_VA_selected'

        

   
%   =======================================================================
%%  3. Transferring insurance market data to standard list countries   
%   =======================================================================
    

    %   The following subsection pass the information 
    %   from 'Str_VA_selected'  where only countries with VA are listed
    %   to   'Str_VA_outputs'   where all possible currencies/countries
    %   are considered(with nulls for countries with no VA) 
    %   -------------------------------------------------------------------
    
    Str_VA_outputs = Str_VA_selected;
    
    Str_VA_outputs.C1C_countries = config.RFR_Str_lists.C2D_list_curncy(:,col_ISO3166);
    
    Str_VA_outputs.M2D_weights = zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1), 2);
    
    Str_VA_outputs.Govts.M2D_govts_portfolio = ...        
               zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1),...
                      length(Str_VA_outputs.Govts.C1R_govts_issuers));
    
    Str_VA_outputs.Govts.M2D_govts_durations = ...        
               zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1),...
                      length(Str_VA_outputs.Govts.C1R_govts_issuers));
        
    Str_VA_outputs.Corps.M2D_corps_portfolio = ...        
               zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1),...
                      length(Str_VA_outputs.Corps.C1R_corps_issuers));
    
    Str_VA_outputs.Corps.M2D_corps_durations = ...        
               zeros(size(config.RFR_Str_lists.C2D_list_curncy, 1),...
                      length(Str_VA_outputs.Corps.C1R_corps_issuers));



    %	in each run of the following loop, the elements created above
    %   received in the row(k) the information of insurance market data
    %	corrsponding to the country/currency with such row(k)
    %   in the general list of countries/currencies contained
    %   in the structure 'RFR_Str_lists.C2D_list_curncy'
  
                  
    for k = 1:size(config.RFR_Str_lists.C2D_list_curncy, 1)
        

        id_country = Str_VA_outputs.C1C_countries{k};
        

        row_in_selected = find(strcmp(id_country, ...
                                   Str_VA_selected.C1C_countries));

	   %  'row_in_selected'  identifies the row that contains
 	   %  insurance market data in the structure  'Str_VA_selected'
	   %  corresponding to the country/currency that has the row(k)
	   %  in the structure  'RFR_Str_lists.C2D_list_curncy'

        if isempty(row_in_selected)
           continue
	   %  for this currency there is no insurance market data
 	   %  in the structure   'Str_VA_selected'
 
        end

        Str_VA_outputs.M2D_weights(k, :) = ...
                    Str_VA_selected.M2D_weights(row_in_selected, :);
    
        Str_VA_outputs.Govts.M2D_govts_portfolio(k,:) = ...
        Str_VA_selected.Govts.M2D_govts_portfolio(row_in_selected, :);

        Str_VA_outputs.Govts.M2D_govts_durations(k,:) = ...        
        Str_VA_selected.Govts.M2D_govts_durations(row_in_selected, :);
        
        Str_VA_outputs.Corps.M2D_corps_portfolio(k,:) = ...        
        Str_VA_selected.Corps.M2D_corps_portfolio(row_in_selected, :);
    
        Str_VA_outputs.Corps.M2D_corps_durations(k,:) = ...        
        Str_VA_selected.Corps.M2D_corps_durations(row_in_selected, :);
                                     
    end
    
    clear Str_VA_selected
    
             
   
%   =======================================================================
%%  4. Selection of the set of default statistics for the calculation of VA   
%   =======================================================================


    %   Selecting the relevant set according to date of calculation
    %   ----------------------------------------------------------------
    
    %   Default statistics(mainly transition matrices) for different dates
    %   are stored in MatLab structure  'Str_PD_CoD'
    %   Data for each date(e.g. 31_12_2011, 31_12_2013,...)
    %   are stored in an element of the structure named  'DS_yyyymmdd'
    %       for example   Str_PD_CoD.DS_20131231
   
    %   Within the MatLab structure Str_PD_CoD'
    %   there is a 2-dimensional matrix   'M2D_PD_CoD_dates'
    %   Matrix  M2D_VA_dates contains two columns
    %       first column: dates of reference of the available VA data sets
    %       second column: first date of application of each data set
    %          (i.e. data set referred to 20131231 might not be applicable
    %            to calculations before 20140630)
    %
    %  The date used for the comparison is based on the reference date.
    
            
    row_date_to_use = find(config.refDate >= M2D_PD_CoD_dates(:, 2), 1, 'last');    
        %   identification of the row of the second column 'M2D_VA_dates'
        %   that gives the date of reference to use(date in first column)
        
    date_to_use = datestr(M2D_PD_CoD_dates(row_date_to_use, 1), 'yyyymmdd');
        %   identification of date of the set of default statistics
        %   -transition matrices- regarding the VA to use(first column)
           
   Str_PD_CoD_calc = Str_PD_CoD.(strcat('DS_', date_to_use));
        %   from now on, market transition matrices - default statistics 
        %   are in MatLab structure named   'Str_PD_CoD_calc'
 
        
    
    
%   =======================================================================
%%  5. Steps of the process of calculation of the Volatility Adjustment   
%   =======================================================================

    msg_headline = strcat(type_VA, '_volatility adjustment');
        %   this should be out of the following 'if'
    

    if isempty(Str_LTAS)

    
    %   ===================================================================
    %%  5.1. Calculation of LTAS for government bonds   
    %   ===================================================================
        
        Str_LTAS = RFR_08A_LTAS_Govts ... 
                        (config, date_calc, Str_VA_outputs);
                     

    %   ===============================================================
    %%  5.2. Calculation of LTAS for corporate bonds   
    %   ===============================================================

       Str_LTAS = RFR_08B_LTAS_Corps_00_main(config,...
           date_calc, Str_LTAS, k_factor);

            %   Before this function the MatLab structure  'Str_LTAS' only
            %   contains LTAS for government bonds(in element 'Govts')
            %   After this function the MatLab structure  'Str_LTAS' 
            %   ALSO contains LTAS for corporate bonds(in element 'Corps')
            %   i.e. the output contains now two elements, 'Govts' and 'Corps'


    %   ===================================================================
    %%  5.3. Calculation of average historical spread basic RFR versus Euro   
    %   ===================================================================

        [Str_LTAS] = RFR_08C_LTAS_Basic_RFR(config, ...
            date_calc, Str_LTAS);

            %   Before this function the MatLab structure  'Str_LTAS' 
            %   contains LTAS for government bonds(in element 'Govts')
            %   and for corporate bonds(in element 'Corps').

            %   After this function the MatLab structure  'Str_LTAS' 
            %   ALSO contains long term average spreads of the basic RFR
            %   compared to the Euro in element 'Basic'
            %   i.e. the output has three elements, 'Govts', 'Corps', 'Basic'

        
        
    end
    
%   =======================================================================
%%  5.4. Calculation of internal effective rates for government bonds
%   =======================================================================

%   These instructions is only for backtestin when the LTAS
%   are frozen. It is coupled with the corresponding instructions 
%   at the beginning of the funciton
%           date_calc = date_calc_real ;

    Str_VA_outputs = RFR_08D_VA_Govts ...
                   (config, date_calc, ...
                      ER_no_VA, Str_VA_outputs, type_VA, Str_LTAS);
        
        %   Before this function the MatLab structure  'Str_VA_outputs' 
        %   ONLY contains insurance market data for the calculation of VA.
            
        %   After this function the MatLab structure  'Str_VA_outputs' 
        %   ALSO contains a detailed breakdown of the intermediate results
        %   previous to the calculation of the VA for government bonds
        
        
%   =======================================================================
%%  5.4. Calculation of internal effective rates for corporate bonds
%   =======================================================================

    [Str_VA_outputs,Str_PD_CoD_outputs] = RFR_08E_VA_Corps(config, date_calc,...
                                  ER_no_VA, Str_VA_outputs , type_VA,...
                                  Str_LTAS, Str_PD_CoD_calc, k_factor);

   
%   =======================================================================
%%  6. Saving the workspace
%   =======================================================================

    save(fullfile(config.RFR_Str_config.folders.path_RFR_99_Workspace, ...
                        'RFR_08A_VA_MA_main_function'))
end