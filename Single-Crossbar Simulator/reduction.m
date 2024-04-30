function [out_reduction,cyc_num_tot,MAGICs_num_tot] = reduction(data,gap,out)
% receives rows of data and performs reduction - moves every row that is in
% row N*gap (N is an integer) to be alligned with the above row

if (all(out))
    rows_num = size(data,1);
    row_size = size(data,2);
    cyc_num_tot = 0;
    MAGICs_num_tot = 0;
    tmp = ones(size(data,1),1);
    first_row = gap/2+1;

    % Move right
    for col_idx = 1:row_size
        col = data(:,col_idx);    
        col_reduc = col(first_row:gap:end);
        [out_NOT,cyc_num_NOT,MAGICs_num_NOT] = NOT_bitwise(col_reduc,out(:,col_idx));
        tmp(first_row:gap:end) = out_NOT;    
        out(:,col_idx) = tmp; 
        cyc_num_tot = cyc_num_tot + cyc_num_NOT;
        MAGICs_num_tot = MAGICs_num_tot + MAGICs_num_NOT; 
    end

    % Move up
    for row_idx = first_row:gap:rows_num
       [out(row_idx-gap/2,:),cyc_num_NOT,MAGICs_num_NOT] =  NOT_bitwise(out(row_idx,:),out(row_idx-gap/2,:));
       cyc_num_tot = cyc_num_tot + cyc_num_NOT;
       MAGICs_num_tot = MAGICs_num_tot + MAGICs_num_NOT;
    end

    out_reduction = out;

else
   error("The MAGIC output was not initialized to '1'!") 
end 

% Now NOT of an entire row
    