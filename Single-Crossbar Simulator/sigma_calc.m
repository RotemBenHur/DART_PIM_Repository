function [out_sigma,inter,cyc_num_tot,MAGICs_num_tot] = sigma_calc(ref_bp,read_bp,out)
% receives two inputs (ref_bp,read_bp), each with 2 bits in each row, compares them row by row
% and returns '1' for every similar row and '0' otherwise, based on bitwise NOR operation

if (all(out))
    [inter_1,cyc_num(1),MAGICs_num(1)] = XNOR2_bitwise(ref_bp(:,1),read_bp(:,1),out(:,1:4));
    [inter_2,cyc_num(2),MAGICs_num(2)] = XNOR2_bitwise(ref_bp(:,2),read_bp(:,2),out(:,5:8));
    [inter_3,cyc_num(3),MAGICs_num(3)] = AND2_bitwise(inter_1(:,4),inter_2(:,4),out(:,9:11));
    
    inter = [inter_1 inter_2 inter_3(:,1:2)];
    out_sigma = inter_3(:,3);
    
    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all'); 
else
   error("The MAGIC output was not initialized to '1'!") 
end     
    
    
   

% Computing the result in decimal:
% A_bin = fi(A,0,1);
% B_bin = fi(B,0,1);
% for x = 1:size(A,1)
%    A_concat(x) = fi(bitconcat(A_bin(x,:)),1,size(A,2)+1);
%    B_concat(x) = fi(bitconcat(B_bin(x,:)),1,size(A,2)+1);
%    maximum(x) = max([A_concat(x),B_concat(x)]);
% end
