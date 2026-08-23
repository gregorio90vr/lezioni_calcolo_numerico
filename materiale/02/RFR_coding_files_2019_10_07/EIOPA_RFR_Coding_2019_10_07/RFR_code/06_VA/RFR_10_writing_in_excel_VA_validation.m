function RFR_10_writing_in_excel_VA_validation ...
                       (ER_no_VA, Str_VA_Currency, Str_VA_National,...
                          Str_LTAS, config)
              

%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------

    %   This function writes in four excel files the outputs of
    %   the intermediate calculations for the currency VA and country VA
    
    %   RFR_VA_currency_Govts_test_file.xlsb
    %   RFR_VA_national_Govts_test_file.xlsb
    %   RFR_VA_currency_Corps_test_file.xlsb
    %   RFR_VA_national_Corps_test_file.xlsb
    
%  ------------------------------------------------------------------------
%  ------------------------------------------------------------------------



%  ========================================================================
%%  1. Loading variables common to the following steps within this function
%  ========================================================================

    
    col_ISO4217 = config.RFR_Str_lists.Str_numcol_curncy.ISO4217;
        %   number of the column in cell array
        %   config.RFR_Str_lists.C2D_list_curncy containing ISO4217
        %   for each of the currencies considered


%  ========================================================================
%%  1. Writing excel file referred to central government bonds VA Currency
%  ========================================================================

    
    file_output = fullfile(config.RFR_Str_config.folders.path_RFR_06_VA, ...
                          'RFR_VA_currency_Govts_test_file.xlsb');     

    num_writings = 21; 
    
    sheet_output = cell(num_writings, 1);
    data_output  = cell(num_writings, 1);
    range_output = cell(num_writings, 1);
    
    counter = 0;

    
    %   -------------------------------------------------------------------
    %%  1.1. Worksheet  'VA_Weights'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_Weights';
        
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 1, size(aux,1), size(aux,2));
                
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.C1C_countries;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));
               
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.M2D_weights;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                                                   
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Govts.M2D_govts_IER;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 6, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(:,col_ISO4217);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 10, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = ER_no_VA.M2D_SW_spot_rates(:,1:30);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 11, size(aux,1), size(aux,2));

    
    %   -------------------------------------------------------------------
    %%  1.2.  Worksheet  'VA_C_Govts_Comp'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Govts_Comp';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Govts.C1R_govts_issuers;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Govts.M2D_govts_portfolio;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  1.3.  Worksheet  'VA_C_Govts_Dur'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Govts_Dur';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Govts.M2D_govts_durations;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  1.4. Worksheet  'LTAS_Govts'
    %   -------------------------------------------------------------------
    
    name_sheet = 'LTAS_Govts';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(:, 1:30);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  1.5. Worksheet  'VA_C_Govts_Yield_before'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Govts_Yield_before';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Govts.M2D_govts_yield_b;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  1.6. Worksheet  'VA_C_Govts_Risk_correction'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Govts_Risk_correction';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Govts.M2D_govts_fs;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  1.7. Worksheet  'VA_C_Govts_Yield_after'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Govts_Yield_after';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Govts.M2D_govts_yield_a;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  1.8. Worksheet  'VA_C_Govts_RFR'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Govts_RFR';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Govts.M2D_govts_rfr;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  1.9. Worksheet  'VA_C_Govts_RFR'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_Currency_Govts_EUR_Duration';
    
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_Currency.ECB;
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(12, 3, size(aux,1), size(aux,2));
                    
    text_waitbar = 'Writing in excel info Central Government bonds VA Currency';
   
    xlswrite_mult_msg(file_output, data_output, sheet_output, range_output, text_waitbar);




%  ========================================================================
%%  2. Writing excel file referred to central government bonds VA National
%  ========================================================================
    
    
    file_output = fullfile(config.RFR_Str_config.folders.path_RFR_06_VA, ...
                          'RFR_VA_national_Govts_test_file.xlsb');     

    num_writings = 21; 
    
    sheet_output = cell(num_writings, 1);
    data_output  = cell(num_writings, 1);
    range_output = cell(num_writings, 1);
    
    counter = 0;
    %   -------------------------------------------------------------------
    %%  2.1. Worksheet  'VA_Weights'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_Weights';
        
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 1, size(aux,1), size(aux,2));
                
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.C1C_countries;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));
               
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.M2D_weights;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                                                                            
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Govts.M2D_govts_IER;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 6, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(:, col_ISO4217);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 10, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = ER_no_VA.M2D_SW_spot_rates(:, 1:30);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 11, size(aux,1), size(aux,2));

    
    %   -------------------------------------------------------------------
    %%  2.2.  Worksheet  'VA_N_Govts_Comp'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Govts_Comp';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Govts.C1R_govts_issuers;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Govts.M2D_govts_portfolio;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  2.3.  Worksheet  'VA_N_Govts_Dur'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Govts_Dur';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Govts.M2D_govts_durations;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  2.4. Worksheet  'LTAS_Govts'
    %   -------------------------------------------------------------------
    
    name_sheet = 'LTAS_Govts';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_LTAS.Govts.M2D_govts_LTAS_spreads_rec(:, 1:30);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  2.5. Worksheet  'VA_N_Govts_Yield_before'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Govts_Yield_before';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Govts.M2D_govts_yield_b;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  2.6. Worksheet  'VA_N_Govts_Risk_correction'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Govts_Risk_correction';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Govts.M2D_govts_fs;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  2.7. Worksheet  'VA_N_Govts_Yield_after'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Govts_Yield_after';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Govts.M2D_govts_yield_a;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  2.8. Worksheet  'VA_N_Govts_RFR'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Govts_RFR';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Govts.M2D_govts_rfr;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    
    text_waitbar = 'Writing to Excel the Central Government bonds VA National information';
   
    xlswrite_mult_msg(file_output , data_output  , sheet_output  , range_output, text_waitbar);

    
    
    
%  ========================================================================
%%  3. Writing excel file referred to corporate bonds VA Currency
%  ========================================================================

    
    file_output = fullfile(config.RFR_Str_config.folders.path_RFR_06_VA, ...
                          'RFR_VA_currency_Corps_test_file.xlsb');     

    num_writings = 23; 
    
    sheet_output = cell(num_writings, 1);
    data_output  = cell(num_writings, 1);
    range_output = cell(num_writings, 1);
    
    counter = 0;

    
    %   -------------------------------------------------------------------
    %%  3.1. Worksheet  'VA_Weights'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_Weights';
        
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 1, size(aux,1), size(aux,2));
                
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.C1C_countries;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));
               
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.M2D_weights;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                                                  
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Corps.M2D_corps_IER;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 6, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(:, col_ISO4217);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 10, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = ER_no_VA.M2D_SW_spot_rates(:, 1:30);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 11, size(aux,1), size(aux,2));

    
    %   -------------------------------------------------------------------
    %%  3.2.  Worksheet  'VA_C_Corps_Comp'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Corps_Comp';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Corps.C1R_corps_issuers; %     Str_VA_Currency.Corps.C1R_corps_issuers
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Corps.M2D_corps_portfolio;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  3.3.  Worksheet  'VA_C_Corps_Dur'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Corps_Dur';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Corps.M2D_corps_durations;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  3.4. Worksheet  'LTAS_Corps'
    %   -------------------------------------------------------------------
    
    name_sheet = 'LTAS_Corps';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(:, 1:30);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  3.5. Worksheet  'LTAS_Basic_RFR'
    %   -------------------------------------------------------------------
    
    name_sheet = 'LTAS_Basic_RFR';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = real(Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread(:, 1:30));
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  3.6. Worksheet  'VA_C_Corps_Yield_before'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Corps_Yield_before';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Corps.M2D_corps_yield_b;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  3.7. Worksheet  'VA_C_Corps_Risk_correction'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Corps_Risk_correction';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Corps.M2D_corps_fs;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  3.8. Worksheet  'VA_C_Corps_Yield_after'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Corps_Yield_after';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Corps.M2D_corps_yield_a;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  3.9. Worksheet  'VA_C_Corps_RFR'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_C_Corps_RFR';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.Corps.M2D_corps_rfr;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    text_waitbar = 'Writing to Excel the Corporate bond information';
   
    xlswrite_mult_msg(file_output , data_output  , sheet_output  , range_output, text_waitbar);
    
 
    
%  ========================================================================
%%  4. Writing excel file referred to corporate bonds VA National
%  ========================================================================

    
    file_output = fullfile(config.RFR_Str_config.folders.path_RFR_06_VA, ...
                          'RFR_VA_national_Corps_test_file.xlsb');     

    num_writings = 23; 
    
    sheet_output = cell(num_writings, 1);
    data_output  = cell(num_writings, 1);
    range_output = cell(num_writings, 1);
    
    counter = 0;

    
    %   -------------------------------------------------------------------
    %%  4.1. Worksheet  'VA_Weights'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_Weights';
        
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 1, size(aux,1), size(aux,2));
                
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_Currency.C1C_countries;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 2, size(aux,1), size(aux,2));
               
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.M2D_weights;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                                                  
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Corps.M2D_corps_IER;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 6, size(aux,1), size(aux,2));
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = config.RFR_Str_lists.C2D_list_curncy(:, col_ISO4217);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 10, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = ER_no_VA.M2D_SW_spot_rates(:, 1:30);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 11, size(aux,1), size(aux,2));

    
    %   -------------------------------------------------------------------
    %%  4.2.  Worksheet  'VA_N_Corps_Comp'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Corps_Comp';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Corps.C1R_corps_issuers; %     Str_VA_Currency.Corps.C1R_corps_issuers
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(10, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Corps.M2D_corps_portfolio;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  4.3.  Worksheet  'VA_N_Corps_Dur'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Corps_Dur';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));

    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Corps.M2D_corps_durations;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  4.4. Worksheet  'LTAS_Corps'
    %   -------------------------------------------------------------------
    
    name_sheet = 'LTAS_Corps';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_LTAS.Corps.M2D_corps_LTAS_spreads_rec(:, 1:30);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  4.5. Worksheet  'LTAS_Basic_RFR'
    %   -------------------------------------------------------------------
    
    name_sheet = 'LTAS_Basic_RFR';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = real(Str_LTAS.Basic.M2D_LTAS_basic_RFR_to_euro_spread(:, 1:30));
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  4.6. Worksheet  'VA_N_Corps_Yield_before'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Corps_Yield_before';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Corps.M2D_corps_yield_b;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  4.7. Worksheet  'VA_N_Corps_Risk_correction'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Corps_Risk_correction';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Corps.M2D_corps_fs;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  4.8. Worksheet  'VA_N_Corps_Yield_after'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Corps_Yield_after';
    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = cell(100, 100);
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output {counter} = name_sheet;
    aux = Str_VA_National.Corps.M2D_corps_yield_a;
    data_output  {counter} = aux;
    range_output {counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    
    %   -------------------------------------------------------------------
    %%  4.9. Worksheet  'VA_N_Corps_RFR'
    %   -------------------------------------------------------------------
    
    name_sheet = 'VA_N_Corps_RFR';
    
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = cell(100, 100);
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
                    
    counter = counter + 1;
    sheet_output{counter} = name_sheet;
    aux = Str_VA_National.Corps.M2D_corps_rfr;
    data_output{counter} = aux;
    range_output{counter} = calcexcelrange(11, 3, size(aux,1), size(aux,2));
    
    text_waitbar = 'Writing to Excel the Corporate bond information';
   
    xlswrite_mult_msg(file_output, data_output, sheet_output, range_output, text_waitbar);

end