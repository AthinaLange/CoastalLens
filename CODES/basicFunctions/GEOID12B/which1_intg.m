function [k] = which1_intg(xlat, xlon, nfiles, glamn, glamx, glomn, glomx, dla, dlo, nla, nlo, ios)
%%function [k] = which1_intg(xlat, xlon, nfiles, glamn, glamx, glomn, glomx, dla, dlo, nla, nlo, ios);
%%%subroutine which1(xlat,xlon,nfiles,k, glamn, glamx, glomn, glomx, dla, dlo, nla, nlo, ios);

%% - Subroutine to decide which of the open
%% - geoid files will be used to interpolate
%% - to a point at xlat/xlon.  The returned
%% - value of "k" means the "kth" file will
%% - be used.
%% - 
%% - For the GEOID99 models:
%%      Alaska and CONUS overlap, and this code
%% -    forces a "CONUS wins" scenario when interpolating
%% -    the geoid at points in the overlap region.

rank = zeros(1, nfiles);


%% - Spin through all *open* files, and
%% - *RANK* them...the file with the
%% - highest RANK decides the value of "k".
%% - Here's how the ranking goes:
%% -   0 = Point does not lie in this file area
%% -   1 = Point lies in this file, but at a corner
%% -   2 = Point lies in this file, but at an edge
%% -   3 = Point lies in this file, away from corners/edges

%% - If a rank=3 file is found, k is immediately set
%% - and we return.  If no 3 files are found, the
%% - file with the highest rank (2 or 1) sets k.
%% - If all files have rank=0, k is set to -1

for i=1:nfiles
	if (ios == 0)

         	if (xlat <= glamx(i) & xlat >= glamn(i) & xlon <= glomx(i) & xlon >= glomn(i) )

			%% - At this point, we're Inside a grid
	
			%% - Now determine which one of the 9 possible
			%% - places this point resides --
			%% - NW corner, North Edge, NE corner
			%% - West Edge, Center    , East edge
			%% - SW corner, South Edge, SE corner
          		ne = 0;
          		se = 0;
          		we = 0;
          		ee = 0;

			%% - Near North edge?
          		if (glamx(i) - xlat <= dla(i)/2)
            			ne = 1;

			%% - Near South edge?
          		elseif (xlat - glamn(i) <= dla(i)/2)
            			se = 1;
          		end
    
			%% - Near East edge?
          		if (glomx(i) - xlon <= dlo(i)/2)
            			ee = 1;
			%% - Near West edge?
          		elseif (xlon - glomn(i) <= dlo(i)/2)
            			we = 1;
          		end
          
          		%%%if(.not.ne .and. .not.se .and. .not.we .and. .not.ee)then
          		if (~ne & ~se & ~we & ~ee)
            			k = i;
            			return;
          		end
         
			%% - Set the rank of this file, based on edge-logic
          		if (ne & ~we & ~ee) rank(i) = 2; end
          		if (se & ~we & ~ee) rank(i) = 2; end
          		if (we & ~ne & ~se) rank(i) = 2; end
          		if (ee & ~ne & ~se) rank(i) = 2; end
          		if (ne & we) rank(i) = 1; end
          		if (se & we) rank(i) = 1; end
          		if (se & ee) rank(i) = 1; end
          		if (ne & ee) rank(i) = 1; end

        	end


    	end

end


%% - If we reach this point, all possible files have
%% - been searched, and there's no open file which
%% - had a rank of 3.  So now, see if we have any rank 2
%% - or rank 1 files to use.
for i=1:nfiles
       	if (ios == 0 & rank(i) == 2)
          	k = i;
          	return;
	end
end

for i=1:nfiles
       	if (ios == 0 & rank(i) == 1)
          	k = i;
          	return;
        end
end


%% - If we come here, no files are acceptable for the
%% - given lat/lon value
k = -1;
return;

