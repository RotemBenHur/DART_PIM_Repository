function [read_rows, k_mer_loc] = init_ref_seg(XB_rows, read_len_bits, k_mer)
% receives number of rows and size of each reference segment and returns
% the data
k_mer_loc = floor(read_len_bits/3);

read = randi([0 1],1,read_len_bits);
read(k_mer_loc:k_mer_loc+3) = k_mer;

for i=1:XB_rows
    read_rows(i,:) = read;
end

