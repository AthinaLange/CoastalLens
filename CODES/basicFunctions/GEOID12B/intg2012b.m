function [zgeoid] = intg2012b(code_dir, xlat, xlon)
%% function [zgeoid] = intg(xlat, xlon, pc_id);
%
%	xlat = decimal latitude
%	xlon = decimal longitude (positive EAST)


%xlat = 32.75;      DEBUG
%xlon = -117.25;    DEBUG
xlon = 360. + xlon;
npts = length(xlat);

%% - Which directory are the geoid files in? 

dirnam = fullfile(code_dir, 'basicFunctions', 'GEOID12B');


%% - Create the list of files that must be opened,
%% - and open them.  Return with a count of how
%% - many files were opened, and a flag (ios)
%% - of which files are open and which are not.
[nfiles, lin, nff, ios] = files_intg(dirnam);

glamn = zeros(1,nfiles);
glamx = zeros(1,nfiles);
glomn = zeros(1,nfiles);
glomx = zeros(1,nfiles);

dla = zeros(1,nfiles);
dlo = zeros(1,nfiles);
nla = zeros(1,nfiles);
nlo = zeros(1,nfiles);

%% - Read the headers of all geoid files which
%% - where opened, and store that information.
 
for i=1:nfiles
	if (ios == 0) 

%	  	[A, na] = fread(lin(i), 4, 'float64');  %Old GEOID99 version
	  	[A, na] = fread(lin(i), 4, 'double','l');
          	glamn(i) = A(1);  %% minimum latitude
          	glomn(i) = A(2);  %% minimum longitude
          	dla(i)   = A(3); %% delta latitude
          	dlo(i)   = A(4); %% delta longitude
%	  	[B, nb] = fread(lin(i), 3, 'int32');    %Old GEOID99 version
	  	[B, nb] = fread(lin(i), 3, 'long','l');
	  	nla(i) = B(1);   %% number of latitudes
	  	nlo(i) = B(2);   %% number of longitudes
	  	ikind = B(3);
	
          	glamx(i) = glamn(i) + (nla(i)-1)*dla(i);   %% maximum latitude
          	glomx(i) = glomn(i) + (nlo(i)-1)*dlo(i);   %% minimum longitude

	end
end

%% - Find which geoid file to use, based on the lat/lon input
kval = zeros(1,npts);
for n=1:npts
	if n==1, [k] = which1_intg(xlat, xlon, nfiles, glamn, glamx, glomn, glomx, dla, dlo, nla, nlo, ios); end
	kval(n) = k;
end
%% - If the point isn't in any of our grid areas, set to -99

zgeoid = -1*ones(1, npts);

for m=1:nfiles
	df = find(kval == m);
   if (length(df) > 0)
      fprintf(1, '%d points to find geoid value...\n', length(df));
%		[C, nc] = fread(lin(k), 'float32'); %Old GEOID99 version
		[C, nc] = fread(lin(k), 'float32','l');
		[Cr] = reshape(C, nlo(k), nla(k));
		glat = glamn(k) + ([1:nla(k)] -1)*dla(k);
      glon = glomn(k) + ([1:nlo(k)] -1)*dlo(k);
      [zgeoid(df)] = interp2(glat, glon, Cr, xlat(df), xlon(df));
      %for i=1:length(df)
         %[zgeoid(df(i))] = interp2(glat, glon, Cr, xlat(df(i)), xlon(df(i)), '*linear');
         %if (mod(i,100)==0), fprintf(1, '%6d %f\r', i, zgeoid(df(i))); end;
		%end;
	end
end

%zgeoid = val;
return;

