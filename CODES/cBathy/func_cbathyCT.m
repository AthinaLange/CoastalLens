function Video = func_cbathyCT(Video, cutoff)
        gamma_H = 0.42; % gamma = H/h value 
        x10 = Video.x10;
        % images are named from top left corner, but we define x10 going from 
        % bottom to top (shore -> offshore)
        x10 = (flipud(x10))';
        min_tide = Video.min_tide;
        %% Surfzone depth inversion - default c
        %%% compute depth inversion with $c = \sqrt(gh(1+\gamma))$
        c_real = Video.crests.c_15m_avg;
        break_loc = (Video.bp);
        % set completely broken to 0
        if ~isempty(find(isnan(break_loc)==1))
            break_loc(find(isnan(break_loc)==1)) = 0;
        end
        
        for nn = 1:size(c_real,2)
            % compute array of 0 or 1.42 depending on if broken or not
            corr = (1+gamma_H)*ones(size(x10))';
            % if not all broken
            if break_loc(nn) ~=0
                corr(1:break_loc(nn))=1;
            end

            % Get bathy inversion
            h_crest_lin(:,nn) = c_real(:,nn).^2./(9.81);
            h_crest_lin(find(h_crest_lin(:,nn)>10),nn)=NaN;
    
            h_crest_nlin(:,nn) = c_real(:,nn).^2./(9.81.*(1+gamma_H));
            h_crest_nlin(find(h_crest_nlin(:,nn)>10),nn)=NaN;
         
            h_crest_bp(:,nn) = c_real(:,nn).^2./(9.81.*corr);
            h_crest_bp(find(h_crest_bp(:,nn)>10),nn)=NaN;
        
        end
            
        %%% Compute h avg 
        af=find(~isnan(nanmean(h_crest_lin,2)));
        %%
        smooth_factor = 5*10;
        % 5m Gaussian smoothing after averaging
        h_crest_lin_avg = smoothdata(nanmean(h_crest_lin,2), 'gaussian', smooth_factor);
        h_crest_nlin_avg = smoothdata(nanmean(h_crest_nlin,2), 'gaussian', smooth_factor);
        h_crest_bp_avg = smoothdata(nanmean(h_crest_bp,2), 'gaussian', smooth_factor);
        
        % remove artefacts of smoothing
        h_crest_lin_avg(1:af(1))=NaN;
        h_crest_nlin_avg(1:af(1))=NaN;
        h_crest_bp_avg(1:af(1))=NaN;
        h_crest_lin_avg(af(end):end)=NaN;
        h_crest_nlin_avg(af(end):end)=NaN;
        h_crest_bp_avg(af(end):end)=NaN;
        
        % flip to match x10 in structure
        if isrow(h_crest_lin_avg); h_crest_lin_avg = h_crest_lin_avg'; end
        if isrow(h_crest_nlin_avg); h_crest_nlin_avg = h_crest_nlin_avg'; end
        if isrow(h_crest_bp_avg); h_crest_bp_avg = h_crest_bp_avg'; end

        % go from depth to NAVD88m with tidal correction
        h_crest_lin_avg = flipud(-h_crest_lin_avg) + Video.tide;
        h_crest_nlin_avg = flipud(-h_crest_nlin_avg) + Video.tide;
        h_crest_bp_avg = flipud(-h_crest_bp_avg) + Video.tide;

        % remove any downsloping curves
        [~,i]=max(h_crest_lin_avg); h_crest_lin_avg(1:i-1)=NaN;
        [~,i]=max(h_crest_nlin_avg); h_crest_nlin_avg(1:i-1)=NaN;
        [~,i]=max(h_crest_bp_avg); h_crest_bp_avg(1:i-1)=NaN;

%%
        if ~isnan(cutoff.cbathy)
            Video.cbathy.z_interp(cutoff.cbathy:end) = NaN;
        end
       
        %%% x-shift to match subaerial surveys
        id = find(~isnan(h_crest_bp_avg)==1); % find first non-nan of predicted bathy
        if isempty(id)
            xshift = NaN;
        elseif h_crest_bp_avg(id(1)) < min_tide % if predicted bathy doesn't reach to min tide
            [~,id2]=min(abs((h_crest_bp_avg(id(1)))-Video.survey.z));
            xshift =-(id2-id(1));
        else % when predicted bathy does reach min tide
            [~,ab]=min(abs(h_crest_bp_avg-min_tide));
            [~,ac]=min(abs(Video.survey.z-min_tide));
            xshift = ab-ac;
            clear ab ac
        end
        %xshift = -450
        xshift = 0;
        Video.ct.xshift = xshift;
        
        if xshift < 0 % get rid of shoreward points
            xshift = abs(xshift);
            Video.ct.h_avg.lin = [NaN(xshift,1); h_crest_lin_avg(1:end-xshift)];
            Video.ct.h_avg.nlin = [NaN(xshift,1); h_crest_nlin_avg(1:end-xshift)];
            Video.ct.h_avg.bp = [NaN(xshift,1); h_crest_bp_avg(1:end-xshift)];
        elseif xshift == 0
            Video.ct.h_avg.lin = h_crest_lin_avg;
            Video.ct.h_avg.nlin = h_crest_nlin_avg;
            Video.ct.h_avg.bp = h_crest_bp_avg;
        elseif xshift > 0 % add shoreward points
            Video.ct.h_avg.lin = [h_crest_lin_avg(xshift+1:end); NaN(xshift,1)];
            Video.ct.h_avg.nlin = [h_crest_nlin_avg(xshift+1:end); NaN(xshift,1); ];
            Video.ct.h_avg.bp = [h_crest_bp_avg(xshift+1:end); NaN(xshift,1); ];
        elseif isnan(xshift)
            Video.ct.h_avg.lin = h_crest_lin_avg;
            Video.ct.h_avg.nlin = h_crest_nlin_avg;
            Video.ct.h_avg.bp = h_crest_bp_avg;
        end
        %%% x-shift to match subaerial surveys
        id = find(~isnan(Video.cbathy.z_interp)==1); % find first non-nan of predicted bathy
        if isempty(id)
            xshift = NaN;
        elseif Video.cbathy.z_interp(id(1)) < min_tide % if predicted bathy doesn't reach to min tide
            [~,id2]=min(abs((Video.cbathy.z_interp(id(1)))-Video.survey.z));
            xshift =-(id2-id(1));
        else % when predicted bathy does reach min tide
            [~,ab]=min(abs(Video.cbathy.z_interp-min_tide));
            [~,ac]=min(abs(Video.survey.z_interp-min_tide));
            xshift = ab-ac;
            clear ab ac
        end
        Video.cbathy.xshift = xshift;
        %%% Mean gamma(x)

        gamma = zeros(length(Video.x10),length(Video.bp));
        for bb = 1:length(Video.bp)
            if Video.bp(bb) == 5001
                gamma(:,bb)=NaN;
            elseif isnan(Video.bp(bb))
                gamma(:,bb)=NaN;
            else
                gamma(1:5001-Video.bp(bb),bb) = 0.42;
            end
        end
        gamma(:,isnan(gamma(1,:)))=[];
        Video.ct.gamma = gamma;
        Video.ct.gamma_mean = mean(gamma,2);

        
        %%% Cutoff offshore based on pixel resolution
        if ~isnan(cutoff.ct)
            Video.ct.h_avg.lin(cutoff.ct:end) = NaN;
            Video.ct.h_avg.nlin(cutoff.ct:end) = NaN;
            Video.ct.h_avg.bp(cutoff.ct:end) = NaN;
        end

        %%% Interpolate to 0.5m grid
        Video.x5 = Video.x10(1:5:end);
        Video.ct.h_avg.lin = interp1(Video.x10, Video.ct.h_avg.lin, Video.x5);
        Video.ct.h_avg.nlin = interp1(Video.x10, Video.ct.h_avg.nlin, Video.x5);
        Video.ct.h_avg.bp = interp1(Video.x10, Video.ct.h_avg.bp, Video.x5);
       
        %% Create composites
        
        [Video] = create_composite_bathys(Video, gamma_H);
        

        %%% Variable surfzone RMSE
        lim = Video.lims;
        %%
        % Inner Surfzone Stats
        [Video.Error.RMSE_insz.cb, Video.Error.Skill_insz.cb, Video.Error.Bias_insz.cb] = calc_errors(Video.survey.z_interp, Video.cbathy.z_interp,[lim(1) lim(2)]);
        [Video.Error.RMSE_insz.cb_gamma, Video.Error.Skill_insz.cb_gamma, Video.Error.Bias_insz.cb_gamma] = calc_errors(Video.survey.z_interp, Video.cbathy.cbathy_gamma,[lim(1) lim(2)]);
        
        [Video.Error.RMSE_insz.lin, Video.Error.Skill_insz.lin, Video.Error.Bias_insz.lin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.lin, Video.x10)', [lim(1) lim(2)]);
        [Video.Error.RMSE_insz.nlin, Video.Error.Skill_insz.nlin, Video.Error.Bias_insz.nlin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.nlin, Video.x10)', [lim(1) lim(2)]);
        [Video.Error.RMSE_insz.bp, Video.Error.Skill_insz.bp, Video.Error.Bias_insz.bp] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.bp, Video.x10)', [lim(1) lim(2)]);
        
        [Video.Error.RMSE_insz.comp_hErr, Video.Error.Skill_insz.comp_hErr, Video.Error.Bias_insz.comp_hErr] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_hErr, [lim(1) lim(2)]);
        [Video.Error.RMSE_insz.comp_gamma, Video.Error.Skill_insz.comp_gamma, Video.Error.Bias_insz.comp_gamma] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_gamma, [lim(1) lim(2)]);
        [Video.Error.RMSE_insz.comp_nlin, Video.Error.Skill_insz.comp_nlin, Video.Error.Bias_insz.comp_nlin] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_nlin, [lim(1) lim(2)]);
        [Video.Error.RMSE_insz.comp_CT, Video.Error.Skill_insz.comp_CT, Video.Error.Bias_insz.comp_CT] = calc_errors(Video.survey.z_interp, Video.composite.cbathyCT, [lim(1) lim(2)]);
        
        % Breaking region Stats
        [Video.Error.RMSE_break.cb, Video.Error.Skill_break.cb, Video.Error.Bias_break.cb] = calc_errors(Video.survey.z_interp, Video.cbathy.z_interp,[lim(2) lim(3)]);
        [Video.Error.RMSE_break.cb_hErr, Video.Error.Skill_break.cb_hErr, Video.Error.Bias_break.cb_hErr] = calc_errors(Video.survey.z_interp, Video.cbathy.cbathy_hErr,[lim(2) lim(3)]);
        [Video.Error.RMSE_break.cb_gamma, Video.Error.Skill_break.cb_gamma, Video.Error.Bias_break.cb_gamma] = calc_errors(Video.survey.z_interp, Video.cbathy.cbathy_gamma,[lim(2) lim(3)]);
        
        [Video.Error.RMSE_break.lin, Video.Error.Skill_break.lin, Video.Error.Bias_break.lin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.lin, Video.x10)', [lim(2) lim(3)]);
        [Video.Error.RMSE_break.nlin, Video.Error.Skill_break.nlin, Video.Error.Bias_break.nlin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.nlin, Video.x10)', [lim(2) lim(3)]);
        [Video.Error.RMSE_break.bp, Video.Error.Skill_break.bp, Video.Error.Bias_break.bp] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.bp, Video.x10)', [lim(2) lim(3)]);
        
        [Video.Error.RMSE_break.comp_hErr, Video.Error.Skill_break.comp_hErr, Video.Error.Bias_break.comp_hErr] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_hErr, [lim(2) lim(3)]);
        [Video.Error.RMSE_break.comp_gamma, Video.Error.Skill_break.comp_gamma, Video.Error.Bias_break.comp_gamma] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_gamma, [lim(2) lim(3)]);
        [Video.Error.RMSE_break.comp_nlin, Video.Error.Skill_break.comp_nlin, Video.Error.Bias_break.comp_nlin] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_nlin, [lim(2) lim(3)]);
        [Video.Error.RMSE_break.comp_CT, Video.Error.Skill_break.comp_CT, Video.Error.Bias_break.comp_CT] = calc_errors(Video.survey.z_interp, Video.composite.cbathyCT, [lim(2) lim(3)]);
        
        % Surfzone Stats
        [Video.Error.RMSE_sz.cb, Video.Error.Skill_sz.cb, Video.Error.Bias_sz.cb] = calc_errors(Video.survey.z_interp, Video.cbathy.z_interp,[lim(1) lim(3)]);
        [Video.Error.RMSE_sz.cb_hErr, Video.Error.Skill_sz.cb_hErr, Video.Error.Bias_sz.cb_hErr] = calc_errors(Video.survey.z_interp, Video.cbathy.cbathy_hErr,[lim(1) lim(3)]);
        [Video.Error.RMSE_sz.cb_gamma, Video.Error.Skill_sz.cb_gamma, Video.Error.Bias_sz.cb_gamma] = calc_errors(Video.survey.z_interp, Video.cbathy.cbathy_gamma,[lim(1) lim(3)]);
        
        [Video.Error.RMSE_sz.lin, Video.Error.Skill_sz.lin, Video.Error.Bias_sz.lin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.lin, Video.x10)', [lim(1) lim(3)]);
        [Video.Error.RMSE_sz.nlin, Video.Error.Skill_sz.nlin, Video.Error.Bias_sz.nlin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.nlin, Video.x10)', [lim(1) lim(3)]);
        [Video.Error.RMSE_sz.bp, Video.Error.Skill_sz.bp, Video.Error.Bias_sz.bp] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.bp, Video.x10)', [lim(1) lim(3)]);
        
        [Video.Error.RMSE_sz.comp_hErr, Video.Error.Skill_sz.comp_hErr, Video.Error.Bias_sz.comp_hErr] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_hErr, [lim(1) lim(3)]);
        [Video.Error.RMSE_sz.comp_gamma, Video.Error.Skill_sz.comp_gamma, Video.Error.Bias_sz.comp_gamma] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_gamma, [lim(1) lim(3)]);
        [Video.Error.RMSE_sz.comp_nlin, Video.Error.Skill_sz.comp_nlin, Video.Error.Bias_sz.comp_nlin] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_nlin, [lim(1) lim(3)]);
        [Video.Error.RMSE_sz.comp_CT, Video.Error.Skill_sz.comp_CT, Video.Error.Bias_sz.comp_CT] = calc_errors(Video.survey.z_interp, Video.composite.cbathyCT, [lim(1) lim(3)]);
        
        % Full Profile Stats
        [Video.Error.RMSE_full.comp_hErr, Video.Error.Skill_full.comp_hErr, Video.Error.Bias_full.comp_hErr] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_hErr, [1 5001]);
        [Video.Error.RMSE_full.comp_gamma, Video.Error.Skill_full.comp_gamma, Video.Error.Bias_full.comp_gamma] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_gamma, [1 5001]);
        [Video.Error.RMSE_full.comp_nlin, Video.Error.Skill_full.comp_nlin, Video.Error.Bias_full.comp_nlin] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_nlin, [1 5001]);
        [Video.Error.RMSE_full.comp_CT, Video.Error.Skill_full.comp_CT, Video.Error.Bias_full.comp_CT] = calc_errors(Video.survey.z_interp, Video.composite.cbathyCT, [1 5001]);
        
        % Offshore State
        [Video.Error.RMSE_offshore.comp_hErr, Video.Error.Skill_offshore.comp_hErr, Video.Error.Bias_offshore.comp_hErr] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_hErr, [lim(3) 5001]);
        [Video.Error.RMSE_offshore.comp_gamma, Video.Error.Skill_offshore.comp_gamma, Video.Error.Bias_offshore.comp_gamma] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_gamma, [lim(3) 5001]);
        [Video.Error.RMSE_offshore.comp_nlin, Video.Error.Skill_offshore.comp_nlin, Video.Error.Bias_offshore.comp_nlin] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_nlin, [lim(3) 5001]);
        [Video.Error.RMSE_offshore.comp_CT, Video.Error.Skill_offshore.comp_CT, Video.Error.Bias_offshore.comp_CT] = calc_errors(Video.survey.z_interp, Video.composite.cbathyCT, [lim(3) 5001]);
        
        

end