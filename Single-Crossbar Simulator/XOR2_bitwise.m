function [out_XOR,cyc_num_tot,MAGICs_num_tot] = XOR2_bitwise(in1,in2,out)
% receives two vector inputs of single bits and returns the bitwise XOR operation
% between them, based on bitwise NOR operation

if (all(out))
    [inter_1,cyc_num(1),MAGICs_num(1)] = AND2_bitwise(in1,in2,out);
    [inter_2,cyc_num(2),MAGICs_num(2)] = NOR2_bitwise(in1,in2,out);
    [out_XOR,cyc_num(3),MAGICs_num(3)] = NOR2_bitwise(inter_1,inter_2,out);

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all');  
else
   error("The MAGIC output was not initialized to '1'!") 
end    

%test = bitxor(in1,in2);