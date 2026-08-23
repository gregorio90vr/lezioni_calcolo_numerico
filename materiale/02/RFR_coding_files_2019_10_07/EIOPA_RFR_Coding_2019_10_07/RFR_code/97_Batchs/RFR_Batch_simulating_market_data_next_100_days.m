

function  RFR_Batch_simulating_market_data_next_100_days 


%%  EXPLANATION OF THIS FUNCTION
%   -----------------------------------------------------------------------

%   This function simulates future dates for all market databases
%   (except swap bid-ask spreads for the time being)

%   The future dates are read from the excel file 
%       RFR_simulation_dates_next_100_days.xlsx

%   Before running this function, introduce the right date in cell D8
%   of the aforementioned excel file.

%   Remember that this function and the excel file above should be
%   in a path included in the set path

%   ¡¡ CAUTION: HARD DISK FILES WITH MARKET DATA BASES WILL BE MODIFIED !!

        
%  ========================================================================
%%  1. Previous load of necessary variables in workspace
%  ========================================================================

%    These two lines below are necessary only to run the function stand
%     alone

    RFR_config_mat_file = RFR_01_basic_setting_config ;


    load ( RFR_config_mat_file )


    col_ISO3166 = RFR_Str_lists.Str_numcol_curncy.ISO3166 ;
%   col_ISO4217 = RFR_Str_lists.Str_numcol_curncy.ISO4217 ;
    
        %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing ISO3166 and ISO4217
        %   for each of the currencies / countries considered

    
    load(fullfile(RFR_Str_config.folders.path_RFR_02_Downloads, ...
                        'RFR_basic_curves' ) )
    
    load(fullfile(RFR_Str_config.folders.path_RFR_02_Downloads, ...
                        'RFR_CRA'))
                        
%    load ( strcat( RFR_Str_config.folders.path_RFR_02_Downloads , ...
%                        '\' , 'RFR_basic_curves_Bid_Ask' ) )
    
    load(strcat(RFR_Str_config.folders.path_RFR_02_Downloads, ...
                        'Str_Corporates'))
    
    load(strcat( RFR_Str_config.folders.path_RFR_05_LTAS , ...
                        'Str_History_basic_RFR'))
                    
                    
  
    
%  ========================================================================
%%  2. Creating variables to use in the following sections
%  ========================================================================
        
    
    [ VecCol_simulated_dates , ~ ] = ...
            xlsread( 'RFR_simulation_dates_next_100_days.xlsx' , ...
                     'simulated_dates' , 'C8:C107' ) ;
  
       %    see explanations at the beginning of thi function
       
       
    V1C_countries_codes = RFR_Str_lists.C2D_list_curncy ( : , col_ISO3166 ) ;

    num_countries = size ( RFR_Str_lists.C2D_list_curncy , 1 ) ; 


  
    
%  ========================================================================
%%  3. Loop for swaps curves
%  ========================================================================

    for run_country = 1 : 1 : num_countries
                
        if run_country > 1  && strcmp('EUR', V1C_countries_codes(run_country))
            % no action for the concrete countries of Euro area
            % only first run calculation for the Euro as a whole 
            continue
        end
        
        name_curve = strcat(V1C_countries_codes{run_country}, ...
                             '_RAW_SWP_BBL');

        if ~strcmp(fieldnames(RFR_download_BBL_Mid), name_curve)
            
            %   there is no swap database for the currency of this run
            continue
        end
        
        M2D_download = RFR_download_BBL_Mid.(name_curve);
                 

        %   repeating last 100 rows and adding at the end of the file
        
        M2D_download = [ M2D_download ; ...
                         M2D_download( end-99:end , : ) ] ;
   
                     
        %   replacing last 100 dates with the new future simulated dates
        
        M2D_download( end-99 : end , 1 ) = VecCol_simulated_dates ;

        
        %   saving in MatLab structure the database for the currency 
        %   of this run once added the future simulated data
        
        RFR_download_BBL_Mid.(name_curve) = M2D_download;
                             
                       
    end     % this refers to the loop for each currency
 

    
        
%  ========================================================================
%%  4. Loop for government curves
%  ========================================================================
    
    for run_country = 1:num_countries
                
        
        name_curve = strcat(V1C_countries_codes{ run_country } , ...
                             '_RAW_GVT_BBL' ) ;

        if ~strcmp(fieldnames( RFR_download_BBL_Mid), name_curve)
            
            %  there is no govt bond database for the currency of this run
            continue
        end
        
        M2D_download = RFR_download_BBL_Mid.(name_curve);

         %   repeating last 100 rows and adding at the end of the file
        
        M2D_download = [ M2D_download ; ...
                         M2D_download( end-99:end , : ) ] ;
   
                     
        %   replacing last 100 dates with the new future simulated dates
        
        M2D_download( end-99 : end , 1 ) = VecCol_simulated_dates ;

        
        %   saving in MatLab structure the database for the currency 
        %   of this run once added the future simulated data
        
       RFR_download_BBL_Mid.(name_curve) = M2D_download; 
                             
                  
    end     % this refers to the loop for each currency

 
    
    
%  ========================================================================
%%  5. Loop for overnight index swap curves
%  ========================================================================

    for run_country = 1 : 1 : num_countries
                
        if run_country > 1  && strcmp('EUR', V1C_countries_codes(run_country))
            % no action for the concrete countries of Euro area
            % only first run calculation for the Euro as a whole 
            continue
        end
        
        name_curve = strcat( V1C_countries_codes{ run_country } , ...
                             '_RAW_OIS_BBL' ) ;

        if ~strcmp(fieldnames(RFR_download_BBL_Mid), name_curve)
            
            %   there is no OIS database for the currency of this run
            continue
        end
        
        M2D_download = RFR_download_BBL_Mid.(name_curve);
                 

        %   repeating last 100 rows and adding at the end of the file
        
        M2D_download = [ M2D_download ; ...
                         M2D_download( end-99:end , : ) ] ;
   
                     
        %   replacing last 100 dates with the new future simulated dates
        
        M2D_download( end-99 : end , 1 ) = VecCol_simulated_dates ;

        
        %   saving in MatLab structure the database for the currency 
        %   of this run once added the future simulated data
        
       RFR_download_BBL_Mid.(name_curve) = M2D_download;
                             
                       
    end     % this refers to the loop for each currency
 

    
      
%  ========================================================================
%%  6. Writing in the hard disk
%  ========================================================================
  
    
    folder_download = RFR_Str_config.folders.path_RFR_02_Downloads ;
        %   path where excel files with interest rates are stored
        %   and also the MatLab file   'RFR_basic_curves.mat'
        %   with the structure 'RFR_download_BBL'
            
    file_storage    = 'RFR_basic_curves' ;
        %   name of 'mat' file containing historical interest rates

    save(fullfile(folder_download, file_storage), 'RFR_download_BBL_Mid',...
        '-append')
                     
       
  
    
%  ========================================================================
%%  5. Loop for History of Basic RFR curves
%  ========================================================================


    for run_country = 1:num_countries
                
        if run_country > 1  && strcmp('EUR', V1C_countries_codes(run_country))
            % no action for the concrete countries of Euro area
            % only first run calculation for the Euro as a whole 
            continue
        end
        
        name_curve = strcat( V1C_countries_codes{ run_country } , ...
                             '_RFR_basic_spot' ) ;

        if ~strcmp(fieldnames(Str_History_basic_RFR), name_curve)
            
            %   there is no swap database for the currency of this run
            continue
        end
        
        M2D_download = Str_History_basic_RFR.(name_curve);
                 

        %   repeating last 100 rows and adding at the end of the file
        
        M2D_download = [ M2D_download ; ...
                         M2D_download( end-99:end , : ) ] ;
   
                     
        %   replacing last 100 dates with the new future simulated dates
        
        M2D_download( end-99 : end , 1 ) = VecCol_simulated_dates ;

        
        %   saving in MatLab structure the database for the currency 
        %   of this run once added the future simulated data
        
        Str_History_basic_RFR.(name_curve) = M2D_download;
                             
                       
    end     % this refers to the loop for each currency
 

    
    
    %   saving in the hard disk
    
    folder_download = RFR_Str_config.folders.path_RFR_05_LTAS ;
        %   path where excel files with interest rates are stored
        %   and also the MatLab file   'RFR_basic_curves.mat'
        %   with the structure 'RFR_download_BBL'
            
    file_storage    = 'Str_History_basic_RFR' ;
        %   name of 'mat' file containing historical interest rates

    save(fullfile(folder_download, file_storage), ...
                'Str_History_basic_RFR', '-append')
                  
  
    
        
%  ========================================================================
%%  6. Loop for corporate curves
%  ========================================================================

    C1C_corps_names_curves = sort(fieldnames(Str_Corporates_iBoxx_Bid));

    num_corps = length(C1C_corps_names_curves);
        
    
    for run_corps = 1:num_corps   % = length (C1C_corps_names_curves)
                
        
        name_curve = C1C_corps_names_curves { run_corps } ;
        
        M2D_download = Str_Corporates_iBoxx_Bid.(name_curve);


        %   repeating last 100 rows and adding at the end of the file
        
        M2D_download = [ M2D_download ; ...
                         M2D_download( end-99:end , : ) ] ;
   
                     
        %   replacing last 100 dates with the new future simulated dates
        
        M2D_download( end-99 : end , 1 ) = VecCol_simulated_dates ;

        
        %   saving in MatLab structure the database for the currency 
        %   of this run once added the future simulated data
        
        Str_Corporates_iBoxx_Bid.(name_curve) = M2D_download; 
                             
                                                
    end     % this refers to the loop for each currency

    
    
    %   saving in the hard disk
    
    folder_download = RFR_Str_config.folders.path_RFR_02_Downloads ;
        %   path where excel files with interest rates are stored
        %   and also the MatLab file   'RFR_basic_curves.mat'
        %   with the structure 'RFR_download_BBL'
            
    file_storage    = 'Str_Corporates' ;
        %   name of 'mat' file containing historical interest rates

    save(fullfile(folder_download, file_storage), ...
                'Str_Corporates_iBoxx_Bid', '-append')
                  
    

  
%  ========================================================================
%%  7. DKK curves
%  ========================================================================  

    DKK_Nykredit.M2D_DKK_Nykredit = ...
                   [  DKK_Nykredit.M2D_DKK_Nykredit  ; ...
                      DKK_Nykredit.M2D_DKK_Nykredit( end-99:end , : )  ] ;
                  
    DKK_Nykredit.M2D_DKK_Nykredit( end-99 : end , 1 ) = VecCol_simulated_dates ;
        
        
    %   saving in the hard disk
    
    folder_download = RFR_Str_config.folders.path_RFR_02_Downloads ;
        %   path where excel files with interest rates are stored
        %   and also the MatLab file   'RFR_basic_curves.mat'
        %   with the structure 'RFR_download_BBL'
            
    file_storage    = 'Str_Corporates' ;
        %   name of 'mat' file containing historical interest rates

    save(fullfile(folder_download, file_storage), ...
        'DKK_Nykredit', '-append');
                  

  
             
%  ========================================================================
%%  8. For CRA rates the control is done directly in the excel file
%  ========================================================================

    M3D_expanded = zeros( size( M3D_CRA_BBL, 1 ) + 100  , ... 
                          size( M3D_CRA_BBL, 2 ), ...
                          size( M3D_CRA_BBL, 3 )  )   ;
    
    M3D_expanded ( 1 : end-100 , : , : )  =  M3D_CRA_BBL ; 
    
    M3D_expanded ( end-99 : end  , : , : ) =  ...
                                M3D_CRA_BBL ( end-99 : end  , : , : ) ;     
   
    M3D_expanded( end-99 : end , 1 , 1 ) = VecCol_simulated_dates ;
    M3D_expanded( end-99 : end , 1 , 2 ) = VecCol_simulated_dates ;
                            

    M3D_CRA_BBL = M3D_expanded ; 
               
    %   saving in the hard disk
    
    folder_download = RFR_Str_config.folders.path_RFR_02_Downloads ;
        %   path where excel files with interest rates are stored
        %   and also the MatLab file   'RFR_basic_curves.mat'
        %   with the structure 'RFR_download_BBL'
            
    file_storage    = 'RFR_CRA' ;
        %   name of 'mat' file containing historical interest rates

    save(fullfile(folder_download, file_storage), ...
        'M3D_CRA_BBL', '-append')

%   -----------------------------------------------------------------------

end

