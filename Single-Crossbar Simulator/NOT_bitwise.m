function [out_NOT,cyc_num,MAGICs_num] = NOT_bitwise(in1,out)
% receives a single vector input of single bits and returns the bitwise
% complementary

if (all(out))
    out_NOT = ~in1;

    cyc_num = 1;
    MAGICs_num = length(in1);
else
   error("The MAGIC output was not initialized to '1'!") 
end    