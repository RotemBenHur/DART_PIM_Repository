function [XB_write1,cyc_write1_num,write1_num] = write1(XB_rows, XB_columns)
% receives number of rows and columns and writes '1's to all cells

XB_write1 = ones(XB_rows, XB_columns);

cyc_write1_num = 1; % no limitations on the number of written cells 
write1_num = size(XB_write1,1)*size(XB_write1,2);


    