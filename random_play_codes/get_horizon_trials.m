%% get_horizon




















%%

lim = 50;
%I_horizon = I(lim:end-lim,lim:end-lim,:);

Igray = rgb2gray(I(lim:end-lim,lim:end-lim,:));%(50:end-50, 50:end-50,:));
I_horizon = medfilt2(Igray, [1, 50]);

level = graythresh(I_horizon)

BW = imbinarize(I,level_close);

%SE = strel("square",9)
%level_close = imclose(level, SE )

imshowpair(I_horizon, BW, 'montage')



x = [1 size(I_horizon,2)]
%aa = max(find(level_close(:,x(1)) == ))



%% Horizon tracking 
% - take into account when no horizon in the picture
% - take into account when foggy and no clear horizon available
% - take into account when horizon no longer visible / or reappears
% 
% Make array of horizon line for every time, and fill with NaNs if not
% available - can then be used for least squares fitting regardless
% 

%% Horizon tracking - gradients
% TODO CHECK IF BETTER WAY HERE
% still need to find gradient position

% to account for black pixels when undistorting Image
lim = 50;
%I_horizon = I(lim:end-lim,lim:end-lim,:);

Igray = rgb2gray(I(lim:end-lim,lim:end-lim,:));%(50:end-50, 50:end-50,:));
I_horizon = medfilt2(Igray, [1, 50]);

for ii = size(I_horizon,2):-1:1
    if any(I_horizon(:,ii,:)== 0)
       I_horizon(:,ii,:)=[];
    end
end

left_I = I_horizon(:,1:50,:);
right_I = I_horizon(:,end-49:end,:);

left_mean = mean(left_I,2);
left_grad = smoothdata(diff(left_mean), 'Gaussian', 100);
right_mean = mean(right_I,2);
right_grad = smoothdata(diff(right_mean), 'Gaussian', 200);

y = [1:length(left_I)];%[lim:size(I,1)-lim];
%left_max_smooth = islocalmax(abs(left_grad));% left_max_smooth = y(left_max_smooth);
%left_max = islocalmax(abs(diff(left_mean))); %left_max = y(left_max);
left_max_smooth = islocalmin(left_grad);
left_max = islocalmin(diff(left_mean)); 

%k = dsearchn(P,PQ)

%%

tiledlayout(2,3)
ax1 = nexttile
image([1:50], [1:length(left_I)], left_I)
ylim([1 length(left_I)])

ax2 = nexttile
image([1], [1:length(left_I)], mean(left_I,2))
hold on
plot(left_grad/5+1, [1:length(left_grad)], 'k', 'LineWidth', 3)
plot(left_grad(left_max)/5+1, y(left_max), 'g*')
plot(left_grad(left_max_smooth)/5+1, y(left_max_smooth), 'r*')
plot([1 1], [1 3000], 'k')
%xlim([-1 3])

ax3 = nexttile
plot(sum(left_I,2),[1:length(left_I)])
hold on
plot(left_grad*500, [1:length(left_grad)])
plot([0 0], [1 3000], 'k')
ylim([1 length(left_I)])
set(gca, 'YDir', 'reverse')
linkaxes([ax1 ax2 ax3],'y')

ax1 = nexttile
image([1:50], [1:length(right_I)], right_I)
ylim([1 length(right_I)])

ax2 = nexttile
image([1], [1:length(right_I)], mean(right_I,2))
hold on
plot(right_grad/5+1, [1:length(right_grad)], 'k', 'LineWidth', 3)
plot([1 1], [1 3000], 'k')
%xlim([-1 3])

ax3 = nexttile
plot(sum(right_I,2),[1:length(right_I)])
hold on
plot(right_grad*500, [1:length(right_grad)])
plot([0 0], [1 3000], 'k')
ylim([1 length(right_I)])
set(gca, 'YDir', 'reverse')
linkaxes([ax1 ax2 ax3],'y')

%%
figure(1);clf;image(I_horizon)
hold on
%plot([1 3730], [174 156], 'k', 'LineWidth', 4)
plot([1 3840], [200 167], 'k', 'LineWidth', 3)


%% Horizon tracking - Ettinger et al. 2003
% doing water and sky as the two parts
tot_pix = size(I,1)*size(I,2);
phi = [-5:1:5]; % roll angle
sig = [50:1:99]/100; % amount of image below horizon line
for pp = 1:length(phi)
    for ss = 1:length(sig)

% figure(1);clf
% image(I)
% hold on
m = tand(phi(pp));
b = intrinsics(2)*(1-sig(ss));
line = m*[1:intrinsics(1)] + b;
%plot([1:intrinsics(1)], line , 'k', 'LineWidth', 2)
sub_pix = sum(line);
j=0;

while round(1 - sub_pix/tot_pix,3) ~= sig % while percentage of picture is ground is incorrect
    j = j+1;
    if (1 - sub_pix/tot_pix) < sig(ss) % line too low
        b = intrinsics(2)*(1-sig(ss))-j;
    elseif (1 - sub_pix/tot_pix) > sig(ss)  % line too high
        b = intrinsics(2)*(1-sig(ss))+j;
    end
    line = m*[1:intrinsics(1)] + b;
    %plot([1:intrinsics(1)], line, 'r', 'LineWidth', 1)
    sub_pix = sum(line);
end
    %plot([1:intrinsics(1)], line, 'g', 'LineWidth', 1)

% extract sky and water pixels

I_sky = I;
I_water = I;
for ww = 1:width
    if round(line(ww)) > 0
        I_sky(round(line(ww)):end,ww,:) = NaN;
        I_water(1:round(line(ww)),ww,:) = NaN;
    else
        I_sky(:,ww,:)=NaN;
    end
end

I_sky = reshape(I_sky, [], 3); 
I_water = reshape(I_water, [], 3);

x_sky = double(I_sky(~all(I_sky == 0,2),:));
x_water = double(I_water(~all(I_water == 0,2),:));

u_s = round(mean(x_sky));
u_w = round(mean(x_water));

cov_s = cov(x_sky);
cov_w = cov(x_water);

gamma_s = eig(cov_s');
gamma_w = eig(cov_w');

J(pp,ss) = 1./(det(cov_s) + det(cov_w) + (sum(gamma_s))^2 + (sum(gamma_w))^2);
    end
end

figure(3);clf
subplot(121)
[p,s]=meshgrid(sig, phi);
pcolor(p,s,J)
hold on
colorbar
[m,i]=find(max(J(:))==J);
plot(sig(i),phi(m), 'k', 'Marker', 'pentagram', 'MarkerSize', 30, 'MarkerFaceColor', 'r')
xlabel('Percentage of image Ground')
ylabel('Roll angle')

subplot(122)
image(I)
hold on
m = tand(phi(m));
b = intrinsics(2)*(1-sig(i));
line = m*[1:intrinsics(1)] + b;
plot([1:intrinsics(1)], line , 'g', 'LineWidth', 2)

%% Horizon tracking - watershed algorithm

cd('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01')
I=imread('Processed_data/undistortImage.png');
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IOEOInitial.mat', 'intrinsics')

%II=imread('Leo/DJI_0156.JPG');
%%

Igray = rgb2gray(I);%(50:end-50, 50:end-50,:));
filteredImage = medfilt2(Igray, [50, 50]);
gradientMagnitude = imgradient(filteredImage, 'Sobel');
grad_curve = smoothdata(sum(gradientMagnitude'), 'Gaussian', 50);
y=[1:size(Igray,1)];
aa=islocalmax(grad_curve);
%%

I_maxes = 256*ones(2160, 3840);
I_maxes(1:140,:) = filteredImage(1:140,:);
L = watershed(I_maxes);

%%

maxes = y(aa);
sky_pt = [intrinsics(1)/2 maxes(1)/2];
water_pt = [2500 500] % use grid projection to get water point
%%

figure(1);clf
subplot(121)
image(filteredImage)
hold on
plot(sky_pt(1), sky_pt(2), 'r.', 'MarkerSize',30)
plot(water_pt(1), water_pt(2), 'r.', 'MarkerSize',30)
%image(imgradient(Igray))
ylim([1 2160])
colormap gray

subplot(122)
%plot(sum(Igray'), [1:2160])
%hold on

%plot(sum(filteredImage'), [1:2160])
%plot(diff(sum(filteredImage')), [1:2160-1])
plot(grad_curve,y, grad_curve(aa), y(aa), 'r*')
set(gca, 'YDir', 'reverse')
ylim([1 2160])

%% Horizon tracking - Hough Transform

cd('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01')
I=imread('Processed_data/undistortImage.png');
load('/Users/athinalange/Desktop/DATA/Work/UAV_rectification/Athina_Automated_rectification/DATA/20211026_Torrey/01/Processed_data/20211026_Torrey_01_IOEOInitial.mat', 'intrinsics')

%II=imread('Leo/DJI_0156.JPG');
%%
originalImage=I;
Igray = rgb2gray(originalImage);%(50:end-50, 50:end-50,:));
filteredImage = edge(Igray,'sobel',[]);%medfilt2(Igray, [1, 100]);
figure(1);clf
imshowpair(Igray,filteredImage, 'montage')
[H,T,R] = hough(filteredImage);
figure(4);clf
imshow(H,[],'XData',T,'YData',R,...
            'InitialMagnification','fit');
xlabel('\theta'), ylabel('\rho');
axis on, axis normal, hold on;

P  = houghpeaks(H,10,'threshold',ceil(0.3*max(H(:))));
x = T(P(:,2)); y = R(P(:,1));
plot(x,y,'s','color','red');


lines = houghlines(filteredImage,T,R,P,'FillGap',5,'MinLength',10);
figure(5);clf; imshow(filteredImage), hold on
max_len = 0;
for k = 1:length(lines)
   xy = [lines(k).point1; lines(k).point2];
   plot(xy(:,1),xy(:,2),'LineWidth',2,'Color','green');

   % Plot beginnings and ends of lines
   plot(xy(1,1),xy(1,2),'x','LineWidth',2,'Color','yellow');
   plot(xy(2,1),xy(2,2),'x','LineWidth',2,'Color','red');

   % Determine the endpoints of the longest line segment
   len = norm(lines(k).point1 - lines(k).point2);
   if ( len > max_len)
      max_len = len;
      xy_long = xy;
   end
end