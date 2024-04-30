function [out_d,out_Bout,inter,cyc_num_tot,MAGICs_num_tot] = FS_1bit(a,b,Bin,out)
% receives three vector inputs of single bits elements (a, b and borow-in) and returns the result of a bitwise single bit Full Subtractor operation
% between them, based on bitwise NOR operation

if (all(out))
    inter_num = 7;
    inter = false(length(a),inter_num);
    
    [inter(:,1),cyc_num(1),MAGICs_num(1)] = NOR2_bitwise(a,b,out(:,1));
    [inter(:,2),cyc_num(2),MAGICs_num(2)] = NOR2_bitwise(a,inter(:,1),out(:,2));
    [inter(:,3),cyc_num(3),MAGICs_num(3)] = NOR2_bitwise(b,inter(:,1),out(:,3));
    [inter(:,4),cyc_num(4),MAGICs_num(4)] = NOR2_bitwise(inter(:,2),inter(:,3),out(:,4));
    [inter(:,5),cyc_num(5),MAGICs_num(5)] = NOR2_bitwise(Bin,inter(:,4),out(:,5));
    [inter(:,6),cyc_num(6),MAGICs_num(6)] = NOR2_bitwise(Bin,inter(:,5),out(:,6));
    [inter(:,7),cyc_num(7),MAGICs_num(7)] = NOR2_bitwise(inter(:,4),inter(:,5),out(:,7));
    [out_d,cyc_num(8),MAGICs_num(8)] = NOR2_bitwise(inter(:,6),inter(:,7),out(:,8));
    [out_Bout,cyc_num(9),MAGICs_num(9)] = NOR2_bitwise(inter(:,6),inter(:,3),out(:,9));
    
    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all'); 
else
   error("The MAGIC output was not initialized to '1'!") 
end    

% test_d = bitxor(bitxor(a,b),Bin);
% test_Bout = bitor(bitor(bitand(~a,b),bitand(b,Bin)),bitand(~a, Bin));