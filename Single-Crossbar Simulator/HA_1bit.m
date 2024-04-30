function [out_s,out_Cout,inter,cyc_num_tot,MAGICs_num_tot] = HA_1bit(a,b,out)
% receives three vector inputs of single-bits elements (a, b and carry-in) 
% and returns the result of a bitwise single bit Full Adder operation
% between them, based on bitwise NOR operation

if (all(out))
    inter_num = 3;
    inter = false(length(a),inter_num);
    
    [inter(:,1),cyc_num(1),MAGICs_num(1)] = NOR2_bitwise(a,b,out(:,1));
    [inter(:,2),cyc_num(2),MAGICs_num(2)] = NOT_bitwise(a,out(:,2));
    [inter(:,3),cyc_num(3),MAGICs_num(3)] = NOT_bitwise(b,out(:,3));
    [out_Cout,cyc_num(4),MAGICs_num(4)] = NOR2_bitwise(inter(:,2),inter(:,3),out(:,4));
    [out_s,cyc_num(5),MAGICs_num(5)] = NOR2_bitwise(out_Cout,inter(:,1),out(:,5));
    
    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all');  
else
   error("The MAGIC output was not initialized to '1'!") 
end    

%test_s = bitxor(bitxor(a,b),Cin);
%test_Cout = bitor(bitor(bitand(a,b),bitand(b,Cin)),bitand(a, Cin));