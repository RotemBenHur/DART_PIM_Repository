function [out_inter_AND,cyc_num_tot,MAGICs_num_tot] = AND2_bitwise(in1,in2,out)
% receives two vector inputs of single bits and returns the bitwise AND operation
% between them, based on bitwise NOR operation

if (all(out))
    [inter_1,cyc_num(1),MAGICs_num(1)] = NOT_bitwise(in1,out(:,1));
    [inter_2,cyc_num(2),MAGICs_num(2)] = NOT_bitwise(in2,out(:,2));
    [out_AND,cyc_num(3),MAGICs_num(3)] = NOR2_bitwise(inter_1,inter_2,out(:,3));
    
    out_inter_AND = [inter_1 inter_2 out_AND];

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all'); 
else
   error("The MAGIC output was not initialized to '1'!") 
end


%test = bitand(in1,in2);