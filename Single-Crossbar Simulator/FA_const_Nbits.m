function [out_S,out_Cout,cyc_num_tot,MAGICs_num_tot] = FA_const_Nbits(A,const,out)
% receives one vector input of N-bits elements (A), and single vector of 
% 1-bit elements (carry-in), and a single vector of 1-bit element (const), and returns
% A if selet=0 and B otherwise, based on bitwise NOR operation

if (all(out))
    N = size(A,2); % this is the index of the Least Sagnificant Bit (LSB)
    Cin = zeros(size(A,1),1);

    out_S = zeros(size(A));
    Cout = zeros(size(A));
    out_Cout = zeros(size(Cin));


    [out_S(:,N),Cout(:,N),cyc_num(1),MAGICs_num(1)] = FA_const_1bit(A(:,N),const(N),Cin,out);

    for i = N-1:-1:1
        [out_S(:,i),Cout(:,i),cyc_num(N-i+1),MAGICs_num(N-i+1)] = FA_const_1bit(A(:,i),const(i),Cout(:,i+1),out);
    end

    out_Cout = Cout(:,i);

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all');
else
   error("The MAGIC output was not initialized to '1'!") 
end    

% Computing the result in decimal:
% A_bin = fi(A,0,1);
% Cin_bin = fi(Cin,0,1);
% const_bin = fi(const,0,1);
% const_concat = bitconcat(const_bin);
% for x = 1:size(A,1)
%    A_concat(x) = bitconcat(A_bin(x,:));
%    sum(x) = A_concat(x) + const_concat + Cin(x);
% end
