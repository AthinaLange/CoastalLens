function [nfiles, lin, nff, ios] = files_intg(dirnam)
%%function [nfiles, lin, nff, ios] = files_intg(dirnam);
%%%%      subroutine files(dirnam,nfiles,fnam,lin,nff, ios)

%% - Subroutine to create the file name for

	ios = (-1) * ones(1,14);
    nfiles = 1;
%% - Use the one master file for CONUS
  fname = [dirnam 'g2012bu0.bin'];
  lin = fopen(fname, 'r', 'b');
  if lin > 0, ios = 0; end


%% - Check and see if at least ONE file was opened,
%% - and make a count of how many WERE opened.
%% - Abort if we find no geoid files.

      nff = 0;
      df = find(ios == 0);
      nff = length(df);

      if (nff < 1) 
		%fprintf(1, 'No files found.  bye.\n');
	else
		%fprintf(1, 'Files found = %d\n', nff);
	end

return;
