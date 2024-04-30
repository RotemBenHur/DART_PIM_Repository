function [out_non_neg,cyc_num_tot,MAGICs_num_tot] = Non_Neg_1bit(a,msb_a,out)
% receives two vector inputs of single-bits elements (a, msb_a) and returns
% a if msb_a=0 and zero otherwise, based on bitwise NOR operation

if (all(out))
    [inter_1,cyc_num(1),MAGICs_num(1)] = NOR2_bitwise(a,msb_a,out);
    [out_non_neg,cyc_num(2),MAGICs_num(2)] = NOR2_bitwise(msb_a,inter_1,out);

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all'); 
else
   error("The MAGIC output was not initialized to '1'!") 
end    

% if msb_a == 0
%     test_non_neg = a;
% else 
%     test_non_neg = 0;  
% end
