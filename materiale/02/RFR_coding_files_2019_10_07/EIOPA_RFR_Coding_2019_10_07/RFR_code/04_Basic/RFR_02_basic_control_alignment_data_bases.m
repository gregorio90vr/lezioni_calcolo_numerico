function aligned = ...
             RFR_02_basic_control_alignment_data_bases(config,...
             checks)

    
%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------
%
%       Before running the calculations, this function controls that
%       all historical databases used in the calculation have 
%       the same vector of dates observed
%
%       The function does NOT control the observed market data at each date
%

    % If no argument for the checks was supplied, check the alignment of
    % all stored rates.
    if nargin < 2
        checks = {'GVT','SWP','OIS','CRA','CORP','DKK','RFR'};
    end

    aligned = true;

%   -----------------------------------------------------------------------
%%  1. Loading configuration and historical data on interest rates for CRA
%   -----------------------------------------------------------------------        

    %   1.1. Loading to workspace the configuration data
    %   ------------------------------------------------    
    
    folder_download = config.RFR_Str_config.folders.path_RFR_01_Config; 
    file_download = 'EIOPA_RFR_config';       

    load(fullfile(folder_download, file_download));
    
    %   Loading to workspace market historical data from financial markets
    %   ------------------------------------------------------------------
        
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;
    
    file_mat_storage = {'RFR_basic_curves','RFR_CRA','Str_Corporates'};
    
    for file=file_mat_storage
        load(fullfile(folder_download, file{1}));
    end
    
    %   1.3. Loading to workspace the history of basic risk-free curves
    %   -------------------------------------------------------------------  
    
    folder_download = config.RFR_Str_config.folders.path_RFR_05_LTAS;
    
    file_download = 'Str_History_basic_RFR';   
    
        %   Name of the MatLab structure with the historical
        %   series of basic risk-free interest rates
        %   (all extrapolated for each date and currency with S-W method)
        %   Each serie is a M2D matrix with 61 columns
        %       First column contains the dates
        %       Columns 2 to 61 are rates observed for maturities 1 to 60

	%   This structure is generated with a batch process
	%   with the function  'VA_History_basic_RFR_batch.m'

    load(fullfile(folder_download, file_download));


%   -----------------------------------------------------------------------
%%  2. Defining the benchmark (Euroswap history) and comparing 
%   -----------------------------------------------------------------------        
    
    V1C_dates_benchmark = RFR_download_BBL_Mid.EUR_RAW_SWP_BBL(:,1);

    
    %   2.1. Control of dates for swap, government and OIS databases
    %   ------------------------------------------------------------
    classes = intersect({'GVT','SWP','OIS'}, checks);
    
    if ~isempty(classes)
        C1C_names = fieldnames(RFR_download_BBL_Mid);

        for k = 1:length(C1C_names)
            if isempty(regexp(C1C_names{k}, strjoin(classes, '|'), 'once'))
                continue;
            end
            
            V1C_to_test = RFR_download_BBL_Mid.(C1C_names{k})(:,1);

            if ~isequal(V1C_dates_benchmark, V1C_to_test)
                info = ['Control alignment dates failed for RFR_download_BBL_Mid.', C1C_names{k}, '.']; 
                RFR_log_register('00_Basic', 'RFR_02_alignment', 'WARNING',...
                    info, config); 
                
                aligned = false;
            end
        end
    end
    
        
    %   2.2. Control of dates for credit risk adjustment
    %   ------------------------------------------------
    if ismember('CRA', checks)    
        if ~isequal(V1C_dates_benchmark, M3D_CRA_BBL(:,1,1)) || ...
           ~isequal(V1C_dates_benchmark, M3D_CRA_BBL(:,1,2))  

            info = ['Control alignment dates failed for the 3-D matrix with CRA market data']; 
            RFR_log_register('00_Basic', 'RFR_02_alignment', 'WARNING',...
                info, config);     

                            
            aligned = false;
        end
    end
    
    %   2.3. Control of dates for iBoxx databases of corporate bonds
    %   ------------------------------------------------------------
    
    if ismember('CORP', checks)
        C1C_names = fieldnames(Str_Corporates_iBoxx_Bid);

        for k = 1:length(C1C_names)

            V1C_to_test = Str_Corporates_iBoxx_Bid.(C1C_names{k})(:,1);

            if ~isequal(V1C_dates_benchmark, V1C_to_test)

                info = ['Control alignment dates failed for Str_Corporates_iBoxx_Bid.', C1C_names{k}, '.']; 
                RFR_log_register('00_Basic', 'RFR_02_alignment', 'WARNING', ...
                    info, config);     

                aligned = false;
            end   
        end
    end
    
        
    %   2.4. Control of dates for Danish Nykredit index
    %   ------------------------------------------------
    
    if ismember('DKK', checks)
        V1C_to_test = DKK_Nykredit.M2D_DKK_Nykredit(:,1);

        if ~isequal(V1C_dates_benchmark, V1C_to_test)

            info = 'Control alignment dates failed for DKK_Nykredit.'; 
            RFR_log_register('00_Basic', 'RFR_02_alignment', 'WARNING', ...
                info, config);  
            
            aligned = false;
        end
    end

    
    %   2.5. Control of dates for basic risk-free curves
    %   ------------------------------------------------
    
    if ismember('RFR', checks)
        C1C_names = fieldnames(Str_History_basic_RFR);

        for k =1:length(C1C_names)
            V1C_to_test = Str_History_basic_RFR.(C1C_names{k})(:,1);

            if ~isequal(V1C_dates_benchmark, V1C_to_test)

                info = ['Control alignment dates failed for Str_History_Basic_RFR.', C1C_names{k}, '.']; 
                RFR_log_register('00_Basic', 'RFR_02_alignment', 'WARNING',...
                    info, config); 
                
                aligned = false;
            end
        end
    end 
end   % of the function