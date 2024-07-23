numfiles = input('Enter the number of GPS files to process: ');

T = [];
for i = 1:numfiles
    disp('Select GPS file: ')
    [ifile,ipath] = uigetfile('*.txt'); 
    inputfile = [ipath,ifile];

    formatSpec = '%s%f%f%f%C%f%f%f%C%C%C%C%C%C%C%C%C%C%C%C%C%C%C';
    tinput = readtable(inputfile,'Format',formatSpec);
    T = [T;tinput];
end
%%
%get output date to name output file
while true
    outputdate = input('Enter output date (YYYYMMDD): ','s');
    if isnumeric(str2num(outputdate)) && length(outputdate) == 8
        break
    end
    fprintf('%s is not a valid date\n',outputdate);
end
fprintf('\n');

% check if need to adjust to rod height of 2m for all points
man_rodht = input('Set manual rod height? (1: yes, 0: no) ');
if man_rodht == 1
    
    mrheight = input('Rod height: ');
    
    geoidz = table2array(T(:,8));
    geoidz = geoidz+0.009; %apply offset

    rodht = char(table2array(T(:,23)));
    rodht = str2num(rodht(:,9:end));

    % add rodht back in and then subtract manually entered rod height
    
    geoidz = geoidz+rodht;
    geoidz = geoidz-mrheight;
    
else
    
    geoidz = table2array(T(:,8));
    geoidz = geoidz+0.009; %apply offset

    rodht = char(table2array(T(:,23)));
    rodht = str2num(rodht(:,9:end));
    
end
%%
ptnum = table2array(T(:,1));

lat = table2array(T(:,2));
lon = table2array(T(:,3));

ellipsoidz = table2array(T(:,4));

notes = char(table2array(T(:,5)));

northings = table2array(T(:,6));
northings = northings-0.225; %apply offset

eastings = table2array(T(:,7));
eastings = eastings+0.203; %apply offset

hrms = char(table2array(T(:,9)));
hrms = str2num(hrms(:,6:end));

vrms = char(table2array(T(:,10)));
vrms = str2num(vrms(:,6:end));

status = char(table2array(T(:,11)));
status = status(:,8:end);

sats = char(table2array(T(:,12)));
sats = str2num(sats(:,6:end));

age = char(table2array(T(:,13)));
age = str2num(age(:,5:end));

pdop = char(table2array(T(:,14)));
pdop = str2num(pdop(:,6:end));

hdop = char(table2array(T(:,15)));
hdop = str2num(hdop(:,6:end));

vdop = char(table2array(T(:,16)));
vdop = str2num(vdop(:,6:end));

tdop = char(table2array(T(:,17)));
tdop = str2num(tdop(:,6:end));

gdop = char(table2array(T(:,18)));
gdop = str2num(gdop(:,6:end));

nrms = char(table2array(T(:,19)));
nrms = str2num(nrms(:,6:end));

erms = char(table2array(T(:,20)));
erms = str2num(erms(:,6:end));

dmy = char(table2array(T(:,21)));
dmy = dmy(:,6:end);

%create character array of time and vector of matlab time units
time = char(table2array(T(:,22)));
time = time(:,5:end);
time(:,1) = ' ';
dt = [dmy,time]; %character array of date/time
time = datenum(dt); %matlab time units
% convert to decimal time
dstring = str2num(datestr(time,'yyyymmdd'));
tstring = mod(time,1);
datedec = dstring+tstring;

%create error vectors
herror = NaN(size(northings));
verror = NaN(size(northings));
herror(:) = 0.01;
verror(:) = 0.02;

%display min/max of ms and dop
mm = {'min';'max'};
ERMS = [min(erms);max(erms)];
HRMS = [min(hrms);max(hrms)];
NRMS = [min(nrms);max(nrms)];
VRMS = [min(vrms);max(vrms)];

rms = table(ERMS,HRMS,NRMS,VRMS,'RowNames',mm);

GDOP = [min(gdop);max(gdop)];
HDOP = [min(hdop);max(hdop)];
PDOP = [min(pdop);max(pdop)];
TDOP = [min(tdop);max(tdop)];
VDOP = [min(vdop);max(vdop)];

dop = table(GDOP,HDOP,PDOP,TDOP,VDOP,'RowNames',mm);

%create file to output notes to
notesfile = [ipath,num2str(outputdate),'_GCP_notes.txt'];
fidnotes = fopen(notesfile,'w');
%output date/time of first and last point
time1 = find(time == min(time));
time2 = find(time == max(time));

%diplay/print rms/dop min/max
disp(rms)
rmsarr = table2array(rms);
fprintf(fidnotes,'   \tERMS\tHRMS\tNRMS\tVRMS\n');
fprintf(fidnotes,'   \t----\t----\t----\t----\n');
fprintf(fidnotes,'min\t');
fprintf(fidnotes, '%.3f\t%.3f\t%.3f\t%.3f\n', rmsarr(1,:)');
fprintf(fidnotes,'max\t');
fprintf(fidnotes, '%.3f\t%.3f\t%.3f\t%.3f\n\n', rmsarr(2,:)');

disp(dop)
doparr = table2array(dop);
fprintf(fidnotes,'   \tGDOP\tHDOP\tPDOP\tTDOP\tVDOP');
fprintf(fidnotes,'\n');
fprintf(fidnotes,'   \t----\t----\t----\t----\t----');
fprintf(fidnotes,'\n');
fprintf(fidnotes,'min\t');
fprintf(fidnotes, '%.3f\t%.3f\t%.3f\t%.3f\t%.3f\n', doparr(1,:)');
fprintf(fidnotes,'max\t');
fprintf(fidnotes, '%.3f\t%.3f\t%.3f\t%.3f\t%.3f\n\n', doparr(2,:)');

%check data is within proper parameters
k = find(hrms>=0.05);
if ~isempty(k)
    for i = 1:length(k)
        fprintf('***** WARNING: hrms at %.0f >5 cm | hrms(%.0f) = %.0f *****\n', k(i),k(i),hrms(k(i)));
        fprintf(fidnotes,'***** WARNING: hrms at %.0f >5 cm | hrms(%.0f) = %.0f *****\n', k(i),k(i),hrms(k(i)));
    end
end

k = find(vrms>=0.05);
if ~isempty(k)
    for i = 1:length(k)
        fprintf('***** WARNING: vrms at %.0f >5 cm | vrms(%.0f) = %.0f *****\n', k(i),k(i),vrms(k(i)));
        fprintf(fidnotes,'***** WARNING: vrms at %.0f >5 cm | vrms(%.0f) = %.0f *****\n', k(i),k(i),vrms(k(i)));
    end
end

k = find(strcmp(status,'FIXED'));
if ~isempty(k)
    for i = 1:length(k)
        fprintf('***** WARNING: status at %.0f NOT fixed *****\n', k(i));
        fprintf(fidnotes,'***** WARNING: status at %.0f NOT fixed *****\n', k(i));
    end
end

k = find(sats<10);
if ~isempty(k)
    for i = 1:length(k)
        fprintf('***** WARNING: sats at %.0f <10 | sats(%.0f) = %.0f *****\n', k(i),k(i),sats(k(i)));
        fprintf(fidnotes,'***** WARNING: sats at %.0f <10 | sats(%.0f) = %.0f *****\n', k(i),k(i),sats(k(i)));
    end
end

k = find(age>1);
if ~isempty(k)
    for i = 1:length(k)
        fprintf('***** WARNING: age at %.0f >1 | age(%.0f) = %.0f *****\n', k(i),k(i),age(k(i)));
        fprintf(fidnotes,'***** WARNING: age at %.0f >1 | age(%.0f) = %.0f *****\n', k(i),k(i),age(k(i)));
    end
end

k = find(nrms>=0.05);
if ~isempty(k)
    for i = 1:length(k)
        fprintf('***** WARNING: nrms at %.0f >5 cm | nrms(%.0f) = %.0f *****\n', k(i),k(i),nrms(k(i)));
        fprintf(fidnotes,'***** WARNING: nrms at %.0f >5 cm | nrms(%.0f) = %.0f *****\n', k(i),k(i),nrms(k(i)));
    end
end

k = find(erms>=0.05);
if ~isempty(k)
    for i = 1:length(k)
        fprintf('***** WARNING: erms at %.0f >5 cm | erms(%.0f) = %.0f *****\n', k(i),k(i),erms(k(i)));
        fprintf(fidnotes,'***** WARNING: erms at %.0f >5 cm | erms(%.0f) = %.0f *****\n', k(i),k(i),erms(k(i)));
    end
end

k = find(rodht~=2);
if ~isempty(k)
    for i = 1:length(k)
        fprintf('***** WARNING: rod height at %.0f is not 2m | rodheight(%.0f) = %.0f *****\n', k(i),k(i),rodht(k(i)));
        fprintf(fidnotes,'***** WARNING: rod height at %.0f is not 2m | rodheight(%.0f) = %.0f *****\n', k(i),k(i),rodht(k(i)));
    end
end

output(:,1) = ptnum;
output(:,2) = num2cell(eastings);
output(:,3) = num2cell(northings);
output(:,4) = num2cell(geoidz);

format shortG

% create table
outputT = array2table(eastings);
outputT(:,2) = num2cell(northings);
outputT(:,3) = num2cell(geoidz);

outputT.Properties.VariableNames = {'Eastings_m','Northings_m','Geoid_Elevation_m'};

%close notes file
fclose(fidnotes);

disp(outputT)
%%
% check if want to remove points
% rmpts = input('Remove points? (1:yes, 0:no) ');
% rmnums = 1;
% badpts = [];
% while rmnums ~= 0
%     disp('Enter 0 when done removing points')
%     rmnums = input('Points to remove (ex: 5 OR range [5,10]): ');
%     
%     if rmnums == 0
%         break
%     else
%         if length(rmnums) == 2
%             rmarray = (rmnums(1):rmnums(2))';
%         else
%             rmarray = rmnums;
%         end
%         badpts = [badpts;rmarray];
%     end
% end 
% 
% if ~isempty(badpts)
%     outputT(badpts,:) = [];
% end

% create output folder
locname = input('Enter location: ','s');

%%
% create output files
outputfile = [ipath,num2str(outputdate),'_gcp.txt'];
fidoutput = fopen(outputfile,'w');
output = output';
fprintf(fidoutput, '%s, %.5f, %.5f, %.3f \n', output{:,1:end});
fclose(fidoutput);

%%
fprintf('\nOutput written to file %s\n',outputfile)

outputfile = [ipath,'filtered_clean',num2str(outputdate),'.llnezts.txt'];
writetable(outputT,outputfile,'Delimiter',' ','WriteVariableNames',0)

fprintf('\nOutput written to file %s\n',outputfile)

% clear unneeded variables
clearvars filename T k ans formatSpec fidnotes fidoutput i notesfile doparr rmsarr ERMS HRMS NRMS VRMS GDOP HDOP PDOP TDOP VDOP mm rms dop dmy outputdate output

% change .txt to .navd88
newname = strcat(outputfile(1:end-4),'.navd88');
movefile(outputfile,newname)

