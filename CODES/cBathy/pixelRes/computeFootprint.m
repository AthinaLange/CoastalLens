function [XYZVertices, res, dcRange, daRange, dcProj, daProj] = computeFootprint(hfov, vfov, az, tilt, roll, NU, NV, cxyz, txyz)
%% This code computes the camera footprint based on the following inputs:
% az: camera azimuth (size of az corresponds to the number of cameras)
% hfov: horizontal field of view (deg.)
% vfov: vertical field of view (deg.)
% tilt: camera tilt (deg.)
% roll: camera roll, typically assumed to be zero deg.
% NU: The width of the chip or sensor in pixels
% NV: The height of the chip or sensor, in pixels 
% cxyz: [x,y,z] position of the camera, assumed to be [0,0,cz] where cz is
% the camera elevation relative to the target projection elevation, txyz
% txyz: Target projection position, as a hack assumed to be [0,0,0],


% Calculate footprint for each camera
for ii = 1:size(az,2)
    %XYZVerticies are the 4 corners of the image projected into coordinates
    % in m relative to the camera location.
    % P is the camera projection matrix, K is the intrinsic camera matrix.
    [XYZVertices{ii}, P{ii},K{ii}] = FOVFootprint(hfov*pi/180,vfov*pi/180,az(ii)*pi/180, tilt*pi/180,roll*pi/180, NU,NV, cxyz,txyz);
    % res is a stucture with along range and cross range resolution
    res{ii} = makeResMapLocal([az(ii)*pi/180,tilt*pi/180,hfov*pi/180,NU,NV, cxyz(1),cxyz(2), cxyz(3)],[cxyz(1)-1000 cxyz(1)+1000 cxyz(2)-1000 cxyz(2)+1000 1 1 0]);
    
end

% pull out ranges from structures
for ii = 1:size(az,2)
    dcRange(:,:,ii) = res{ii}.dcRange;
    daRange(:,:,ii) = res{ii}.daRange;
    dcProj(:,:,ii) = res{ii}.dcProj;
    daProj(:,:,ii) = res{ii}.daProj;
end

end


%%
%    Developed at Naval Research Laboratory, Stennis Space Center (2019)
%    Public Release Number: 19-1231-0203
%
%    This program is free software: you can redistribute it and/or  
%    modify it under the terms of the GNU General Public License as 
%    published by the Free Software Foundation, version 3 of the 
%    License.

%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.

%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see
%                                <http://www.gnu.org/licenses/>.
%