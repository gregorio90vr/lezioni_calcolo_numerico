function errors = RFR_08_validation(config, ER_no_VA)
%RFR_08_VALIDATION Validate that rates at DLT points are almost eq. to the
%input data.

    % Calculated rates and input data should be eq. up to an error of the
    % THRESHOLD constant
    THRESHOLD = 1E-6;
    
    errors = {};
    
    % Set up of the configuration data
    col_SWP_GVT = config.RFR_Str_lists.Str_numcol_curncy.SWP_GVT;
    col_LLP_GVT = config.RFR_Str_lists.Str_numcol_curncy.LLP_GVT;
    col_LLP_SWP = config.RFR_Str_lists.Str_numcol_curncy.LLP_SWP;
    col_name_country = config.RFR_Str_lists.Str_numcol_curncy.name_country;
    
    countries = config.RFR_Str_lists.C2D_list_curncy(:,col_name_country);
    instruments = config.RFR_Str_lists.C2D_list_curncy(:,col_SWP_GVT);
    swps = strcmp(instruments, 'SWP');
    
    llp = zeros(length(instruments), 1);
    llp(swps) = cell2mat(config.RFR_Str_lists.C2D_list_curncy(swps,col_LLP_SWP));
    llp(~swps) = cell2mat(config.RFR_Str_lists.C2D_list_curncy(~swps,col_LLP_GVT));
    
    DLT_GVT = config.RFR_basic_ADLT_GVT(:,11:end);
    DLT_GVT = cell2mat(DLT_GVT);
        
    DLT_SWP = config.RFR_basic_ADLT_SWP(:, 11:end);
    DLT_SWP = cell2mat(DLT_SWP);
    
    dlt = DLT_GVT;
    dlt(swps,:) = DLT_SWP(swps,:);
    dlt = logical(dlt);
    
    % Ignore all DLT points after the LLP
    for i=1:size(dlt,1)
       dlt(i,llp(i):end) = false; 
    end
    
    inputRates = ER_no_VA.M2D_raw_rates_net_CRA(:,1:size(dlt,2)) / 100;
    inputRates = inputRates .* dlt;
    calcRates = ER_no_VA.M2D_SW_spot_rates(:,1:size(dlt,2)) .* dlt;
    swapRates = ER_no_VA.M2D_SW_swap_rates(swps,1:size(dlt,2));
    calcRates(swps,:) = swapRates .* dlt(swps,:);

    delta = abs(calcRates - inputRates);
    result = delta > THRESHOLD;
    
    for i=1:size(result,1)
        if any(result(i,:))
            flags = find(result(i,:));
            errors = [errors;strcat(countries(i), ':', join(compose('%dY', flags), ','))];              
        end
    end
end

