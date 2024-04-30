function [out_compare,inter,cyc_num_tot,MAGICs_num_tot] = compare(A,B,out)
% receives two inputs (A,B), each with 3 bits in each row, compares them row by row
% and returns '1' for every similar row and '0' otherwise, based on bitwise NOR operation

if (all(out))
    [inter_1,cyc_num(1),MAGICs_num(1)] = XNOR2_bitwise(A(:,1),B(:,1),out(:,1:4));
    [inter_2,cyc_num(2),MAGICs_num(2)] = XNOR2_bitwise(A(:,2),B(:,2),out(:,5:8));
    [inter_3,cyc_num(3),MAGICs_num(3)] = XNOR2_bitwise(A(:,3),B(:,3),out(:,9:12));
    [inter_4,cyc_num(4),MAGICs_num(4)] = AND2_bitwise(inter_1(:,4),inter_2(:,4),out(:,13:15));
    [inter_5,cyc_num(5),MAGICs_num(5)] = AND2_bitwise(inter_4(:,3),inter_3(:,4),out(:,16:18));
    
    inter = [inter_1 inter_2 inter_3 inter_4 inter_5(:,1:2)];
    out_compare = inter_5(:,3);
    
    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all'); 
else
   error("The MAGIC output was not initialized to '1'!") 
end     
    
    
   
