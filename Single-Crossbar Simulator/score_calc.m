function [out_score,inter,cyc_num_MAGIC_tot,MAGICs_num_tot,cyc_write1_num,write1_num] = score_calc(sigma,w_sub,w_del,w_ins,left_up,left,up,out)
% receives the scores on the left, up-left and up cells, and returns the
% score of the new cell

% verifies w_sub = w_ins = w_del = 1 
if (w_sub ~= 1)
    error("w_sub should be equal to 1!")
elseif (w_ins ~= 1)
    error("w_ins should be equal to 1!")
elseif (w_del ~= 1)
    error("w_del should be equal to 1!")
end

if (all(out))
    
    w = w_sub*ones(size(left,1),1);
    
    % Y = minimum{left_up,left,up}
    [X,inter_1,cyc_num(1),MAGICs_num(1)] = MIN_Nbits(left_up,left,out(:,1:39)); % N=3, thus inter_1 has 30 columns
    [Y,inter_2,cyc_num(2),MAGICs_num(2)] = MIN_Nbits(up,X,out(:,40:78));
    % Z = Y + w (only when w_sub=1)
    [Z,inter_3a,inter_3b,cyc_num(3),MAGICs_num(3)] = HA_Nbits(Y,w,out(:,79:93));
    % S1=1 only if Y==111 
    [inter_4,cyc_num(4),MAGICs_num(4)] = AND2_bitwise(Y(:,2),Y(:,3),out(:,94:96));
    [inter_5,cyc_num(5),MAGICs_num(5)] = AND2_bitwise(Y(:,1),inter_4(:,3),out(:,97:99));
    S1 = inter_5(:,3);
    % If Y=111, we reached saturation (so W=Y, else W=Z)
    [W,inter_6,cyc_num(6),MAGICs_num(6)] = MUX_A_Nbits(Y,Z,S1,out(:,100:111));
    % score = W / left_up if sigma == 0 / 1 respectively 
    [out_score,inter_7,cyc_num(7),MAGICs_num(7)] = MUX_A_Nbits(left_up,W,sigma,out(:,112:123)); 
    
    inter = [X inter_1 Y inter_2 Z inter_3a inter_3b inter_4 inter_5 W inter_6 inter_7];
    
    cyc_num_MAGIC_tot = sum(cyc_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all'); 
    
    cyc_write1_num = 1;
    write1_num = numel(X);
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
