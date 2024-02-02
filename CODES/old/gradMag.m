function gradient = gradMag( bw )

bwtemp = zeros(size(bw,1)+1,size(bw,2)+1);
bwtemp(2:size(bw,1)+1,1:size(bw,2)) = bw;
gradient = zeros(size(bw));

for i = 2:size(bw,1)+1
    for j = 1:size(bw,2)
        gradient(i-1,j) = sqrt((bwtemp(i,j+1)-bwtemp(i,j))^2 + (bwtemp(i-1,j)-bwtemp(i,j))^2);
    end
end

end