function [out_inter_XNOR,cyc_num_tot,MAGICs_num_tot] = XNOR2_bitwise(in1, in2, out)
% receives two vector inputs of single bits and returns the bitwise XNOR operation
% between them, based on bitwise NOR operation

if (all(out))
    [inter_1,cyc_num(1),MAGICs_num(1)] = NOR2_bitwise(in1,in2,out(:,1));
    [inter_2,cyc_num(2),MAGICs_num(2)] = NOR2_bitwise(in1,inter_1,out(:,2));
    [inter_3,cyc_num(3),MAGICs_num(3)] = NOR2_bitwise(in2,inter_1,out(:,3));
    [out_XNOR,cyc_num(4),MAGICs_num(4)] = NOR2_bitwise(inter_2,inter_3,out(:,4));
    
    out_inter_XNOR = [inter_1 inter_2 inter_3 out_XNOR];

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all');   
else
   error("The MAGIC output was not initialized to '1'!") 
end
    
%test = ~bitxor(in1,in2);