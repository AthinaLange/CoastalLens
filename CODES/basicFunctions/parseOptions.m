
function options = parseOptions( defaults , cellString )

%INPUT PARSING
p = inputParser;
p.KeepUnmatched = true;

names = fieldnames( defaults );
for ii = 1 : length(names)
    %
    addOptional( p , names{ii}, defaults.(names{ii}));
    %
end
%
parse( p , cellString{:} );
options = p.Results;
%
end