function [out_first_match,inter,cyc_num_tot,MAGICs_num_tot] = find_first_match(b,out)
% receives a vector input b, and returns an output vector c with '1' only 
% at the location of the first '1' in b

if (all(out))
    l = length(b);

    col_1 = out(:,1);
    col_2 = out(:,2);
    col_3 = out(:,3);
    col_4 = out(:,4);


    [col_1,cyc_MAGIC_num(1),MAGICs_num(1)] = NOT_bitwise(b,col_1); % col_1 is b'
    
    [col_4(1),cyc_MAGIC_num(2),MAGICs_num(2)] = NOT_bitwise(col_1(1),col_4(1)); % col_4(1)=c1
    [col_2(1),cyc_MAGIC_num(3),MAGICs_num(3)] = NOT_bitwise(b(1),col_2(1)); % col_2(1)=a2'
    [col_2(2),cyc_MAGIC_num(4),MAGICs_num(4)] = NOT_bitwise(col_2(1),col_2(2)); % col_2(2)=a2=a1+b1
    [col_4(2),cyc_MAGIC_num(5),MAGICs_num(5)] = NOR2_bitwise(col_2(2),col_1(2),col_4(2)); % col_4(2)=c2
    
    for i = 2:2:(l-2-mod(l,2))

        [col_3(i),cyc_MAGIC_num(6*i/2),MAGICs_num(6*i/2)] = NOR2_bitwise(b(i),col_2(i),col_3(i));
        [col_3(i+1),cyc_MAGIC_num(6*i/2+1),MAGICs_num(6*i/2+1)] = NOT_bitwise(col_3(i),col_3(i+1)); % col_3(i+1)=a(i+1)
        [col_4(i+1),cyc_MAGIC_num(6*i/2+2),MAGICs_num(6*i/2+2)] = NOR2_bitwise(col_3(i+1),col_1(i+1),col_4(i+1)); % col_4(i+1)=c(i+1)

        [col_2(i+1),cyc_MAGIC_num(6*i/2+3),MAGICs_num(6*i/2+3)] = NOR2_bitwise(b(i+1),col_3(i+1),col_2(i+1));
        [col_2(i+2),cyc_MAGIC_num(6*i/2+4),MAGICs_num(6*i/2+4)] = NOT_bitwise(col_2(i+1),col_2(i+2)); % col_3(i+2)=a(i+2)
        [col_4(i+2),cyc_MAGIC_num(6*i/2+5),MAGICs_num(6*i/2+5)] = NOR2_bitwise(col_2(i+2),col_1(i+2),col_4(i+2)); % col_4(i+2)=c(i+2)

    end

    if (mod(l,2)) % l is odd
        [col_3(l-1),cyc_MAGIC_num(6*(l-1)/2),MAGICs_num(6*(l-1)/2)] = NOR2_bitwise(b(l-1),col_2(l-1),col_3(l-1));
        [col_3(l),cyc_MAGIC_num(6*(l-1)/2+1),MAGICs_num(6*(l-1)/2+1)] = NOT_bitwise(col_3(l-1),col_3(l)); % col_3(i+1)=a(i+1)
        [col_4(l),cyc_MAGIC_num(6*(l-1)/2+2),MAGICs_num(6*(l-1)/2+2)] = NOR2_bitwise(col_3(l),col_1(l),col_4(l)); % col_4(i+1)=c(i+1)
    end
        
    inter = [col_1 col_2 col_3];
    out_first_match = col_4;

    cyc_num_tot = sum(cyc_MAGIC_num,'all');
    MAGICs_num_tot = sum(MAGICs_num,'all');
    
else
   error("The MAGIC output was not initialized to '1'!") 
end     
    
    
   
