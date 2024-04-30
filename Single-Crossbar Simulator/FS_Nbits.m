function [out_D,out_Bout,inter,cyc_num_tot,MAGICs_num_tot] = FS_Nbits(A,B,out)
% receives two vector inputs of N-bits elements (A, B) and a single vector of 1-bit elements (Borow-in) and returns the result of an N-bits Full Subtractor operation
% between them, based on bitwise NOR operation



if (all(out))
    N = size(A,2); % this is the index of the Least Sagnificant Bit (LSB)
    Bin = zeros(size(A,1),1);
    
    FS_1bit_inter_num = 7;
    FS_1bit_out_num = FS_1bit_inter_num + 2;
    inter_num = FS_1bit_inter_num*N;
    inter = false(size(A,1),inter_num);

    out_D = zeros(size(A));
    out_Bout = zeros(size(A));
    %out_Bout = zeros(size(Bin));

    [out_D(:,N),out_Bout(:,N),inter(:,1:FS_1bit_inter_num),cyc_num(1),MAGICs_num(1)] = FS_1bit(A(:,N),B(:,N),Bin,out(:,1:FS_1bit_out_num));

    for i = N-1:-1:1
        [out_D(:,i),out_Bout(:,i),inter(:,i*FS_1bit_inter_num+1:i*FS_1bit_inter_num+FS_1bit_inter_num),cyc_num(N-i+1),MAGICs_num(N-i+1)] = FS_1bit(A(:,i),B(:,i),out_Bout(:,i+1),out(:,i*FS_1bit_out_num+1:i*FS_1bit_out_num+FS_1bit_out_num));
    end

    %out_Bout = out_Bout(:,i);

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all');
else
   error("The MAGIC output was not initialized to '1'!") 
end    

% Computing the result in decimal:
% A_bin = fi(A,0,1);
% B_bin = fi(B,0,1);
% Bin_bin = fi(Bin,1,2);
% for x = 1:size(A,1)
%    A_concat(x) = fi(bitconcat(A_bin(x,:)),1,size(A,2)+1);
%    B_concat(x) = fi(bitconcat(B_bin(x,:)),1,size(A,2)+1);
%    subtract(x) = A_concat(x)-B_concat(x)-Bin_bin(x);
% end
