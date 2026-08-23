% Cost of Downgrade
% Calculted according to section 10.C.2 and annex 14.H of the technical documentation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%Inputs%%%

% Transition_matrix should be a N x N+1 matrix. 
% The last column should be the "non rated" transitions. 
% The last row should be 0 0 ... 0 1 0 (default transitions)
% The code is also working in case the transition matrix doesn't have "non
% rated" transitions

% The benchmark_yield_vector should be the risk free rate, 
% with as many maturities as in the Spread_table

% The recovery_rate_corp is a %. It should be 30%

% Inception_Factor is a vector of length CQS. Each row is defined as a
% percentage of the MV of the benchmark and will be used to calculate the
% MV of the bonds

% Initial_Factor is set to 15 and is a calibration factor

%%%Outputs%%%
% The outputs are three matrices 
% The first two are the cost of downgrade and the cost of default, size N x 60
% They are expressed in percentages
% The last rows are not to be used 
% (row for "Default" credit quality step, only there for computation purpose)
% The last output is the probability of default
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [CoD,PD,ProbD] = PD_CoD ...
					(benchmark_yield_vector, recovery_rate_corp, ...
					Transition_matrix, Inception_Factor, Initial_factor)

% Define maturity
Maturity = size(benchmark_yield_vector,2);

% Test if the transition matrix is with or without a withdrawn column
% Case without:
if size(Transition_matrix,1) == size(Transition_matrix,2)
    n = length(Transition_matrix);
	My_Transition_matrix = Transition_matrix;
% Case with:
else    
    % Allocate the last column of the transition matrix 
	%(i.e. the non-rated) to the other columns:
    n = length(Transition_matrix) - 1; %-1 because the last column is the non-rated
    My_Transition_matrix = Transition_matrix(:,1:n);
    My_Transition_matrix = My_Transition_matrix./repmat((1-Transition_matrix(:,end)),1,n);
end

% Add infinity line to the spread table 
% (corresponding to the spreads of default credit quality step, for computation purpose)
My_Inception_Factor = [Inception_Factor;Inf];

% Define CQS (Credit Quality Step) and maturity buckets
CQS = [1:size(My_Inception_Factor,1)];
Maturity_buckets = [1:size(benchmark_yield_vector,2)];

% Transition matrix taking upgrades after downgrade into account:
Aux_Transition_matrix = zeros(n);

for i = 1:n
    Aux_Transition_matrix(i,1:(i-1)) = My_Transition_matrix(i,1:(i-1));
    Aux_Transition_matrix(i,i) = sum(My_Transition_matrix(i,i:(n-1)));
    Aux_Transition_matrix(i,n) = My_Transition_matrix(i,n);
end


% Define Market value of the benchmark (ZC bond)
MV_benchmark = (1 + benchmark_yield_vector).^[1:length(benchmark_yield_vector)];

% Compute cost of downgrade matrix $C_D^{(d)}$
C_D_d = zeros(Maturity,Maturity,length(CQS),length(CQS));
default = max(CQS);
for d = 1:Maturity
    for t = 1:d 
        for X = CQS(1):CQS((length(CQS)-1)) 
            for Y = CQS(X+1):CQS(length(CQS))
                if Y == default 
                    %  loss given default is (1 - recovery_rate) * (last market value)
                    C_D_d(d,t,X,Y) = (1 - recovery_rate_corp) * My_Inception_Factor(X)^...
									((d-t)/Initial_factor) * MV_benchmark(t) * ...
									My_Transition_matrix(X,Y);
                else 
                    C_D_d(d,t,X,Y) = (My_Inception_Factor(X)^((d-t)/Initial_factor) - ...
									My_Inception_Factor(Y)^((d-t)/Initial_factor)) * ...
									MV_benchmark(t) * My_Transition_matrix(X,Y);
                end
            end
        end
    end
end

% Compute cost of downgrade cash flows (matrix CoD)
CoD = zeros(length(CQS),length(Maturity_buckets));
PD = zeros(length(CQS),length(Maturity_buckets));
PD_for_CoD = zeros(length(CQS),length(Maturity_buckets));
ProbD = zeros(length(CQS),length(Maturity_buckets));
n = length(CQS);
for D = Maturity_buckets(1):Maturity_buckets(length(Maturity_buckets))
    CoD_cashflows = zeros(n,D);
    PD_cashflows = zeros(n,D);
    PD_cashflows_for_CoD = zeros(n,D);
    q = eye(n); %start with identity matrix
    tm = eye(n); % same here
    for d = 1:D
      % Note: the matrices q and tm represent Q_Transition_matrix^(d-1) 
	  % and Transition_matrix^(d-1), respectively (see below)
	  
	  % vector (1,...,1,0) extracts all downgrades
      CoD_cashflows(:,d) =  q * squeeze(C_D_d(D,d,:,:)) * [ones(n-1,1);0];
      PD_cashflows_for_CoD(:,d) = q * squeeze(C_D_d(D,d,:,:)) * [zeros(n-1,1);1]; 
      q = Aux_Transition_matrix * q; 
      % at this stage, q = Q_Transition_matrix^ d (see above)
	  

	  % vector (0,...,0,1) extracts all defaults	  
      PD_cashflows(:,d) = tm * squeeze(C_D_d(D,d,:,:)) * [zeros(n-1,1);1]; 
      tm = My_Transition_matrix * tm; 
      % at this stage, tm =   Transition_matrix ^ d (see above)
	  
      % Store the probability of defaults, which is the last column of the
      % transition matrix
      if D == length(Maturity_buckets)
         ProbD(:,d) = tm(:,n);
      end
    end

	% Solve the equation
    for c = CQS(1:(length(CQS)-1))

       
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       % PD:
       Temp = (1+benchmark_yield_vector(D)) / (1 - sum(PD_cashflows(c,1:D) ./ ...
				(1 + benchmark_yield_vector(1:D)) .^ (0.5 + (0:(D-1))))) .^ (1 / D) - ...
				(1 + benchmark_yield_vector(D));
       
	   % Testing if the result is complex
       if isreal(Temp)
          PD(c,D) = Temp;
       else
          PD(c,D) = 0;
       end        
        
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       % PD for CoD:
       Temp = (1+benchmark_yield_vector(D)) / (1 - sum(PD_cashflows_for_CoD(c,1:D) ./ ...
				(1 + benchmark_yield_vector(1:D)) .^ (0.5 + (0:(D-1))))) .^ (1 / D) - ...
				(1 + benchmark_yield_vector(D));
       
	   % Testing if the result is complex
       if isreal(Temp)
          PD_for_CoD(c,D) = Temp;
       else
          PD_for_CoD(c,D) = 0;
       end
       
       %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
       % CoD:
       Temp = (1+benchmark_yield_vector(D)) / (1 - sum(CoD_cashflows(c,1:D) ./ ...
				(1 + benchmark_yield_vector(1:D)) .^ (0.5 + (0:(D - 1))))) .^ (1 / D) - ...
				(1 + benchmark_yield_vector(D));
       % Testing if the result is complex
       if isreal(Temp)
          CoD(c,D) = Temp;
       else
          CoD(c,D) = 0;
       end

       %Remove double counting
       CoD(c,D) = max ( 0, CoD(c,D) - ( PD(c,D) - PD_for_CoD(c,D))) ;       
       
    end
	
end
   %CoD in percentages
   CoD = CoD * 100;
   %PD in percentages
   PD = PD * 100;
end










