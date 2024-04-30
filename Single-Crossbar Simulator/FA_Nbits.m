function [out_S,out_Cout,inter,cyc_num_tot,MAGICs_num_tot] = FA_Nbits(A,B,out)
% receives two vector inputs of N-bits elements (A, B) and a single vector of 1-bit elements (Carry-in) and returns the result of an N bit Full Adder operation
% between them, based on bitwise NOR operation

if (all(out))
    N = size(A,2); % this is the index of the Least Sagnificant Bit (LSB)
    Cin = zeros(size(A,1),1);
    
    FA_1bit_inter_num = 7;
    FA_1bit_out_num = FA_1bit_inter_num + 2;
    inter_num = FA_1bit_inter_num*N;
    inter = false(size(A,1),inter_num);

    out_S = zeros(size(A));
    out_Cout = zeros(size(A));


    [out_S(:,N),out_Cout(:,N),inter(:,1:FA_1bit_inter_num),cyc_num(1),MAGICs_num(1)] = FA_1bit(A(:,N),B(:,N),Cin,out(:,1:FA_1bit_out_num));

    for i = N-1:-1:1
        [out_S(:,i),out_Cout(:,i),inter(:,i*FA_1bit_inter_num+1:i*FA_1bit_inter_num+FA_1bit_inter_num),cyc_num(N-i+1),MAGICs_num(N-i+1)] = FA_1bit(A(:,i),B(:,i),out_Cout(:,i+1),out(:,i*FA_1bit_out_num+1:(i+1)*FA_1bit_out_num));
    end

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all');   
else
   error("The MAGIC output was not initialized to '1'!") 
end

% Computing the result in decimal:
% A_bin = fi(A,0,1);
% B_bin = fi(B,0,1);
% Cin_bin = fi(Cin,0,1);
% for x = 1:size(A,1)
%    A_concat(x) = bitconcat(A_bin(x,:));
%    B_concat(x) = bitconcat(B_bin(x,:));
%    sum(x) = A_concat(x)+B_concat(x)+Cin(x);
% end