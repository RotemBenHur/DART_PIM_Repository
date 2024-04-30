function [out_s,out_Cout,cyc_num_tot,MAGICs_num_tot] = FA_const_1bit(a,k,Cin,out)
% receives two vector inputs of single-bits elements (a and carry-in) 
% and a single-bit element k, and returns the result of a bitwise single 
% bit Full Adder operation between them, based on bitwise NOR operation

if (all(out))
    if k == 0
        [out_Cout,cyc_num(1),MAGICs_num(1)] = AND2_bitwise(a,Cin,out);
        [inter_1,cyc_num(2),MAGICs_num(2)] = NOR2_bitwise(a,Cin,out);
        [out_s,cyc_num(3),MAGICs_num(3)] = NOR2_bitwise(out_Cout,inter_1,out);
    else 
        [inter_1,cyc_num(1),MAGICs_num(1)] = NOR2_bitwise(a,Cin,out);
        [inter_2,cyc_num(2),MAGICs_num(2)] = NOR2_bitwise(a,inter_1,out);
        [inter_3,cyc_num(3),MAGICs_num(3)] = NOR2_bitwise(Cin,inter_1,out);
        [out_s,cyc_num(4),MAGICs_num(4)] = NOR2_bitwise(inter_2,inter_3,out);
        [out_Cout,cyc_num(5),MAGICs_num(5)] = NOT_bitwise(inter_1,out);
    end    

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all'); 
else
   error("The MAGIC output was not initialized to '1'!") 
end    

%test_mux = bitor(bitand(a,~sel),bitand(b,sel));
