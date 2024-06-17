function [read_mat,k_mer_loc,cycles_wr0,cycles_wr1,cycles_read,cells_wr0,cells_wr1,cells_read] = move_read(read,XB_process_rows,read_len_bits,k_mer)
% receives number of rows and size of each reference segment and returns
% the data

read_mat = read.*ones(XB_process_rows,read_len_bits);

k_mer_loc = strfind(read,k_mer); % change

cycles_wr0 = 1;
cycles_wr1 = 1;
cycles_read = 1;
cells_wr1 = nnz(read_mat);
cells_wr0 = numel(read_mat)-cells_wr1;
cells_read = length(read);


