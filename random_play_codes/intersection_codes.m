%%
clear all   
cd /Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/
load('DATA/20211026_Torrey/01/data_up_until_GCP.mat', 'pc_new', 'intrinsics', 'cameraParams', 'extrinsicsInitialGuess')

load('colors.mat')

% Load LiDAR point cloud data (assuming it's in a PLY or XYZ format)
%lasReader=lasFileReader('CPG_data/20220817_00581_00590_NoWaves_TorreyCobble_P4RTK_epoch2010_geoid12b.las');
%lidarData = readPointCloud(lasReader);

loc = pc_new.Location;
col = pc_new.Color;

loc(:,1) = loc(:,1) - extrinsicsInitialGuess(1);
loc(:,2) = loc(:,2) - extrinsicsInitialGuess(2);
% 
% m=intrinsics(1);
% n=intrinsics(2);
% i_bounds = [0 .1*m; n .1*m; n m; 0 m];
% 
% [w_bounds] = distUV2XYZ(intrinsics,  [0 0 67 deg2rad(289) deg2rad(70) deg2rad(0)], i_bounds', 'z', zeros(1, size(i_bounds,1)));
% 
% [in,on] = inpolygon(loc(:,1), loc(:,2),[w_bounds(1:4,1); w_bounds(1,1)], [w_bounds(1:4,2); w_bounds(1,2)]);
% 
% pc_new = select(pc_new, in);
% loc = pc_new.Location;
% col = pc_new.Color;
% 
% loc(:,1) = loc(:,1) - extrinsicsInitialGuess(1);
% loc(:,2) = loc(:,2) - extrinsicsInitialGuess(2);

%%

K=cameraParams.Intrinsics.K
%Kinv=inv(K);
%t = [0 0 100]';
%R = eul2rotm(deg2rad([180 0 0]), 'XYZ')
%P = [10 5 0]';
% World to Pixel
%p = K * [R t] * [P; 1]; p = p/p(3)
% Pixel to World
%P_temp = inv(R) * Kinv * p + t

intrinsics(1) = cameraParams.ImageSize(2);            % Number of pixel columns
intrinsics(2) = cameraParams.ImageSize(1);            % Number of pixel rows
intrinsics(3) = cameraParams.PrincipalPoint(1);         % U component of principal point
intrinsics(4) = cameraParams.PrincipalPoint(2);          % V component of principal point
intrinsics(5) = cameraParams.FocalLength(1);         % U components of focal lengths (in pixels)
intrinsics(6) = cameraParams.FocalLength(2); 
%P=K * [R t]; P=P/P(3,4);
[P, K_cirn,R_cirn,t_cirn] = intrinsicsExtrinsics2P( intrinsics, [0 0 67 deg2rad(289) deg2rad(70) deg2rad(0)]); % looking nadir

[U,V]=meshgrid([1:cameraParams.ImageSize(2)], [1:cameraParams.ImageSize(1)]);
%%
X_c = (U(:) - K(1,3)) / K(1,1);
Y_c = (V(:) - K(2,3)) / K(2,2);
Z_c = ones(length(U(:)),1); % Assuming the point lies on the image plane
vec =(inv(R_cirn)*[X_c, Y_c, Z_c]')' ;
% Calculate the unit vector
unitVector = 1000000*vec/ norm(vec);

%%



% We will find the world coordinates atributed to each UV point using the
% Direct Linear Transformation Equations.
%       U = (Ax + By + Cz + D)/(Ex + Fy + Gz + 1);
%       V = (Hx + Jy + Kz + L)/(Ex + Fy + Gz + 1);

% Convert P to DLT Coefficients
A = P(1,1);
B = P(1,2);
C = P(1,3);
D = P(1,4);
E = P(3,1);
F = P(3,2);
G = P(3,3);
H = P(2,1);
J = P(2,2);
K = P(2,3);
L = P(2,4);
clear P

% Convert Coefficients to Rearranged Combined Coefficients For Solution
M = (E*U(:) - A);
N = (F*U(:) - B);
O = (G*U(:) - C);
P = (D - U(:));
Q = (E*V(:) - H);
R = (F*V(:) - J);
S = (G*V(:) - K);
T = (L - V(:));

Z =  zeros(length(U(:)),1);
X = ((N.*S - R.*O).*Z + (R.*P - N.*T))./(R.*M - N.*Q);
Y = ((M.*S - Q.*O).*Z + (Q.*P - M.*T))./(Q.*N - M.*R);

% Reformat into one Matrix
xyz = [X Y Z];

%%
figure(2);clf
plot3(0,0,-t_cirn(end), 'r.', 'MarkerSize', 30)
hold on
%scatter3(xyz(:,1), xyz(:,2), xyz(:,3))
%axis equal
xlabel('x')
ylabel('y')
%xlim([-200 10])
%ylim([-200 200])
%xlim([-100 -70])
grid on
scatter3(loc(:,1), loc(:,2), loc(:,3), 20,  double(pc_new.Color)/65535, 'filled')
%uu=unitVector(6504000:6505000,:);
uu=unitVector(1:10000:end,:);
%zlim([0 14])
%quiver3(zeros(length(uu),1), zeros(length(uu),1), -t_cirn(end)*ones(length(uu),1), uu(:,1), uu(:,2), uu(:,3))
%id=6503765
%quiver3(0,0, -t_cirn(end), unitVector(id,1), unitVector(id,2), unitVector(id,3), 'LineWidth', 2)

%surf(loc(:,1), loc(:,2), loc(:,3), double(pc_new.Color)/65535)
%%
%[x_grid, y_grid] = meshgrid([-150:0.1:-50],[-200:0.1:200]);
%z_grid = griddata(loc(:,1), loc(:,2), loc(:,3), x_grid, y_grid, 'nearest');
%pc_grid = pointCloud([x_grid(:) y_grid(:) z_grid(:)]);

%[mesh,depth,perVertexDensity] = pc2surfacemesh(pc_grid,"poisson");

%%


figure(10);clf
%quiver3(0,0, -t_cirn(end), 100*uu(id,1), 100*uu(id,2), 100*uu(id,3), 'LineWidth', 2)
scatter3(loc(:,1), loc(:,2), loc(:,3), 20,  double(pc_new.Color)/65535, 'filled')
hold on
%scatter3(ray_pts(1,:), ray_pts(2,:), ray_pts(3,:))
scatter3(loc(k,1), loc(k,2), loc(k,3), 40, 'r', 'filled')
%%
%id=6503765
tic

uu=unitVector./abs(unitVector(:,3));
k=NaN(1,length(unitVector));
depth=NaN(1,length(unitVector));
cP = NaN(length(unitVector),3);
for id = 1:100:length(unitVector)
    
    dist_cam = [50:100];
    ray_pts = [0 0 -t_cirn(end)]'+uu(id,:)'* dist_cam;
    ray_pts(:,ray_pts(3,:) < 0)=[];
    if ray_pts(1,end) > min(loc(:,1))
        % get all points along ray in 1m bins until z = 0 for 1st pass
        for ii = 1:length(ray_pts)
            [k_coarse(ii),dist_point(ii)] = dsearchn(loc,ray_pts(:,ii)');
        end
        if min(dist_point) < 5
            [~,k_ind] = min(dist_point);
            clear ray_pts
            ray_pts = [0 0 -t_cirn(end)]'+uu(id,:)'* [dist_cam(k_ind)-1:0.1:dist_cam(k_ind)+1];
            % search_area = loc; 
            % search_area(loc(:,1) > loc(k_coarse(k_ind),1) +10,:)=NaN;
            % search_area(loc(:,1) < loc(k_coarse(k_ind),1) -10,:)=NaN;
            % search_area(loc(:,2) > loc(k_coarse(k_ind),2) +10,:)=NaN;
            % search_area(loc(:,2) < loc(k_coarse(k_ind),2) -10,:)=NaN;
            for ii = 1:length(ray_pts)
                [k_fine(ii),dist_point(ii)] = dsearchn(loc,ray_pts(:,ii)');
               % [k_fine(ii),dist(ii)] = dsearchn(search_area,ray_pts(:,ii)');
            end
            [~,k_ind] = min(dist_point);
            k(id) = k_fine(k_ind);
            cP(id,:) = double(col(k(id),:))/65535;
            depth(id) = loc(k(id),3);
        end
    end
      
    id
end
%scatter3(loc(k,1), loc(k,2), loc(k,3), 100,  'b', 'filled')

%%
% Load your surface data (replace this with your surface data)
% Example: Create a surface (a sphere in this case)
[x, y, z] = sphere(20);
surfaceX = x(:);
surfaceY = y(:);
surfaceZ = z(:);

% Define the ray (origin and direction)
rayOrigin = [0, 0, 0]; % Ray origin (replace with your actual origin)
rayDirection = [1, 1, 1]; % Ray direction (replace with your actual direction)

% Calculate the intersection points using InterX
P = InterX([surfaceX, surfaceY, surfaceZ], ...
                                               [rayOrigin(1), rayOrigin(2), rayOrigin(3); ...
                                                rayOrigin(1) + rayDirection(1), ...
                                                rayOrigin(2) + rayDirection(2), ...
                                                rayOrigin(3) + rayDirection(3)]');

% Plot the surface and intersection points
figure;
surf(reshape(surfaceX, size(x)), reshape(surfaceY, size(y)), reshape(surfaceZ, size(z)), 'FaceAlpha', 0.5);
hold on;
scatter3(intersectX, intersectY, intersectZ, 'r', 'filled');
xlabel('X');
ylabel('Y');
zlabel('Z');
title('Intersection between Surface and Ray');

%%
[mesh,depth,perVertexDensity] = pc2surfacemesh(pc_new,"poisson");
xyzPoints = pc_new.Location;

% Set the parameters for Poisson surface reconstruction
gridResolution = 0.1; % Adjust this value based on your point cloud density
surfaceType = 'inversedistance'; % Options: 'ball-pivoting', 'barnacles', 'delanunay', 'distancemap', 'gp3', 'inversedistance', 'movingleast squares'

% Perform Poisson surface reconstruction
mesh = pc2mesh(xyzPoints, 'STL', surfaceType, 'GP3', gridResolution);

% Visualize the mesh
figure;
trisurf(mesh.Triangulation, mesh.X, mesh.Y, mesh.Z, 'FaceColor', 'cyan');
xlabel('X');
ylabel('Y');
zlabel('Z');
title('Mesh from 3D Point Cloud');
axis equal;
%% get SfM intersection points
id=28221;

% Define the line (P0 and V are 3D vectors)

% Define two points in 3D space
P0 = [0 0 67]; % First point
P1 = [xyz(id,:)]; % Second point

% Calculate the direction vector of the line
V = P1 - P0;
V_normalized = V / norm(V);


% Define scattered points (Nx3 matrix where N is the number of points)
points = loc; % Add your points here

% Initialize variables for storing closest point and minimum distance
closestPoint = [];
minDistance = Inf;

% Iterate through scattered points to find the closest point on the line
for i = 1:size(points, 1)
    % Calculate vector from the line point to the scattered point
    vecToPoint = points(i, :) - P0;
    
    % Calculate distance along the line using dot product
    distance = dot(vecToPoint, V_normalized);
    
    % Calculate the point on the line corresponding to the distance
    linePoint = P0 + distance * V_normalized;
    
    % Calculate the squared distance between the line point and scattered point
    squaredDistance = sum((linePoint - points(i, :)).^2);
    
    % Check if this is the closest point found so far
    if squaredDistance < minDistance
        minDistance = squaredDistance;
        closestPoint = linePoint;
    end
end

% closestPoint contains the coordinates of the closest point on the line to the scattered points
disp('Closest Point on the Line:');
disp(closestPoint);


