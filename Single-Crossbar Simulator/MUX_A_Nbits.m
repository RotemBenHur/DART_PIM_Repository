function [out_mux,inter,cyc_num_tot,MAGICs_num_tot] = MUX_A_Nbits(A,B,sel,out)
% receives two vector inputs of N-bits elements (A, B) and a single vector of 1-bit elements (select) and returns
% A if selet=1 and B otherwise, based on bitwise NOR operation

if (all(out))
    out_mux = zeros(size(A));
    
    N = size(A,2);
    mux_1bit_inter_num = 3;
    mux_1bit_out_num = mux_1bit_inter_num + 1;
    inter_num = mux_1bit_inter_num*N;
    inter = false(size(A,1),inter_num);

    for i = 1:N
        [out_mux(:,i),inter(:,(i-1)*mux_1bit_inter_num+1:i*mux_1bit_inter_num),cyc_num(i),MAGICs_num(i)] = MUX_a_1bit(A(:,i),B(:,i),sel,out(:,(i-1)*mux_1bit_out_num+1:i*mux_1bit_out_num));
    end

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all'); 
else
   error("The MAGIC output was not initialized to '1'!") 
end    

% Computing the result in decimal:
% A_bin = fi(A,0,1);
% B_bin = fi(B,0,1);
% sel_bin = fi(sel,0,1);
% for x = 1:size(A,1)
%    A_concat(x) = bitconcat(A_bin(x,:));
%    B_concat(x) = bitconcat(B_bin(x,:));
%    if sel(x) == 0 
%       mux(x) = A_concat(x);
%    else 
%       mux(x) = B_concat(x);
%    end
% end
