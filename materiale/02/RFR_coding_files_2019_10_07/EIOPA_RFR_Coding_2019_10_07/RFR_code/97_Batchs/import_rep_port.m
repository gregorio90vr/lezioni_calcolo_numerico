% Import the representative portfolio data from the AssetsRP Combined 
% SoloGroupTemplate file in the same directory into the corresponding 
% Str_VA_market_data structure.
%
% Preparatory steps before this script is run:
%
% 1. Copy the AssetsRP file to this directory. 
% 2. Copy the Str_VA_market_data.mat file to this directory.
% 3. Change the "REFDATE" constant to the reference date of the new
%    representative portfolio.
%
% After running the script, copy the Str_VA_market_data.mat file to the
% 06_VA directory of the production data directory.
%
% Assumptions: All currency and country codes in the excel file are
% consistent with the ones in the MATLAB structure.
%
% 

%% CONSTANTS
% Reference Date for the implementation of the representative portfolio
REFDATE = datenum(2018,3,31);
INPUTFILE = fullfile('AssetsRP Combined SoloGroupTemplate DKKfrozen v19032012.xlsb');
VAFILE = 'Str_VA_market_data.mat';

%% Main
data = load(VAFILE);

refDateStr = datestr(REFDATE, 'yyyymmdd');
currencyVAStr = ['VA_C_' refDateStr];
nationalVAStr = ['VA_N_' refDateStr];

% Copy the reference structure
data.Str_VA_market_data.(currencyVAStr) = data.Str_VA_market_data.VA_C_20131231;
data.Str_VA_market_data.(nationalVAStr) = data.Str_VA_market_data.VA_N_20131231;

% Overwrite the data with the new representative portfolio

% EUR duration
data.Str_VA_market_data.(currencyVAStr).ECB = xlsread(INPUTFILE, 'SOLO EUR Duration', 'EURduration');
data.Str_VA_market_data.(nationalVAStr).ECB = data.Str_VA_market_data.(currencyVAStr).ECB;

% Currency weights
[curWeights,curCode] = xlsread(INPUTFILE, 'VA_Currency_Weights', 'VA_Currency_Weights');
data.Str_VA_market_data.(currencyVAStr).M2D_weights = curWeights;

% National weights
[natWeights,natCode] = xlsread(INPUTFILE, 'VA_National_Weights', 'VA_National_Weights');
data.Str_VA_market_data.(nationalVAStr).M2D_weights = natWeights;

% Currency GOV composition
[curGOVweights,curGOVheaders] = xlsread(INPUTFILE, 'VA_C_Govts_Comp', 'VA_C_Govts_Comp');
data.Str_VA_market_data.(currencyVAStr).Govts.M2D_govts_portfolio = curGOVweights;

% Currency GOV duration
[curGOVdurations,curGOVheaders] = xlsread(INPUTFILE, 'VA_C_Govts_Dur', 'VA_C_Govts_Dur');
data.Str_VA_market_data.(currencyVAStr).Govts.M2D_govts_durations = curGOVdurations;

% Currency CORP composition
[curCORPweights,curCORPheaders] = xlsread(INPUTFILE, 'VA_C_Corps_Comp', 'VA_C_Corps_Comp');
data.Str_VA_market_data.(currencyVAStr).Corps.M2D_corps_portfolio = curCORPweights;

% Currency CORP duration
[curCORPdurations,curCORPheaders] = xlsread(INPUTFILE, 'VA_C_Corps_Dur', 'VA_C_Corps_Dur');
data.Str_VA_market_data.(currencyVAStr).Corps.M2D_corps_durations = curCORPdurations;

% National GOV composition
[natGOVweights,natGOVheaders] = xlsread(INPUTFILE, 'VA_N_Govts_Comp', 'VA_N_Govts_Comp');
data.Str_VA_market_data.(nationalVAStr).Govts.M2D_govts_portfolio = natGOVweights;

% National GOV duration
[natGOVdurations,natGOVheaders] = xlsread(INPUTFILE, 'VA_N_Govts_Dur', 'VA_N_Govts_Dur');
data.Str_VA_market_data.(nationalVAStr).Govts.M2D_govts_durations = natGOVdurations;

% National CORP composition
[natCORPweights,natCORPheaders] = xlsread(INPUTFILE, 'VA_N_Corps_Comp', 'VA_N_Corps_Comp');
data.Str_VA_market_data.(nationalVAStr).Corps.M2D_corps_portfolio = natCORPweights;

% National CORP duration
[natCORPdurations,natCORPheaders] = xlsread(INPUTFILE, 'VA_N_Corps_Dur', 'VA_N_Corps_Dur');
data.Str_VA_market_data.(nationalVAStr).Corps.M2D_corps_durations = natCORPdurations;

save('Str_VA_market_data.mat', '-struct', 'data')

