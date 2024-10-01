function [P,K,R] = makeP(az, tilt, roll, hfov, vfov, U0, V0, camxyz)
%
%   P = makeP(az, tilt, roll, hfov, vfov, U0, V0, camxyz)
%
% create a camera projection matrix for a synthetic camera with the
% following characteristics
%   tilt    - tilt angle in radians
%   az      - azimuth of view in compass degrees
%   roll    - roll in degrees
%   hfov    - horizontal field of view (radians)
%   vfov    - vertical field of view (radians)
%   U0      - U image center in pixels
%   V0      - V image center in pixels
%

% written by Holman on the Spanish coast, 05/30/06.
% updated 02/07/17


fU = U0 / tan(hfov/2);
fV = V0 / tan(vfov/2);
K = [fU    0     U0; ...
     0    -fV    V0; ...
     0     0      1];
R = angles2R(az, tilt, roll);
P = K * R * [eye(3) -camxyz(:)];  
P = P / P(3,4);

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
