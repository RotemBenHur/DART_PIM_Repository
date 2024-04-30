function [out_NOR,cyc_num,MAGICs_num]  = NOR2_bitwise(in1,in2,out)
% receives two vector inputs of single bits and returns the bitwise NOR operation
% between them

if (all(out)) 
    out_NOR = ~(bitor(in1,in2));

    cyc_num = 1;
    MAGICs_num = length(in1);
else
   error("The MAGIC output was not initialized to '1'!") 
end