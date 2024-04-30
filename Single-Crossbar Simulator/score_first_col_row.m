function [out_score_first,inter,cyc_num_tot,MAGICs_num_tot] = score_first_col_row(w,prev_score,out)
% Receives an input prev_score and adds w_ins (if on the first row) or w_del (if on the first column) to it, 
% based on bitwise NOR operation. If it reaches "111" then it is saturated, thus does not change. 


if (all(out))
    
    W = w*ones(size(prev_score,1),1);
    
    % X = prev_score + 1
    [X,inter_1a,inter_1b,cyc_num(1),MAGICs_num(1)] = HA_Nbits(prev_score,w,out(:,1:15));
    % S1=1 only when if prev_score==111 
    [inter_2,cyc_num(2),MAGICs_num(2)] = AND2_bitwise(prev_score(:,2),prev_score(:,3),out(:,16:18));
    [inter_3,cyc_num(3),MAGICs_num(3)] = AND2_bitwise(prev_score(:,1),inter_2(:,3),out(:,19:21));
    S1 = inter_3(:,3);
    % If prev_score=111, we reached saturation (so out_score_first=prev_score=111, else out_score_first=X=prev_score+1)
    [out_score_first,inter_4,cyc_num(4),MAGICs_num(4)] = MUX_A_Nbits(prev_score,X,S1,out(:,22:33));
    
    inter = [X inter_1a inter_1b inter_2 inter_3 inter_4];
    
    cyc_num_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all'); 
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
