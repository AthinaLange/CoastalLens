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

%%
%%% Compute h avg
af=find(~isnan(nanmean(h_crest_lin,2)));

smooth_factor = 25*10;
% 25m Gaussian smoothing after averaging
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
h_crest_lin_avg = (-h_crest_lin_avg) + Video.tide;
h_crest_nlin_avg = (-h_crest_nlin_avg) + Video.tide;
h_crest_bp_avg = (-h_crest_bp_avg) + Video.tide;

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
    xshift =(id2-id(1));
else % when predicted bathy does reach min tide
    [~,ab]=min(abs(h_crest_bp_avg-min_tide));
    [~,ac]=min(abs(Video.survey.z-min_tide));
    xshift = ac-ab;%ab-ac;
    clear ab ac
end

%xshift = 0;
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
%%
%%% x-shift to match subaerial surveys
id = find(~isnan(Video.cbathy.z_interp)==1); % find first non-nan of predicted bathy
if isempty(id)
    xshift = NaN;
elseif Video.cbathy.z_interp(id(1)) < min_tide % if predicted bathy doesn't reach to min tide
    [~,id2]=min(abs((Video.cbathy.z_interp(id(1)))-Video.survey.z));
    xshift =(id2-id(1));
else % when predicted bathy does reach min tide
    [~,ab]=min(abs(Video.cbathy.z_interp-min_tide));
    [~,ac]=min(abs(Video.survey.z_interp-min_tide));
    xshift = ac-ab;
    clear ab ac
end
Video.cbathy.xshift = xshift;
%%% Mean gamma(x)

gamma = zeros(length(Video.x10),length(Video.bp));
for bb = 1:length(Video.bp)
    if Video.bp(bb) == size(Video.x10, 1)
        gamma(:,bb)=NaN;
    elseif isnan(Video.bp(bb))
        gamma(:,bb)=NaN;
    else
        gamma(1:size(Video.x10, 1)-Video.bp(bb),bb) = 0.42;
    end
end
gamma(:,isnan(gamma(1,:)))=[];
Video.ct.gamma = gamma;
Video.ct.gamma_mean = mean(gamma,2, 'omitnan');

%%
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

% [Video] = create_composite_bathys(Video, gamma_H);

window = (50/2)/0.1;
%% Remove any cBathy hErr > 0.5 and interp
Video.cbathy.cbathy_hErr = Video.cbathy.z_interp_m;
Video.cbathy.cbathy_hErr(Video.cbathy.zerr_interp_m > 0.5) = NaN;
x10_temp=Video.x10;
x10_temp(isnan(Video.cbathy.cbathy_hErr))=[];Video.cbathy.cbathy_hErr(isnan(Video.cbathy.cbathy_hErr))=[];
if ~isempty(x10_temp)
    Video.cbathy.cbathy_hErr_m = interp1(x10_temp, Video.cbathy.cbathy_hErr, Video.x10);
else
    Video.cbathy.cbathy_hErr_m = NaN(size(Video.x10,1), size(Video.x10,2));
end
%% Foreshore Beach
date = Video.date;
tide = Video.min_tide;
x = Video.x10';
z = Video.survey.z_interp_m';
[~,id]=min(abs(z-tide)); % find when bathy reaches low tide line
x(id+1:end)=[]; % only foreshore
z(id+1:end)=[];
x_upper = x'; z_upper = z;
x_upper(isnan(z_upper))=[];z_upper(isnan(z_upper))=[];

%% BP Composite
gamma_profile = Video.ct.gamma_mean; % Not applying xshift because was computed from unshift data - cBathy also unshifted
if isnan(mean(gamma_profile, 'omitnan'))
    id_ocean_ct = NaN;
    id_ocean_cb = NaN;
else
    aa = find(min(abs(gamma_profile-(gamma-0.01)))==abs(gamma_profile-(gamma-0.01)));
    id_shore = aa(end); % onshore
    aa = find(round(gamma_profile,2)==0);
    if isempty(aa)
        aa = find(round(gamma_profile,2)==min(round(gamma_profile,2)));
    end
    id_ocean_ct = aa(1)+window/2;
    id_ocean_cb = aa(1)+window*5;
end

id_sz = 0; id_cb = 0;
% Surfzone bathy
x_sz = Video.x10; z_sz = smoothdata(interp1(Video.x5, Video.ct.h_avg.bp, Video.x10), 'Gaussian', window);
z_sz(1:find(max(x_upper)==x_sz)) = NaN; % find how far offshore subaerial survey region is valid
if isnan(id_ocean_ct); id_ocean_ct = size(Video.x10,1);end
z_sz(id_ocean_ct:end) = NaN; % remove anything further offshore then beginning of breaking + cBathy buffer
x_sz(isnan(z_sz)) = []; z_sz(isnan(z_sz)) = [];
if ~isempty(x_sz)
    shore_id = x_sz(1);
    % if overlap between subaerial and crest-tracking -> prioritize subaerial survey
    if x_sz(1) < x_upper(end)
        [~,ii]=min(abs(x_sz - x_upper(end)));
        x_sz(1:ii)=[]; z_sz(1:ii)=[];
    end
    id_sz = 1;
else
    shore_id = NaN;%id_shore/10;
end

% Offshore bathy
x_cb = Video.x10;
z_cb = Video.cbathy.cbathy_hErr_m;
if isnan(id_ocean_cb)
    try
        id_ocean_cb = max([min(find(~isnan(z_cb)==1)) find(x_sz(end)==x_cb)]);
    catch
        id_ocean_cb = 1;
    end
end
z_cb(1:id_ocean_cb) = NaN;
x_cb(isnan(z_cb)) = []; z_cb(isnan(z_cb)) = [];
if ~isempty(x_sz); x_cut = x_sz(end); else; x_cut = x_upper(end);end
if ~isempty(x_cb)
    if x_cb(1) < x_cut
        [~,ii]=min(abs(x_cb - x_cut));
        x_cb(1:ii)=[]; z_cb(1:ii)=[];
    end
    id_cb = 1;
end

% combine subaerial survey, BP crest-tacking, and cBathy
if isrow(x_upper); x_upper = x_upper'; end
if isrow(x_sz); x_sz = x_sz'; end
if isrow(x_cb); x_cb = x_cb'; end
x = [x_upper' x_sz' x_cb'];
if isrow(z_upper); z_upper = z_upper'; end
if isrow(z_sz); z_sz = z_sz'; end
if isrow(z_cb); z_cb = z_cb'; end
z = [z_upper' z_sz' z_cb'];
%%
Video.composite.cbathyCT = smoothdata(interp1(x, z, Video.x10),'Gaussian', window);
% runupline = InterX([Video.x10';Video.composite.cbathyCT'],[x_upper';z_upper']); % coppect for smoothing issue; find intersection point between upper beach and smoothed curve
% if ~isempty(runupline)
%     [~,i1]=min(abs(x_upper-runupline(1,1)));
%     [~,i2]=min(abs(Video.x10-runupline(1,1)));
%     x = [x_upper(1:i1); Video.x10(i2+1:end)];
%     z = [z_upper(1:i1); Video.composite.cbathyCT(i2+1:end)];
%     Video.composite.stitch.cbathyCT_beach = x_upper(i1);
% end
% Video.composite.cbathyCT = interp1(x, z, Video.x10);
%
% if ~isempty(x_cb) &&  ~isnan(x_cb(1))
%     Video.composite.stitch.cbathyCT_offshore = x_cb(1);
% elseif ~isempty(x_sz) &&  ~isnan(x_sz(end))
%     Video.composite.stitch.cbathyCT_offshore = x_sz(end);
% end
%
% index of [1st BP valid onshore point, onshore cutoff of breaking, offshore cutoff of breaking]
% Video.lims = (round([shore_id*2; id_shore; id_ocean]));
% if id_sz == 1; Video.check.CT = 'Yes'; else Video.check.CT = 'No';end
% if id_cb == 1; Video.check.cBathy = 'Yes'; else Video.check.cBathy = 'No';end
%
%
%         %%% Variable surfzone RMSE
%         lim = Video.lims;
%         %%
%         % Inner Surfzone Stats
%         [Video.Error.RMSE_insz.cb, Video.Error.Skill_insz.cb, Video.Error.Bias_insz.cb] = calc_errors(Video.survey.z_interp, Video.cbathy.z_interp,[lim(1) lim(2)]);
%         [Video.Error.RMSE_insz.cb_gamma, Video.Error.Skill_insz.cb_gamma, Video.Error.Bias_insz.cb_gamma] = calc_errors(Video.survey.z_interp, Video.cbathy.cbathy_gamma,[lim(1) lim(2)]);
%
%         [Video.Error.RMSE_insz.lin, Video.Error.Skill_insz.lin, Video.Error.Bias_insz.lin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.lin, Video.x10)', [lim(1) lim(2)]);
%         [Video.Error.RMSE_insz.nlin, Video.Error.Skill_insz.nlin, Video.Error.Bias_insz.nlin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.nlin, Video.x10)', [lim(1) lim(2)]);
%         [Video.Error.RMSE_insz.bp, Video.Error.Skill_insz.bp, Video.Error.Bias_insz.bp] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.bp, Video.x10)', [lim(1) lim(2)]);
%
%         [Video.Error.RMSE_insz.comp_hErr, Video.Error.Skill_insz.comp_hErr, Video.Error.Bias_insz.comp_hErr] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_hErr, [lim(1) lim(2)]);
%         [Video.Error.RMSE_insz.comp_gamma, Video.Error.Skill_insz.comp_gamma, Video.Error.Bias_insz.comp_gamma] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_gamma, [lim(1) lim(2)]);
%         [Video.Error.RMSE_insz.comp_nlin, Video.Error.Skill_insz.comp_nlin, Video.Error.Bias_insz.comp_nlin] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_nlin, [lim(1) lim(2)]);
%         [Video.Error.RMSE_insz.comp_CT, Video.Error.Skill_insz.comp_CT, Video.Error.Bias_insz.comp_CT] = calc_errors(Video.survey.z_interp, Video.composite.cbathyCT, [lim(1) lim(2)]);
%
%         % Breaking region Stats
%         [Video.Error.RMSE_break.cb, Video.Error.Skill_break.cb, Video.Error.Bias_break.cb] = calc_errors(Video.survey.z_interp, Video.cbathy.z_interp,[lim(2) lim(3)]);
%         [Video.Error.RMSE_break.cb_hErr, Video.Error.Skill_break.cb_hErr, Video.Error.Bias_break.cb_hErr] = calc_errors(Video.survey.z_interp, Video.cbathy.cbathy_hErr,[lim(2) lim(3)]);
%         [Video.Error.RMSE_break.cb_gamma, Video.Error.Skill_break.cb_gamma, Video.Error.Bias_break.cb_gamma] = calc_errors(Video.survey.z_interp, Video.cbathy.cbathy_gamma,[lim(2) lim(3)]);
%
%         [Video.Error.RMSE_break.lin, Video.Error.Skill_break.lin, Video.Error.Bias_break.lin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.lin, Video.x10)', [lim(2) lim(3)]);
%         [Video.Error.RMSE_break.nlin, Video.Error.Skill_break.nlin, Video.Error.Bias_break.nlin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.nlin, Video.x10)', [lim(2) lim(3)]);
%         [Video.Error.RMSE_break.bp, Video.Error.Skill_break.bp, Video.Error.Bias_break.bp] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.bp, Video.x10)', [lim(2) lim(3)]);
%
%         [Video.Error.RMSE_break.comp_hErr, Video.Error.Skill_break.comp_hErr, Video.Error.Bias_break.comp_hErr] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_hErr, [lim(2) lim(3)]);
%         [Video.Error.RMSE_break.comp_gamma, Video.Error.Skill_break.comp_gamma, Video.Error.Bias_break.comp_gamma] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_gamma, [lim(2) lim(3)]);
%         [Video.Error.RMSE_break.comp_nlin, Video.Error.Skill_break.comp_nlin, Video.Error.Bias_break.comp_nlin] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_nlin, [lim(2) lim(3)]);
%         [Video.Error.RMSE_break.comp_CT, Video.Error.Skill_break.comp_CT, Video.Error.Bias_break.comp_CT] = calc_errors(Video.survey.z_interp, Video.composite.cbathyCT, [lim(2) lim(3)]);
%
%         % Surfzone Stats
%         [Video.Error.RMSE_sz.cb, Video.Error.Skill_sz.cb, Video.Error.Bias_sz.cb] = calc_errors(Video.survey.z_interp, Video.cbathy.z_interp,[lim(1) lim(3)]);
%         [Video.Error.RMSE_sz.cb_hErr, Video.Error.Skill_sz.cb_hErr, Video.Error.Bias_sz.cb_hErr] = calc_errors(Video.survey.z_interp, Video.cbathy.cbathy_hErr,[lim(1) lim(3)]);
%         [Video.Error.RMSE_sz.cb_gamma, Video.Error.Skill_sz.cb_gamma, Video.Error.Bias_sz.cb_gamma] = calc_errors(Video.survey.z_interp, Video.cbathy.cbathy_gamma,[lim(1) lim(3)]);
%
%         [Video.Error.RMSE_sz.lin, Video.Error.Skill_sz.lin, Video.Error.Bias_sz.lin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.lin, Video.x10)', [lim(1) lim(3)]);
%         [Video.Error.RMSE_sz.nlin, Video.Error.Skill_sz.nlin, Video.Error.Bias_sz.nlin] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.nlin, Video.x10)', [lim(1) lim(3)]);
%         [Video.Error.RMSE_sz.bp, Video.Error.Skill_sz.bp, Video.Error.Bias_sz.bp] = calc_errors(Video.survey.z_interp, interp1(Video.x5, Video.ct.h_avg.bp, Video.x10)', [lim(1) lim(3)]);
%
%         [Video.Error.RMSE_sz.comp_hErr, Video.Error.Skill_sz.comp_hErr, Video.Error.Bias_sz.comp_hErr] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_hErr, [lim(1) lim(3)]);
%         [Video.Error.RMSE_sz.comp_gamma, Video.Error.Skill_sz.comp_gamma, Video.Error.Bias_sz.comp_gamma] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_gamma, [lim(1) lim(3)]);
%         [Video.Error.RMSE_sz.comp_nlin, Video.Error.Skill_sz.comp_nlin, Video.Error.Bias_sz.comp_nlin] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_nlin, [lim(1) lim(3)]);
%         [Video.Error.RMSE_sz.comp_CT, Video.Error.Skill_sz.comp_CT, Video.Error.Bias_sz.comp_CT] = calc_errors(Video.survey.z_interp, Video.composite.cbathyCT, [lim(1) lim(3)]);
%
%         % Full Profile Stats
%         [Video.Error.RMSE_full.comp_hErr, Video.Error.Skill_full.comp_hErr, Video.Error.Bias_full.comp_hErr] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_hErr, [1 5001]);
%         [Video.Error.RMSE_full.comp_gamma, Video.Error.Skill_full.comp_gamma, Video.Error.Bias_full.comp_gamma] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_gamma, [1 5001]);
%         [Video.Error.RMSE_full.comp_nlin, Video.Error.Skill_full.comp_nlin, Video.Error.Bias_full.comp_nlin] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_nlin, [1 5001]);
%         [Video.Error.RMSE_full.comp_CT, Video.Error.Skill_full.comp_CT, Video.Error.Bias_full.comp_CT] = calc_errors(Video.survey.z_interp, Video.composite.cbathyCT, [1 5001]);
%
%         % Offshore State
%         [Video.Error.RMSE_offshore.comp_hErr, Video.Error.Skill_offshore.comp_hErr, Video.Error.Bias_offshore.comp_hErr] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_hErr, [lim(3) 5001]);
%         [Video.Error.RMSE_offshore.comp_gamma, Video.Error.Skill_offshore.comp_gamma, Video.Error.Bias_offshore.comp_gamma] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_gamma, [lim(3) 5001]);
%         [Video.Error.RMSE_offshore.comp_nlin, Video.Error.Skill_offshore.comp_nlin, Video.Error.Bias_offshore.comp_nlin] = calc_errors(Video.survey.z_interp, Video.composite.cbathy_nlin, [lim(3) 5001]);
%         [Video.Error.RMSE_offshore.comp_CT, Video.Error.Skill_offshore.comp_CT, Video.Error.Bias_offshore.comp_CT] = calc_errors(Video.survey.z_interp, Video.composite.cbathyCT, [lim(3) 5001]);
%


end