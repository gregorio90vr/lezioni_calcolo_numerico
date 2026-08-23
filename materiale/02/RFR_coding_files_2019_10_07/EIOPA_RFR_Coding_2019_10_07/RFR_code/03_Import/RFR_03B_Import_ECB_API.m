function [V1C_ECB_dates,M2D_ECB_rates] = RFR_03B_Import_ECB_API(config)
%RFR_03B_IMPORT_ECB_API Imports the ECB all euro area spots through SDMX.

    % Downloads the ECB all euro area zero coupon spot rates for integer
    % maturities through usage of the RESTFUL SDW API in JSON format.
    % Converts them to the RFR project format.
    %
    % The ECB API website can be found at:
    % https://sdw-wsrest.ecb.europa.eu/
    %
    % YC/B.U2.EUR.4F.G_N_C.SV_C_YM.SR_12Y 

    % ECB SDW URL for the yield curves
    url = 'http://sdw-wsrest.ecb.europa.eu/service/data/YC/';

    % Select the start and end date
    startDate = datetime(2004, 9, 6, 'Format', 'yyyy-MM-dd');
    % endDate = datetime('today', 'Format', 'yyyy-MM-dd');
    endDate = datetime(config.refDate, 'ConvertFrom', 'datenum', ...
        'Format', 'yyyy-MM-dd');
    
    % Integer maturities to download
    maturities = 1:30;

    % Generate the selector string for spot rates (i.e. SR_1Y+SR_2Y+...)
    maturities = [num2str(maturities') repmat('Y', size(maturities,2), 1)];
    maturities = cellstr(maturities);
    maturities = cellfun(@(x) ['SR_' strtrim(x)], maturities, 'UniformOutput', false);
%     maturities = strjoin(maturities, '+');

    rates = {};
    
    webOpt = weboptions('ContentType', 'text', 'Timeout', 60,...
            'KeyName', 'Accept', 'KeyValue', ...
            'application/vnd.sdmx.data+json;version=1.0.0-wd');
        
    for i = 1:length(maturities)
        key = ['B.U2.EUR.4F.G_N_C.SV_C_YM.' maturities{i}];

        % Query the API
        try
            result = webread([url key], 'startPeriod', char(startDate), ...
                'endPeriod', char(endDate), 'includeHistory', 'false', webOpt);
        catch ME
            info_message = 'Couldn''t connect to the ECB API. Aborting...';            

            RFR_log_register('01_Import', '03B_Download', 'ERROR',...
                info_message, config);
            return
        end

        result = jsondecode(result);

        % We are interested in the order of the maturities of the returned dataset.
        % Therefore, we have to extract and parse the series ids.
        datatypeIdx = find(cellfun(@(x) strcmp(x, 'DATA_TYPE_FM'),...
            {result.structure.dimensions.series.id}),1);

        datatypes = {result.structure.dimensions.series(datatypeIdx).values.id};
        returnMaturities = regexp(datatypes, 'SR_(\d+)Y', 'tokens');
        returnMaturities = [returnMaturities{:}];
        returnMaturities = str2double([returnMaturities{:}]);

        dataseries = fieldnames(result.dataSets.series);
%         [~,matInd] = ismember(1:30,returnMaturities);
%         dataseries = dataseries(matInd);

        % Get the rounding
        structureFields = {result.structure.attributes.series(:).id};
        decField = strcmp(structureFields, 'DECIMALS');

        decimals = str2double(...
            result.structure.attributes.series(decField).values.id);

        % Extract the rates
        for mat=1:length(dataseries)
            data = structfun(@(x) round(x(1), decimals),...
                result.dataSets.series.(dataseries{mat}).observations,...
                'UniformOutput', true);

            dates = datenum({result.structure.dimensions.observation.values.id}, ...
        'yyyy-mm-dd');
            
            % Sort the dates in ascending order and do the same to the
            % rates then.
            [dates,ord] = sort(dates);
            data = data(ord);
            
            rates = [rates,data];
        end
    end
    
    M2D_ECB_rates = [rates{:}];
    M2D_ECB_rates = 100 * exp(M2D_ECB_rates/100) - 100;

    % Extract the dates
    V1C_ECB_dates =  datenum({result.structure.dimensions.observation.values.id}, ...
        'yyyy-mm-dd');

    
end