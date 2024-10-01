function R = resMapLocal(cA,X)
%       R = resMapLocal(camInfo,X)
%
%RESMAPLOCAL maps pixel resolution at a set of points in xyz space
%
%  Usage: R = resMap(camInfo,X)
%  Input:
%  X is (Nx3) locations of xyz points (right-hand coord.)
%  camInfo is a vector of camera info 
%    [azimuth tilt horzFOV NU NV camX camY camZ]
%    All angles are in radians, azimuth is measured CW from pos. y-axis,
%    and tilt is measured as 0 from neg. z-axis.
%  Output:
%  R is a structure with the fields (all in m/pixel units, out of range
%  values are indiated by NaNs):
%    daRange - along-range pixel footprint (azimuthal resolution) 
%    dcRange - cross-range pixel footprint (cross-azimuthal resolution)
%    daProj - maximum of alongshore projection of pixel footprint major axes
%    dcProj - maximum of cross-shore projection of pixel footprint major axes
%
%  The most likely information you want are the 'Proj' values, which are
%  the pixel along-azimuth and cross-azimuth footprints projected onto the
%  X and Y axes. 
%


az = pi/2 - cA(1); % camera corrected to math conventions
tl = pi - cA(2); % tilt
delH = cA(3)/cA(4); % delta horiz. fov
delV = delH;

% calculate resolution 
x = X(:,1) - cA(6);    
y = X(:,2) - cA(7);
z = X(:,3) - cA(8);
L = sqrt(x.^2 + y.^2 + z.^2);
H = sqrt(x.^2 + y.^2);
tau = atan(H./z);
theta = atan2(y,x);
daRange = abs(z).*(tan(tau + delH/2) - tan(tau - delH/2)); % range resolution
dcRange = 2*L*tan(delV/2); % cross-range resolution
dcProj = max(abs([daRange.*cos(theta) dcRange.*cos(pi/2-theta)]),[],2); % cross-axis (cross-shore) resolution % axis projection
daProj = max(abs([dcRange.*cos(theta) daRange.*cos(pi/2-theta)]),[],2); % along-axis (alongshore) resolution % axis projection

% create the projection matrix, then the m-vector
cxyz = cA(6:8);
NU = cA(4); NV = cA(5);
P = makeP(cA(1),cA(2),0,cA(3),cA(3)*NV/NU,NU/2,NV/2, cxyz);
% out of view calculation
[U,V] = findUV(P2m(P),X);
mask = nan*ones(size(X,1),1);
gind = find(U>10 & U<(cA(4)-10) & V>10 & V<(cA(5)-10));
mask(gind) = 1;

% output data
R.dcRange = dcRange.*mask;
R.daRange = daRange.*mask;
R.dcProj = dcProj.*mask;
R.daProj = daProj.*mask;


%   Copyright (C) 2017  Coastal Imaging Research Network
%                       and Oregon State University

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

% CIRN: https://coastal-imaging-research-network.github.io/
% CIL:  http://cil-www.coas.oregonstate.edu
