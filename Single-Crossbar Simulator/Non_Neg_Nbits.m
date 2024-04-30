function [out_Non_Neg,cyc_num_tot,MAGICs_num_tot] = Non_Neg_Nbits(A,out)
% receives three vector inputs of 8 bits each (A, B and Carry-in) and 
% returns the result of an N bit Full Adder operation
% between them, based on bitwise NOR operation

if (all(out))
    out_Non_Neg = zeros(size(A));
    MSB_A = A(:,1);

    for i = 1:size(A,2)
        [out_Non_Neg(:,i),cyc_num(i),MAGICs_num(i)] = Non_Neg_1bit(A(:,i),MSB_A,out);
    end

    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all');  
else
   error("The MAGIC output was not initialized to '1'!") 
end

% Computing the result in decimal:
% test_non_neg = zeros(size(A));
% for x = 1:size(A,1)
%    if  MSB_A(x) == 0
%        test_non_neg(x,:) = A(x,:);
%    end
% end
   
