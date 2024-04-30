function [out_mux,inter,cyc_num_tot,MAGICs_num_tot] = MUX_a_1bit(a,b,sel,out)
% receives three vector inputs of single-bits elements (a, b and select) and returns
% a if select=1 and b otherwise, based on bitwise NOR operation

if (all(out))
    [inter(:,1),cyc_num(1),MAGICs_num(1)] = NOT_bitwise(sel,out(:,1));
    [inter(:,2),cyc_num(2),MAGICs_num(2)] = NOR2_bitwise(a,inter(:,1),out(:,2));
    [inter(:,3),cyc_num(3),MAGICs_num(3)] = NOR2_bitwise(b,sel,out(:,3));
    [out_mux,cyc_num(4),MAGICs_num(4)] = NOR2_bitwise(inter(:,2),inter(:,3),out(:,4));

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all');   
else
   error("The MAGIC output was not initialized to '1'!") 
end    

%test_mux = bitor(bitand(a,~sel),bitand(b,sel));
