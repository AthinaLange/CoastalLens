%% get_origin
function [origin_grid] = get_origin(Mopnum)


load('/Users/athinalange/Desktop/DATA/Work/RS_Bathy/CODES/helperFunctions/MOPS_toolbox/MopTableUTM.mat')
origin_grid = [Mop.BackLat(Mopnum) Mop.BackLon(Mopnum) Mop.Normal(Mopnum)];