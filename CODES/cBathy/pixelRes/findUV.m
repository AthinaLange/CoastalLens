function [U,V] = findUV( m, X )

% Usage:
%       [U,V] = findUV(m,X) 
%
%       returns image coordinates of real world coordinates
%
%       input:  m = the DLT coefficient vector A->L
%               X = [N,3] maxtrix (real world coords)
%       output: [U,V] = [N,2] array of image coordinates
%
%

% stolen from geometry5, reformatted to make it obvious

%  Check that the survey coordinates are valid
[N, M] = size(X);
if ((N == 3) & (M~=3))  % matrix transposed
        X = X';
end
if (size(X,2) ~= 3)
        error('Invalid survey coordinates entered into FindUV')
end

% check that m is valid
m = m(:);		% force to a column vector
if length(m) ~= 11 	% invalid geometry
        error('Invalid geometry supplied to findUV')
end

%  Carry out the equivalent vectorized calculation of
%       U = Ax + By + Cz + D / Ex + Fy + Gz + 1;
%       V = Hx + Jy + Kz + L / Ex + Fy + Gz + 1;

Xplus = [X ones(size(X,1),1)];

% !!! used to be rounded to ints! No!
U = ( Xplus * (m(1:4)) ./ (Xplus * [m(5:7);1]) );
V = ( Xplus * (m(8:11)) ./ (Xplus * [m(5:7);1]) );

%

%
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
%
%key support routines Argus CIL CIRN
%

