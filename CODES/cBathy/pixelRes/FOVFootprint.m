function [XYZ,P,K] = FOVFootprint(hfov,vfov,az,tilt,roll,NU,NV,cxyz,txyz)
%
% Function used to determine the image corners based on the camera
% parameters. 
% Output is keystone shape.

U0 = NU/2;  %use chip resolution to estimate principle point for use in makeP
V0 = NV/2;

[P,K,~] = makeP(az, tilt, roll, hfov, vfov, U0, V0, cxyz);

m = [P(1,:) P(3,1:3) P(2,:)];
UVList = [1 1; NU 1; NU NV; 1 NV];
XYZ_orig = findXYZ(m, UVList, txyz(3), 3);

if (vfov/2 + tilt) > pi/2
    %Wrapping! (camera field of view extends above horizon)
    tilt = deg2rad(90) - vfov/2 - deg2rad(.5);
    [P,K,~] = makeP(az, tilt, roll, hfov, vfov, U0, V0, cxyz);
    m = [P(1,:) P(3,1:3) P(2,:)];
    UVList = [1 1; NU 1; NU NV; 1 NV];
    XYZ_new = findXYZ(m, UVList, txyz(3), 3);
    XYZ = [XYZ_new(1:2,:); XYZ_orig(3:4,:)];
else
    %No wrapping
    XYZ = XYZ_orig;
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