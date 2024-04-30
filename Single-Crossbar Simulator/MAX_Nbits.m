function [out_max,inter,cyc_num_tot,MAGICs_num_tot] = MAX_Nbits(A,B,out)
% receives three vector inputs of 8 bits each (A, B and Carry-in) and returns the maximum
% between them, based on bitwise NOR operation

if (all(out))
    N = size(A,2);
    FS_1bit_inter_num = 7;
    FS_Nbit_inter_num = FS_1bit_inter_num*N;
    FS_1bit_out_num = FS_1bit_inter_num + 2;
    FS_Nbit_out_num = FS_1bit_out_num*N;
    mux_1bit_inter_num = 3;
    mux_Nbit_inter_num = mux_1bit_inter_num*N;
    mux_1bit_out_num = mux_1bit_inter_num + 1;
    mux_Nbit_out_num = mux_1bit_out_num*N;
    
    inter_num = FS_Nbit_inter_num + mux_Nbit_inter_num;
    inter = false(size(A,1),inter_num);
    
    out_max = zeros(size(A));
    Bin = zeros(size(A,1),1); 

    [D,Bout,inter(:,1:FS_Nbit_inter_num),cyc_num_tot_FS,MAGICs_num_tot_FS] = FS_Nbits(A,B,out(:,1:FS_Nbit_out_num));

    [out_max,inter(:,FS_Nbit_inter_num+1:FS_Nbit_inter_num+mux_Nbit_inter_num),cyc_num_tot_MUX,MAGICs_num_tot_MUX] = MUX_B_Nbits(A,B,Bout(:,1),out(:,FS_Nbit_out_num+1:FS_Nbit_out_num+mux_Nbit_out_num));

    cyc_num_tot = cyc_num_tot_FS + cyc_num_tot_MUX;
    MAGICs_num_tot = MAGICs_num_tot_FS + MAGICs_num_tot_MUX; 
else
   error("The MAGIC output was not initialized to '1'!") 
end    

% Computing the result in decimal:
% A_bin = fi(A,0,1);
% B_bin = fi(B,0,1);
% for x = 1:size(A,1)
%    A_concat(x) = fi(bitconcat(A_bin(x,:)),1,size(A,2)+1);
%    B_concat(x) = fi(bitconcat(B_bin(x,:)),1,size(A,2)+1);
%    maximum(x) = max([A_concat(x),B_concat(x)]);
% end
