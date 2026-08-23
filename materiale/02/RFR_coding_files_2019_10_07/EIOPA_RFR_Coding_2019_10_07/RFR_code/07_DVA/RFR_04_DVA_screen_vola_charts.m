


function [ Str_plot_left, Str_plot_right ] = RFR_04_DVA_screen_vola_charts...
                          (curve_selected, curncy_selected, ...
                            matur_selected, date_selected, ...
                            Str_vola, RFR_Str_lists)

                        
                        
                        
    col_ISO4217 = RFR_Str_lists.Str_numcol_curncy.ISO4217;
        
        %   number of the column in cell array
        %   'RFR_Str_lists.C2D_list_curncy'  containing ISO4217
        %   for each of the currencies / countries considered 


    CellCol_currencies = unique(RFR_Str_lists.C2D_list_curncy(:,col_ISO4217));

    string_curncy = CellCol_currencies{curncy_selected};

    pannel_curncy = find(...
        strcmp(RFR_Str_lists.C2D_list_curncy(:,col_ISO4217), string_curncy), 1, 'first');



    switch curve_selected

        
        case 1      % 'Par market rates. Term structure for a given date'
        % -----------------------------------------------------------------
        
            %   LEFT SIDE CHART ------------------------------------------
            
            Matrix_left  = Str_vola.M3D_par_mkt_rates (:, :, pannel_curncy);
            
            Str_plot_left.title  = 'Par market rates. Term structure for a given date';            
            Str_plot_left.text_x_axe  = ('Maturities');        
            
            Str_plot_left.y_max = max(max (Matrix_left (:, 2:end)));
            if Str_plot_left.y_max == 0
               Str_plot_left.y_max = 1;
            end
            
            Str_plot_left.y_min = min(min (Matrix_left (:, 2:end)));
            Str_plot_left.x_max = size(Matrix_left, 2) - 1;
            Str_plot_left.x_axe = (1 : 1 : size(Matrix_left, 2) - 1);
       
            Str_plot_left.M2D_plot = Matrix_left (date_selected, 2:end);


            %   RIGHT SIDE CHART ------------------------------------------
            
            Matrix_right = Str_vola.M3D_par_mkt_vola  (:, :, pannel_curncy); 
            
            Str_plot_right.title = 'Par market rates. Volatility 21 last days for a given date';
            Str_plot_right.text_x_axe = ('Maturities');
            
            %   Following instructions try to avoid charts with maximum
            %   values too high, where the behaviour of most of values
            %   is shown as an almost flat line nearby zero
            
            [ num_rows, num_cols ] = size (Matrix_right);
            V1C_interim = reshape(Matrix_right(26:end, 2:end), ...
                                   (num_rows-25)*(num_cols-1), 1);
            
            max_y_1 = max  (V1C_interim) ;
            max_y_2 = mean (V1C_interim);
            if (max_y_2 ~= 0) && (max_y_1 > 8 * max_y_2)
                max_y_final = 8 * max_y_2;
            else
                if max_y_1 == 0
                   max_y_final = 1;
                else
                   max_y_final = max_y_1;
                end
            end
            
            Str_plot_right.y_max = max_y_final;

            Str_plot_right.y_min = min(min (Matrix_right (:, 2:end)));
            Str_plot_right.x_max = size(Matrix_right, 2) - 1;
            Str_plot_right.x_axe = (1 : 1 : size(Matrix_right, 2) - 1);
       
            Str_plot_right.M2D_plot = Matrix_right (date_selected, 2:end);
            
            
        case 2    % 'Par market rates. Time serie for a given maturity'  
        % -----------------------------------------------------------------
        
            %   LEFT SIDE CHART ------------------------------------------
            
            Matrix_left   = Str_vola.M3D_par_mkt_rates (:, :, pannel_curncy);
            
            Str_plot_left.title  = 'Par market rates. Time serie for a given maturity'  ;
            Str_plot_left.text_x_axe  = ('Dates');
            
            Str_plot_left.y_max = max(max (Matrix_left (:, 2:end)));
            if Str_plot_left.y_max == 0
               Str_plot_left.y_max = 1;
            end
            
            Str_plot_left.y_min = min(min (Matrix_left (:, 2:end)));
            Str_plot_left.x_max = size(Matrix_left, 1);
            Str_plot_left.x_axe = (1 : 1 : size(Matrix_left, 1));
       
            Str_plot_left.M2D_plot = Matrix_left (:, matur_selected + 1);
           

            %   RIGHT SIDE CHART ------------------------------------------

            Matrix_right  = Str_vola.M3D_par_mkt_vola  (:, :, pannel_curncy);
            
            Str_plot_right.title = 'Par market rates. Time serie volatility 21 last days';            
            Str_plot_right.text_x_axe = ('Dates');
            
            %   Following instructions try to avoid charts with maximum
            %   values too high, where the behaviour of most of values
            %   is shown as an almost flat line nearby zero
            
            [ num_rows, num_cols ] = size (Matrix_right);
            V1C_interim = reshape(Matrix_right(26:end, 2:end), ...
                                   (num_rows-25)*(num_cols-1), 1);
            
            max_y_1 = max  (V1C_interim) ;
            max_y_2 = mean (V1C_interim);
            if (max_y_2 ~= 0) && (max_y_1 > 8 * max_y_2)
                max_y_final = 8 * max_y_2;
            else
                if max_y_1 == 0
                   max_y_final = 1;
                else
                   max_y_final = max_y_1;
                end
            end
                                    
            Str_plot_right.y_max = max_y_final;

            Str_plot_right.y_min = min(min (Matrix_right (:, 2:end)));
            Str_plot_right.x_max = size(Matrix_right, 1);
            Str_plot_right.x_axe = (1 : 1 : size(Matrix_right, 1));
                  
            Str_plot_right.M2D_plot = Matrix_right (:, matur_selected + 1);
        
        
        case 3      % 'Spot rates. Zero coupon term structure for a given date'
        % -----------------------------------------------------------------
        
            %   LEFT SIDE CHART ------------------------------------------
            
            Matrix_left  = Str_vola.M3D_zero_spot_rates (:, :, pannel_curncy);
            
            Str_plot_left.title  = 'Zero-coupon Spot rates. Term structure for a given date';            
            Str_plot_left.text_x_axe  = ('Maturities');        
            
            Str_plot_left.y_max = max(max (Matrix_left (:, 2:end)));
            if Str_plot_left.y_max == 0
               Str_plot_left.y_max = 1;
            end
            
            Str_plot_left.y_min = min(min (Matrix_left (:, 2:end)));
            Str_plot_left.x_max = size(Matrix_left, 2) - 1;
            Str_plot_left.x_axe = (1 : 1 : size(Matrix_left, 2) - 1);
       
            Str_plot_left.M2D_plot = Matrix_left (date_selected, 2:end);


            %   RIGHT SIDE CHART ------------------------------------------
            
            Matrix_right = Str_vola.M3D_zero_spot_vola  (:, :, pannel_curncy); 
            
            Str_plot_right.title = 'Zero-coupon Spot rates. Volatility 21 last days for a given date';
            Str_plot_right.text_x_axe = ('Maturities');
            
            %   Following instructions try to avoid charts with maximum
            %   values too high, where the behaviour of most of values
            %   is shown as an almost flat line nearby zero
            
            [ num_rows, num_cols ] = size (Matrix_right);
            V1C_interim = reshape(Matrix_right(26:end, 2:end), ...
                                   (num_rows-25)*(num_cols-1), 1);
            
            max_y_1 = max  (V1C_interim) ;
            max_y_2 = mean (V1C_interim);
            if (max_y_2 ~= 0) && (max_y_1 > 8 * max_y_2)
                max_y_final = 8 * max_y_2;
            else
                if max_y_1 == 0
                   max_y_final = 1;
                else
                   max_y_final = max_y_1;
                end
            end
            
            Str_plot_right.y_max = max_y_final;

            Str_plot_right.y_min = min(min (Matrix_right (:, 2:end)));
            Str_plot_right.x_max = size(Matrix_right, 2) - 1;
            Str_plot_right.x_axe = (1 : 1 : size(Matrix_right, 2) - 1);
       
            Str_plot_right.M2D_plot = Matrix_right (date_selected, 2:end);
            
            
        case 4    % 'Spot rates. Zero coupon rates for a given maturity'  
        % -----------------------------------------------------------------
        
            %   LEFT SIDE CHART ------------------------------------------
            
            Matrix_left   = Str_vola.M3D_zero_spot_rates (:, :, pannel_curncy);
            
            Str_plot_left.title  = 'Zero-coupon Spot rates. Time series for a given maturity'  ;
            Str_plot_left.text_x_axe  = ('Dates');
            
            Str_plot_left.y_max = max(max (Matrix_left (:, 2:end)));
            if Str_plot_left.y_max == 0
               Str_plot_left.y_max = 1;
            end
            
            Str_plot_left.y_min = min(min (Matrix_left (:, 2:end)));
            Str_plot_left.x_max = size(Matrix_left, 1);
            Str_plot_left.x_axe = (1 : 1 : size(Matrix_left, 1));
       
            Str_plot_left.M2D_plot = Matrix_left (:, matur_selected + 1);
           

            %   RIGHT SIDE CHART ------------------------------------------

            Matrix_right  = Str_vola.M3D_zero_spot_vola  (:, :, pannel_curncy);
            
            Str_plot_right.title = 'Zero-coupon Spot rates. Time series volatility 21 last days';            
            Str_plot_right.text_x_axe = ('Dates');
            
            %   Following instructions try to avoid charts with maximum
            %   values too high, where the behaviour of most of values
            %   is shown as an almost flat line nearby zero
            
            [ num_rows, num_cols ] = size (Matrix_right);
            V1C_interim = reshape(Matrix_right(26:end, 2:end), ...
                                   (num_rows-25)*(num_cols-1), 1);
            
            max_y_1 = max  (V1C_interim) ;
            max_y_2 = mean (V1C_interim);
            if (max_y_2 ~= 0) && (max_y_1 > 8 * max_y_2)
                max_y_final = 8 * max_y_2;
            else
                if max_y_1 == 0
                   max_y_final = 1;
                else
                   max_y_final = max_y_1;
                end
            end
                                    
            Str_plot_right.y_max = max_y_final;

            Str_plot_right.y_min = min(min (Matrix_right (:, 2:end)));
            Str_plot_right.x_max = size(Matrix_right, 1);
            Str_plot_right.x_axe = (1 : 1 : size(Matrix_right, 1));
                  
            Str_plot_right.M2D_plot = Matrix_right (:, matur_selected + 1);
            
            
        case 5   % 'Forwad rates term structure for a given date'
        % -----------------------------------------------------------------

            %   LEFT SIDE CHART ------------------------------------------
                    
            Matrix_left   = Str_vola.M3D_fwd_rates (:, :, pannel_curncy);
            
            Str_plot_left.title  = 'Forward rates. Term structure for a given date';
            Str_plot_left.text_x_axe  = ('Maturities');        
            
            Str_plot_left.y_max = max(max (Matrix_left (:, 2:end)));
            if Str_plot_left.y_max == 0
               Str_plot_left.y_max = 1;
             end
            Str_plot_left.y_min = min(min (Matrix_left (:, 2:end)));
            Str_plot_left.x_max = size(Matrix_left, 2) - 1;
            Str_plot_left.x_axe = (1 : 1 : size(Matrix_left, 2) - 1);
       
            Str_plot_left.M2D_plot = Matrix_left (date_selected, 2:end);

            
            %   RIGHT SIDE CHART ------------------------------------------
            
            Matrix_right  = Str_vola.M3D_fwd_vola  (:, :,  pannel_curncy);
            
            Str_plot_right.title = 'Forward rates. Volatility 21 last days for a given date'; 
            Str_plot_right.text_x_axe = ('Maturities');
            
            %   Following instructions try to avoid charts with maximum
            %   values too high, where the behaviour of most of values
            %   is shown as an almost flat line nearby zero
            
            [ num_rows, num_cols ] = size (Matrix_right);
            V1C_interim = reshape(Matrix_right(26:end, 2:end), ...
                                   (num_rows-25)*(num_cols-1), 1);
            
            max_y_1 = max  (V1C_interim) ;
            max_y_2 = mean (V1C_interim);
            if (max_y_2 ~= 0) && (max_y_1 > 8 * max_y_2)
                max_y_final = 8 * max_y_2;
            else
                if max_y_1 == 0
                   max_y_final = 1;
                else
                   max_y_final = max_y_1;
                end
            end
            
            Str_plot_right.y_max = max_y_final;

            Str_plot_right.y_min = min(min (Matrix_right (:, 2:end)));
            Str_plot_right.x_max = size(Matrix_right, 2) - 1;
            Str_plot_right.x_axe = (1:size(Matrix_right, 2) - 1);
       
            Str_plot_right.M2D_plot = Matrix_right (date_selected, 2:end);

            
        case 6  % 'Forwad rates for a given maturity'
        % -----------------------------------------------------------------
 
            %   LEFT SIDE CHART ------------------------------------------
                   
            Matrix_left  = Str_vola.M3D_fwd_rates (:, :, pannel_curncy);
            
            Str_plot_left.title  = 'Forward rates. Time series for a given maturity';
            Str_plot_left.text_x_axe  = (' Dates');

            Str_plot_left.y_max = max(max (Matrix_left (:, 2:end)));
            if Str_plot_left.y_max == 0
               Str_plot_left.y_max = 1;
            end
            Str_plot_left.y_min = min(min (Matrix_left (:, 2:end)));
            Str_plot_left.x_max = size(Matrix_left, 1);
            Str_plot_left.x_axe = (1 : 1 : size(Matrix_left, 1));
       
            Str_plot_left.M2D_plot = Matrix_left (:, matur_selected + 1);

            
            %   RIGHT SIDE CHART ------------------------------------------
            
            Matrix_right = Str_vola.M3D_fwd_vola  (:, :, pannel_curncy);
            
            Str_plot_right.title = 'Forward rates. Time series volatility 21 last days'; 
            Str_plot_right.text_x_axe = (' Dates');

            %   Following instructions try to avoid charts with maximum
            %   values too high, where the behaviour of most of values
            %   is shown as an almost flat line nearby zero
            
            [ num_rows, num_cols ] = size (Matrix_right);
            V1C_interim = reshape(Matrix_right(26:end, 2:end), ...
                                   (num_rows-25)*(num_cols-1), 1);
            
            max_y_1 = max  (V1C_interim) ;
            max_y_2 = mean (V1C_interim);
            if (max_y_2 ~= 0) && (max_y_1 > 8 * max_y_2)
                max_y_final = 8 * max_y_2;
            else
                if max_y_1 == 0
                   max_y_final = 1;
                else
                   max_y_final = max_y_1;
                end
            end
            
            Str_plot_right.y_max = max_y_final;

            Str_plot_right.y_min = min(min (Matrix_right (:, 2:end)));
            Str_plot_right.x_max = size(Matrix_right, 1);
            Str_plot_right.x_axe = (1 : 1 : size(Matrix_right, 1));
                  
            Str_plot_right.M2D_plot = Matrix_right (:, matur_selected + 1);
            
        
                
            
        case 7   % 'Forwad rates term structure for a given date and Roll measure'
        % -----------------------------------------------------------------

            %   LEFT SIDE CHART ------------------------------------------
                    
            Matrix_left   = Str_vola.M3D_zero_spot_rates (:, :, pannel_curncy);
            
            Str_plot_left.title  = 'Zero-coupon Spot rates. Term structure for a given date';
            Str_plot_left.text_x_axe  = ('Maturities');        
            
            Str_plot_left.y_max = max(max (Matrix_left (:, 2:end)));
            if Str_plot_left.y_max == 0
               Str_plot_left.y_max = 1;
             end
            Str_plot_left.y_min = min(min (Matrix_left (:, 2:end)));
            Str_plot_left.x_max = size(Matrix_left, 2) - 1;
            Str_plot_left.x_axe = (1 : 1 : size(Matrix_left, 2) - 1);
       
            Str_plot_left.M2D_plot = Matrix_left (date_selected, 2:end);

            
            %   RIGHT SIDE CHART ------------------------------------------
            
            Matrix_right  = Str_vola.M3D_Roll (:, :,  pannel_curncy);
            
            Str_plot_right.title = 'Zero-coupon Spot rates. Roll measure (*100) 21 last days for a given date'; 
            Str_plot_right.text_x_axe = ('Maturities');
            
            %   Following instructions try to avoid charts with maximum
            %   values too high, where the behaviour of most of values
            %   is shown as an almost flat line nearby zero
            
            [ num_rows, num_cols ] = size (Matrix_right);
            V1C_interim = reshape(Matrix_right(26:end, 2:end), ...
                                   (num_rows-25)*(num_cols-1), 1);
            
            max_y_1 = max  (V1C_interim) ;
            max_y_2 = mean (V1C_interim);
            if (max_y_2 ~= 0) && (max_y_1 > 8 * max_y_2)
                max_y_final = 8 * max_y_2;
            else
                if max_y_1 == 0
                   max_y_final = 1;
                else
                   max_y_final = max_y_1;
                end
            end
            
            Str_plot_right.y_max = max_y_final;

            Str_plot_right.y_min = min(min (Matrix_right (:, 2:end)));
            Str_plot_right.x_max = size(Matrix_right, 2) - 1;
            Str_plot_right.x_axe = (1 : 1 : size(Matrix_right, 2) - 1);
       
            Str_plot_right.M2D_plot = Matrix_right (date_selected, 2:end);

            
        case 8  % 'Spot rates for a given maturity and Roll measure'
        % -----------------------------------------------------------------
 
            %   LEFT SIDE CHART ------------------------------------------
                   
            Matrix_left  = Str_vola.M3D_zero_spot_rates (:, :, pannel_curncy);
            
            Str_plot_left.title  = 'Zero-coupon Spot rates. Time series for a given maturity';
            Str_plot_left.text_x_axe  = (' Dates');

            Str_plot_left.y_max = max(max (Matrix_left (:, 2:end)));
            if Str_plot_left.y_max == 0
               Str_plot_left.y_max = 1;
            end
            Str_plot_left.y_min = min(min (Matrix_left (:, 2:end)));
            Str_plot_left.x_max = size(Matrix_left, 1);
            Str_plot_left.x_axe = (1 : 1 : size(Matrix_left, 1));
       
            Str_plot_left.M2D_plot = Matrix_left (:, matur_selected + 1);

            
            %   RIGHT SIDE CHART ------------------------------------------
            
            Matrix_right = Str_vola.M3D_Roll (:, :, pannel_curncy);
            
            Str_plot_right.title = 'Zero-coupon Spot rates. Time series Roll measure (*100) 21 last days'; 
            Str_plot_right.text_x_axe = (' Dates');

            %   Following instructions try to avoid charts with maximum
            %   values too high, where the behaviour of most of values
            %   is shown as an almost flat line nearby zero
            
            [ num_rows, num_cols ] = size (Matrix_right);
            V1C_interim = reshape(Matrix_right(26:end, 2:end), ...
                                   (num_rows-25)*(num_cols-1), 1);
            
            max_y_1 = max  (V1C_interim) ;
            max_y_2 = mean (V1C_interim);
            if (max_y_2 ~= 0) && (max_y_1 > 8 * max_y_2)
                max_y_final = 8 * max_y_2;
            else
                if max_y_1 == 0
                   max_y_final = 1;
                else
                   max_y_final = max_y_1;
                end
            end
            
            Str_plot_right.y_max = max_y_final;

            Str_plot_right.y_min = min(min (Matrix_right (:, 2:end)));
            Str_plot_right.x_max = size(Matrix_right, 1);
            Str_plot_right.x_axe = (1 : 1 : size(Matrix_right, 1));
                  
            Str_plot_right.M2D_plot = Matrix_right (:, matur_selected + 1);
        
            
            
        case 9  % Forward rates in LLP. Fitting polynomial 4 degrees;
        % -----------------------------------------------------------------


            %   LEFT SIDE CHART ------------------------------------------
                
            Matrix_left = Str_vola.M3D_fwd_fit_last_date(:, 2:3, pannel_curncy);

            Str_plot_left.title = 'Raw forward rates LLP versus 4-degree polynomial fitting last 21-days as of calculation date';
            Str_plot_left.text_x_axe = ('Dates');

            Str_plot_left.y_max =  max(Matrix_left);

            if Str_plot_left.y_max == 0
               Str_plot_left.y_max = 1;
            end
            Str_plot_left.y_min = min(Matrix_left);
            
            max_x = size(Matrix_left, 1);

            Str_plot_left.x_max = max_x;
            Str_plot_left.M2D_plot = Matrix_left ;
            Str_plot_left.x_axe = (1 : 1 : size(Matrix_left,1));
            

            
        %   RIGHT SIDE CHART ------------------------------------------
            
            Matrix_right =  Str_vola.M3D_fwd_rates    (26:end, end, pannel_curncy) - ...
                            Str_vola.M3D_fwd_fit_diff (26:end, end, pannel_curncy) ;

        %    Matrix_left = [ Str_vola.M3D_fwd_rates(:,1,pannel_curncy)...
        %                    VecCol_int1 ];
            
            Str_plot_right.title  = 'Deviation raw forward rates LLP versus 4-degree polynomial fitting last 21-days (in bp)';            
            Str_plot_right.text_x_axe = ('Dates');
      
            Str_plot_right.y_max = max(Matrix_right) ;
            if Str_plot_right.y_max == 0
               Str_plot_right.y_max = 1;
            end            
            Str_plot_right.y_min = min(Matrix_right);

            Str_plot_right.x_max = size(Matrix_right,1);
            Str_plot_right.x_axe = (1 : 1 : size(Matrix_right,1));

            Str_plot_right.M2D_plot = Matrix_right;
   
    end   

    
       
    Str_plot_left.M2D_plot  (find(Str_plot_left.M2D_plot  == 0)) = NaN;

    Str_plot_right.M2D_plot (find(Str_plot_right.M2D_plot == 0)) = NaN;


end

