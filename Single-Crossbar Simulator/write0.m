function [XB_write0,cyc_write0_num,write0_num] = write0(XB_rows, XB_columns)
% receives number of rows and columns and writes '1's to all cells

XB_write0 = zeros(XB_rows, XB_columns);

cyc_write0_num = 1; % no limitations on the number of written cells 
write0_num = size(XB_write0,1)*size(XB_write0,2);

