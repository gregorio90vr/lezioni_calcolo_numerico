function RFR_08_Alignment_of_the_data_bases(config)

    
%  ------------------------------------------------------------------------
%%  0. Explanation of this function
%  ------------------------------------------------------------------------
%
%       This function aligns the data arrays for the different market data
%       with the union of all available dates. 
%

    
    %   Load the market data structures into the workspace
    %   ------------------------------------------------------------------
        
    folder_download = config.RFR_Str_config.folders.path_RFR_02_Downloads;
    
    file_mat_storage = {'RFR_basic_curves','RFR_CRA','Str_Corporates'};
    
    for file=file_mat_storage
        load(fullfile(folder_download, file{1}));
    end


    %% Create the union of all date vectors
    dates = [];
    
    % GVT / SWP
    dataFields = fieldnames(RFR_download_BBL_Mid);
    
    for i=1:length(dataFields)
        if contains(dataFields{i}, 'OIS')
            continue
        end
        
        dates = union(dates, RFR_download_BBL_Mid.(dataFields{i})(:,1));
    end
    
    % CRA
    dates = union(dates, M3D_CRA_BBL(:,1));
    
    % DKK
    dates = union(dates, DKK_Nykredit.M2D_DKK_Nykredit(:,1));
    dates = union(dates, DKK_Nykredit.Duration_DKK_Nykredit(:,1));
    
    % Corporates
    dataFields = fieldnames(Str_Corporates_iBoxx_Bid);
    
    for i=1:length(dataFields)
        dates = union(dates, Str_Corporates_iBoxx_Bid.(dataFields{i})(:,1));
    end
    
    % Generate a vector with all business days between the first and last
    % date in the dates vector.
    dates = busdays(dates(1), dates(end), 'd', NaN);
    
    %% Align / extend the arrays
    
    % GVT / SWP
    dataFields = fieldnames(RFR_download_BBL_Mid);
    
    for i=1:length(dataFields)
        if contains(dataFields{i}, 'OIS')
            continue
        end
        
        marketData = RFR_download_BBL_Mid.(dataFields{i});
        
        if ~isequal(dates, marketData(:,1))
            info = [dataFields{i}, ... 
                    ': Not aligned with the other data arrays. Extending...'];
                                                 
            RFR_log_register('03_Import', 'RFR_08_Alignment_of_the_data_bases',...
                'WARNING', info, config);
                    
            newDates = setdiff(dates, ...
                marketData(:,1));
            
            extension = zeros(length(newDates), size(marketData, 2));
            extension(:,1) = newDates;
            
            marketData = sortrows([marketData;extension]); 
            RFR_download_BBL_Mid.(dataFields{i}) = marketData;
        end
    end
    
    % CRA
    marketData = M3D_CRA_BBL;
    
    % Implicit assumption that IBOR / OIS are already aligned
    if ~isequal(dates, marketData(:,1,1))
        info = ['M3D_CRA_BBL', ... 
                ': Not aligned with the other data arrays. Extending...'];
                                                 
        RFR_log_register('03_Import', 'RFR_08_Alignment_of_the_data_bases',...
            'WARNING', info, config);
        
        newDates = setdiff(dates, ...
            marketData(:,1,1));

        extension = zeros(length(newDates), size(marketData, 2), ...
            size(marketData, 3));
        extension(:,1,1) = newDates;
        extension(:,1,2) = newDates;

        marketData = [marketData;extension]; 
        marketData(:,:,1) = sortrows(marketData(:,:,1));
        marketData(:,:,2) = sortrows(marketData(:,:,2));

        M3D_CRA_BBL = marketData;
    end
        
    % DKK
    % 1. Yields
    marketData = DKK_Nykredit.M2D_DKK_Nykredit;
    
    if ~isequal(dates, marketData(:,1))
        info = ['DKK_Nykredit.M2D_DKK_Nykredit', ... 
                    ': Not aligned with the other data arrays. Extending...'];
                                                 
        RFR_log_register('03_Import', 'RFR_08_Alignment_of_the_data_bases',...
            'WARNING', info, config);
            
            newDates = setdiff(dates, ...
                marketData(:,1));
            
            extension = zeros(length(newDates), size(marketData, 2));
            extension(:,1) = newDates;
            
            marketData = sortrows([marketData;extension]); 
            DKK_Nykredit.M2D_DKK_Nykredit = marketData;
    end
    
    % 2. Durations
    marketData = DKK_Nykredit.Duration_DKK_Nykredit;
    
    if ~isequal(dates, marketData(:,1))
        info = ['DKK_Nykredit.Duration_DKK_Nykredit', ... 
                    ': Not aligned with the other data arrays. Extending...'];
                                                 
        RFR_log_register('03_Import', 'RFR_08_Alignment_of_the_data_bases',...
            'WARNING', info, config);
            
            newDates = setdiff(dates, ...
                marketData(:,1));
            
            extension = zeros(length(newDates), size(marketData, 2));
            extension(:,1) = newDates;
            
            marketData = sortrows([marketData;extension]); 
            DKK_Nykredit.Duration_DKK_Nykredit = marketData;
    end
        
    % Corporates
    dataFields = fieldnames(Str_Corporates_iBoxx_Bid);
    
    for i=1:length(dataFields)

        marketData = Str_Corporates_iBoxx_Bid.(dataFields{i});
        
        if ~isequal(dates, marketData(:,1))
            info = [dataFields{i}, ... 
                    ': Not aligned with the other data arrays. Extending...'];
                                                 
            RFR_log_register('03_Import', 'RFR_08_Alignment_of_the_data_bases',...
                'WARNING', info, config);
            
            newDates = setdiff(dates, ...
                marketData(:,1));
            
            extension = zeros(length(newDates), size(marketData, 2));
            extension(:,1) = newDates;
            
            marketData = sortrows([marketData;extension]); 
            Str_Corporates_iBoxx_Bid.(dataFields{i}) = marketData;
        end
    end
    
    save(fullfile(folder_download, 'RFR_basic_curves'), ...
        'RFR_download_BBL_Mid', '-append')
    save(fullfile(folder_download, 'RFR_CRA'), 'M3D_CRA_BBL', '-append');
    save(fullfile(folder_download, 'Str_Corporates'), 'DKK_Nykredit', '-append');
    save(fullfile(folder_download, 'Str_Corporates'), ...
      'Str_Corporates_iBoxx_Bid', '-append');

end   % of the function