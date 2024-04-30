%% Wagner-Fischer

clear; clc; close all;


%% Wagner-Fischer - mMPU Implementation

tic;

% DART-PIM parameters 

% Wagner-Fischer parameters
k = 12;
minimizer = [0 0 0 0 0 0 1 1 0 0 1 1];
eth = 6; %error threshold
read_len = 150; 
read_len_bits = 2*read_len;
ref_seg_len = 2*read_len - k + 2*eth; 
ref_seg_len_bits = 2*ref_seg_len;

%XB (crossbar) parameters
XB_rows = 256;
XB_reads_FIFO_rows = 160; 
XB_affine_buffer_rows = 64;
XB_linear_buffer_rows = XB_rows - XB_reads_FIFO_rows - XB_affine_buffer_rows;
XB_process_rows = XB_linear_buffer_rows - 1;
XB_process_rows_begin = XB_reads_FIFO_rows + 1;
XB_process_rows_end = XB_reads_FIFO_rows + XB_process_rows;
XB_cols = 2048;
XB = ones(XB_rows, XB_cols);
XB_zero_col_idx = ref_seg_len_bits + read_len_bits + 1; % XB column with zeros
XB_process_col_begin_idx = XB_zero_col_idx + 1; % first column of processing area

% Number of switches for each NOR-based operation
Num_ops_NOR = 1;
Num_ops_NOT = 1;
Num_ops_OR = 2;
Num_ops_AND = 3;
Num_ops_XNOR = 4;
Num_ops_XOR = 5;
Num_ops_MUX = 4;
Num_ops_HA = 5;
Num_ops_FA_const = 5;
Num_ops_FA = 9;
Num_ops_FS = 9;
Num_ops_MAX = Num_ops_FS + Num_ops_MUX;
Num_ops_MIN = Num_ops_MAX;
Num_ops_comp = 3*Num_ops_XNOR + 2*Num_ops_AND;
Num_ops_first_match = 4;



%% \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ Indexing - Offline ///////////////////////////////

% INDEXING - writing reference segments to crossbar

% Number of cycles (for latency) and number of switches (for energy) - initialization
total_cycles_indexing = 0;
total_cycles_indexing_wr0 = 0;
total_cycles_indexing_wr1 = 0;
total_switches_indexing_wr0 = 0;
total_switches_indexing_wr1 = 0;


% Indexing
XB(XB_process_rows_begin:XB_process_rows_end,1:ref_seg_len_bits) = init_ref_seg(XB_process_rows, ref_seg_len_bits, minimizer);

total_cycles_indexing_wr1 = XB_process_rows; % a cycle for writing '1' for each row
total_cycles_indexing_wr0 = XB_process_rows; % a cycle for writing '0' for each row 
total_switches_indexing_wr1 = nnz(XB(XB_process_rows_begin:XB_process_rows_end,1:ref_seg_len_bits));
total_switches_indexing_wr0 = XB_process_rows*ref_seg_len_bits - total_switches_indexing_wr1;
total_cycles_indexing = total_cycles_indexing_wr0 + total_cycles_indexing_wr1;



%% \\\\\\\\\\\\\\\\\\\ Seeding-Filtering-Wagner-Fischer - Runtime ////////////////////

% Number of cycles (for latency) and number of switches (for energy) - initialization
total_cycles_runtime = 0;
total_cycles_runtime_read = 0;
total_cycles_runtime_wr0 = 0;
total_cycles_runtime_wr1 = 0;
total_cycles_runtime_MAGIC = 0;
total_switches_runtime_read = 0;
total_switches_runtime_wr0 = 0;
total_switches_runtime_wr1 = 0;
total_switches_runtime_MAGIC = 0;


% SEEDING - inserting reads to Reads FIFO

% Number of cycles (for latency) and number of switches (for energy) - initialization
total_cycles_seeding = 0;
total_cycles_seeding_read = 0;
total_cycles_seeding_wr0 = 0;
total_cycles_seeding_wr1 = 0;
total_cycles_seeding_MAGIC = 0;
total_switches_seeding_read = 0;
total_switches_seeding_wr0 = 0;
total_switches_seeding_wr1 = 0;
total_switches_seeding_MAGIC = 0;

% Inserting all reads to the Reads FIFO
for reads_buffer_row = 1:XB_reads_FIFO_rows
    for reads_buffer_col = 1:read_len_bits:XB_cols-read_len_bits+1
        [XB(reads_buffer_row,reads_buffer_col:reads_buffer_col+read_len_bits-1),tmp_cycles,tmp_write0,tmp_write1] = get_read(read_len_bits,minimizer);
        total_cycles_seeding_wr0 = total_cycles_seeding_wr0+tmp_cycles/2;
        total_cycles_seeding_wr1 = total_cycles_seeding_wr1+tmp_cycles/2;
        total_switches_seeding_wr0 = total_switches_seeding_wr0+tmp_write0;
        total_switches_seeding_wr1 = total_switches_seeding_wr1+tmp_write1;
    end
end

% Write first read from FIFO to all linear buffer rows
% (Controller reads a read and its minimizer location and writes it to all
% linear buffer rows, for comuting the WF of the read with every reference 
% segment, one on each crossbar row)
[XB(XB_process_rows_begin:XB_process_rows_end,ref_seg_len_bits+1:ref_seg_len_bits+read_len_bits),minimizer_loc,tmp_cycles_wr0,tmp_cycles_wr1,tmp_cycles_read,tmp_write0,tmp_write1,tmp_switches_read] = move_read(XB(1,1:read_len_bits),XB_process_rows,read_len_bits,minimizer);
total_cycles_seeding_read = total_cycles_seeding_read+tmp_cycles_read;
total_cycles_seeding_wr0 = total_cycles_seeding_wr0+tmp_cycles_wr0;
total_cycles_seeding_wr1 = total_cycles_seeding_wr1+tmp_cycles_wr1;
total_switches_seeding_read = total_switches_seeding_read+tmp_switches_read;
total_switches_seeding_wr0 = total_switches_seeding_wr0+tmp_write0;
total_switches_seeding_wr1 = total_switches_seeding_wr1+tmp_write1;


% FILTERING - filtering the irelevant rows (potential locations)

% using Wagner-Fischer (by finding the row (potential location) with
% minimal score)

% The following implementation works ONLY WHEN w_del = w_ins = w_sub = 1.
% To change it, the following changes in "score" function are needed:
% 1. Half Adder should be replaced with Full Adder
% 2. First add w_del, w_ins, w_sub and only then compute the minimum 

w_del = 1;
w_ins = 1;
w_sub = 1;

% Number of cycles (for latency) and number of switches (for energy) - initialization
total_cycles_WF = 0;
total_cycles_WF_read = 0;
total_cycles_WF_wr0 = 0;
total_cycles_WF_wr1 = 0;
total_cycles_WF_MAGIC = 0;
total_switches_WF_read = 0;
total_switches_WF_wr0 = 0;
total_switches_WF_wr1 = 0;
total_switches_WF_MAGIC = 0;


% Initialize processing area
[XB(XB_process_rows_begin:XB_process_rows_end,XB_zero_col_idx),tmp_cycles_wr0,tmp_switches_wr0] = write0(XB_process_rows,1);
total_cycles_WF_wr0 = total_cycles_WF_wr0+tmp_cycles_wr0;
total_switches_WF_wr0 = total_switches_WF_wr0+tmp_switches_wr0;
[XB(XB_process_rows_begin:XB_process_rows_end,XB_process_col_begin_idx:XB_cols),tmp_cycles_wr1,tmp_switches_wr1] = write1(XB_process_rows,XB_cols-XB_process_col_begin_idx+1);
total_cycles_WF_wr1 = total_cycles_WF_wr1+tmp_cycles_wr1;
total_switches_WF_wr1 = total_switches_WF_wr1+tmp_switches_wr1;

% Calculate score matrix

ref_seg_begin_idx = (ref_seg_len_bits-length(minimizer))/2 + 1 - minimizer_loc(1) + 1  ;
ref_seg_end_idx = ref_seg_begin_idx + read_len_bits - 1;
read_begin_idx = ref_seg_len_bits+1;

num_scores_per_WF_row = 1 + 2*eth; % number of scores calculated in each row in banded WF            
score_size = 3; % number of bits of each score
sigma_size = 1; % number of bits of each sigma

Num_ops_sigma_inter = 2*Num_ops_XNOR + Num_ops_AND - sigma_size;
Num_ops_sigma_out = sigma_size;
Num_ops_score_first_inter = score_size*Num_ops_HA + 2*Num_ops_AND + score_size*(Num_ops_MUX-1);
Num_ops_score_first_out = score_size;
Num_ops_score_inter = score_size*(1 + 2*Num_ops_MIN + Num_ops_HA + 2*(Num_ops_MUX-1)) + 2*Num_ops_AND;
Num_ops_score_out = score_size;

WF_score_begin_idx = eth+1;

XB_begin_score_col_idx = XB_process_col_begin_idx; % The XB column index of the stored row of the score matrix
XB_sigma_col_idx = XB_begin_score_col_idx + (num_scores_per_WF_row+2)*score_size;
%XB_even_row_score_col_idx = XB_odd_row_score_col_idx + num_scores_per_WF_row*score_size; % The column index of the second stored row of the score matrix
XB_inter_col_begin_idx = XB_sigma_col_idx + sigma_size;
XB_current_inter_col_idx = XB_inter_col_begin_idx; % The column index of the intermediate results
XB_process_cols_num = XB_cols - XB_inter_col_begin_idx + 1; % number of columns for processing


WF_score_MAT_length = read_len;
score_MATs_num = XB_process_rows;
score_MATs = 7*ones(WF_score_MAT_length,WF_score_MAT_length,score_MATs_num);     %  ????? should it be a square matrix?????


for WF_row_idx = 1:WF_score_MAT_length
    
    % set the boundaries of the banded WF score matrix
    if (WF_row_idx - eth >= 1)
        WF_col_begin_idx = WF_row_idx - eth;
    else     
        WF_col_begin_idx = 1;
    end

    if (WF_row_idx + eth <= WF_score_MAT_length)
        WF_col_end_idx = WF_row_idx + eth;
    else     
        WF_col_end_idx = WF_score_MAT_length;
    end
    
    % set the index of the first calculated score in a banded row (size of
    % banded row is 2*eth+1 scores, and we add a score='111' on both sides, 
    % so a total of 2*eth+3 scores)
    if (WF_col_begin_idx == 1)
        WF_current_score_idx = WF_score_begin_idx-(WF_row_idx-1)+1;
        XB_current_score_col_idx = XB_begin_score_col_idx + (WF_current_score_idx-1)*score_size; % The XB column index of the current calculated score
    else
        WF_current_score_idx = 2;
        XB_current_score_col_idx = XB_begin_score_col_idx + score_size;
    end
    
    % generate the score matrix
    for WF_col_idx = WF_col_begin_idx:WF_col_end_idx
        
        % TODO: when starting a new row x (starting from row 3), erase the scores of row x-2, and set
        % XB_current_score_col_idx to the erased place 
           
        if (WF_row_idx == 1) % //// Initialize first row of score matrix ////
           if (WF_col_idx == 1)
               score_MATs(1,1,:) = 0; 
               [XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx:XB_current_score_col_idx+score_size-1),tmp_cycles_wr0,tmp_switches_wr0] = write0(XB_process_rows,score_size);
               total_cycles_WF_wr0 = total_cycles_WF_wr0 + tmp_cycles_wr0;
               total_switches_WF_wr0 = total_switches_WF_wr0 + tmp_switches_wr0;
               %XB_current_score_col_idx = XB_current_score_col_idx + score_size;
           else
               % reset processing area if there is not enough space for the computations
               if (XB_current_inter_col_idx+Num_ops_score_first_inter-1) > XB_cols
                   XB_current_inter_col_idx_old = XB_current_inter_col_idx;
                   XB_current_inter_col_idx = XB_inter_col_begin_idx;
                   [XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx_old-1),tmp_cycles_wr1,tmp_switches_wr1] = write1(XB_process_rows,XB_current_inter_col_idx_old-XB_current_inter_col_idx);
                   total_cycles_WF_wr1 = total_cycles_WF_wr1 + tmp_cycles_wr1;
                   total_switches_WF_wr1 = total_switches_WF_wr1 + tmp_switches_wr1;
               end 
               % add w_ins to the previous score in the row
               score_MATs(1,WF_col_idx,:) = score_MATs(1,WF_col_idx-1,:)+w_ins;
               out = [XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_score_first_inter-1) XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx:XB_current_score_col_idx+Num_ops_score_first_out-1) ];
               [XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx:XB_current_score_col_idx+Num_ops_score_first_out-1),XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_score_first_inter-1),tmp_cycles_MAGIC,tmp_switches_MAGIC] = score_first_col_row(w_ins,XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx-score_size:XB_current_score_col_idx-1),out);
               total_cycles_WF_MAGIC = total_cycles_WF_MAGIC + tmp_cycles_MAGIC;
               total_switches_WF_MAGIC = total_switches_WF_MAGIC + tmp_switches_MAGIC;
               %XB_current_score_col_idx = XB_current_score_col_idx + score_size;
               XB_current_inter_col_idx = XB_current_inter_col_idx + Num_ops_score_first_inter;
           end
           
        else
           if (WF_col_idx == 1) % //// Initialize first column of score matrix ////
               % reset processing area if there is not enough space for the computations
               if (XB_current_inter_col_idx+Num_ops_score_first_inter-1) > XB_cols
                   XB_current_inter_col_idx_old = XB_current_inter_col_idx;
                   XB_current_inter_col_idx = XB_inter_col_begin_idx;
                   [XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx_old-1),tmp_cycles_wr1,tmp_switches_wr1] = write1(XB_process_rows,XB_current_inter_col_idx_old-XB_current_inter_col_idx);
                   total_cycles_WF_wr1 = total_cycles_WF_wr1 + tmp_cycles_wr1;
                   total_switches_WF_wr1 = total_switches_WF_wr1 + tmp_switches_wr1;
               end 
               % add w_del to the previous score in the row
               score_MATs(WF_row_idx,1,:) = score_MATs(WF_row_idx-1,1,:)+w_del;
               out = [XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_score_first_inter-1) XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx:XB_current_score_col_idx+Num_ops_score_first_out-1) ];
               [XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx:XB_current_score_col_idx+Num_ops_score_first_out-1),XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_score_first_inter-1),tmp_cycles_MAGIC,tmp_switches_MAGIC] = score_first_col_row(w_del,XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx+score_size:XB_current_score_col_idx+score_size*2-1),out);
               total_cycles_WF_MAGIC = total_cycles_WF_MAGIC + tmp_cycles_MAGIC;
               total_switches_WF_MAGIC = total_switches_WF_MAGIC + tmp_switches_MAGIC;
               %XB_current_score_col_idx = XB_current_score_col_idx + Num_ops_score_first_out;
               XB_current_inter_col_idx = XB_current_inter_col_idx + Num_ops_score_first_inter;
           
           else % //// Calculate all scores (except for the first row and column) ////
               % reset processing area if there is not enough space for the sigma computation
               if (XB_current_inter_col_idx+Num_ops_sigma_inter-1) > XB_cols
                   if (XB_inter_col_begin_idx+Num_ops_sigma_inter-1) > XB_process_cols_num
                       error("Not enough space for the sigma computation!")
                   end
                   XB_current_inter_col_idx_old = XB_current_inter_col_idx;
                   XB_current_inter_col_idx = XB_inter_col_begin_idx;
                   [XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx_old-1),tmp_cycles_wr1,tmp_switches_wr1] = write1(XB_process_rows,XB_current_inter_col_idx_old-XB_current_inter_col_idx);
                   total_cycles_WF_wr1 = total_cycles_WF_wr1 + tmp_cycles_wr1;
                   total_switches_WF_wr1 = total_switches_WF_wr1 + tmp_switches_wr1;
               end 
               % calculate sigma
               ref_bp_idx = ref_seg_begin_idx+2*WF_col_idx-4;
               read_bp_idx = read_begin_idx+2*WF_row_idx-4;
               %col_idx_sigma_out = XB_current_inter_col_idx+Num_ops_sigma_inter;
               ref_bp = XB(XB_process_rows_begin:XB_process_rows_end,ref_bp_idx:ref_bp_idx+1);
               read_bp = XB(XB_process_rows_begin:XB_process_rows_end,read_bp_idx:read_bp_idx+1);
               out = [XB(XB_process_rows_begin:XB_process_rows_end,XB_sigma_col_idx+Num_ops_sigma_out-1)  XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_sigma_inter-1)];
               [tmp_sigma_out,tmp_sigma_inter,tmp_cycles_MAGIC,tmp_switches_MAGIC] = sigma_calc(ref_bp,read_bp,out);
               XB(XB_process_rows_begin:XB_process_rows_end,XB_sigma_col_idx:XB_sigma_col_idx+Num_ops_sigma_out-1) = tmp_sigma_out;
               XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_sigma_inter-1) = tmp_sigma_inter;
               total_cycles_WF_MAGIC = total_cycles_WF_MAGIC + tmp_cycles_MAGIC;
               total_switches_WF_MAGIC = total_switches_WF_MAGIC + tmp_switches_MAGIC;
               XB_current_inter_col_idx = XB_current_inter_col_idx + Num_ops_sigma_inter;
               
               % reset processing area if there is not enough space for the score computation
               if (XB_current_inter_col_idx+Num_ops_score_inter-1) > XB_cols
                   if (XB_inter_col_begin_idx+Num_ops_score_inter-1) > XB_process_cols_num
                       error("Not enough space for the score computation!")
                   end
                   XB_current_inter_col_idx_old = XB_current_inter_col_idx;
                   XB_current_inter_col_idx = XB_inter_col_begin_idx;
                   [XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx_old-1),tmp_cycles_wr1,tmp_switches_wr1] = write1(XB_process_rows,XB_current_inter_col_idx_old-XB_current_inter_col_idx);
                   total_cycles_WF_wr1 = total_cycles_WF_wr1 + tmp_cycles_wr1;
                   total_switches_WF_wr1 = total_switches_WF_wr1 + tmp_switches_wr1;
               end
               % calculate score
               sigma = XB(XB_process_rows_begin:XB_process_rows_end,XB_sigma_col_idx+Num_ops_sigma_out-1);
               left_up = XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx:XB_current_score_col_idx+score_size-1);
               left = XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx-score_size:XB_current_score_col_idx-1);
               up = XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx+score_size:XB_current_score_col_idx+2*score_size-1);
               out = [ones(XB_process_rows,score_size) XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_score_inter-1)];
               [tmp_score_out,tmp_score_inter,tmp_cycles_MAGIC,tmp_switches_MAGIC,tmp_cycles_wr1,tmp_switches_wr1] = score_calc(sigma,w_sub,w_del,w_ins,left_up,left,up,out);
               XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx:XB_current_score_col_idx+score_size-1) = tmp_score_out;
               XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_score_inter-1) = tmp_score_inter;
               total_cycles_WF_MAGIC = total_cycles_WF_MAGIC + tmp_cycles_MAGIC;
               total_switches_WF_MAGIC = total_switches_WF_MAGIC + tmp_switches_MAGIC;
               total_cycles_WF_wr1 = total_cycles_WF_wr1 + tmp_cycles_wr1;
               total_switches_WF_wr1 = total_switches_WF_wr1 + tmp_switches_wr1;
               XB_current_inter_col_idx = XB_current_inter_col_idx + Num_ops_score_inter;
               
               for idx = 1:score_MATs_num
                   if (sigma(idx) == 1) % a_i == b_j
                       score_MATs(WF_row_idx,WF_col_idx,idx) = score_MATs(WF_row_idx-1,WF_col_idx-1,idx);
                   else
                       score_MATs(WF_row_idx,WF_col_idx,idx) = min( [score_MATs(WF_row_idx-1,WF_col_idx,idx)+w_del  score_MATs(WF_row_idx,WF_col_idx-1,idx)+w_ins  score_MATs(WF_row_idx-1,WF_col_idx-1,idx)+w_sub] );
                   end
               end
               
               % reset the cells for the next calculated sigma
               [XB(XB_process_rows_begin:XB_process_rows_end,XB_sigma_col_idx:XB_sigma_col_idx+Num_ops_sigma_out-1),tmp_cycles_wr1,tmp_switches_wr1] = write1(XB_process_rows,sigma_size);
               total_cycles_WF_wr1 = total_cycles_WF_wr1 + tmp_cycles_wr1;
               total_switches_WF_wr1 = total_switches_WF_wr1 + tmp_switches_wr1;

           end 
        end

    XB_current_score_col_idx = XB_current_score_col_idx + score_size;   
    WF_current_score_idx = WF_current_score_idx + 1;
    
    end
end

% \\\\ Reduction to all minimum values (in order to find the global minimum) \\\\\
XB_score_col_idx = XB_current_score_col_idx - score_size;
gaps = 2.^(1:ceil(log2(XB_process_rows)));

for ii = 1:length(gaps)
    
    gap = gaps(ii);

    % reset the processing area (including some of the uneeded scores and the sigma)
    XB_init_start = XB_current_score_col_idx;
    XB_init_end = XB_current_inter_col_idx-1;
    [XB(XB_process_rows_begin:XB_process_rows_end,XB_init_start:XB_init_end),tmp_cycles_wr1,tmp_switches_wr1] = write1(XB_process_rows,XB_init_end-XB_init_start+1);
    total_cycles_WF_wr1 = total_cycles_WF_wr1 + tmp_cycles_wr1;
    tmp_switches_wr1 = tmp_switches_wr1/XB_process_rows*ceil(XB_process_rows/gap*2); %only some of the rows were changed, according to gap
    total_switches_WF_wr1 = total_switches_WF_wr1 + tmp_switches_wr1;
    XB_current_inter_col_idx = XB_current_score_col_idx + score_size;

    WF_min_scores = XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx-score_size:XB_current_score_col_idx-1);
    WF_min_scores_reduc = XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx:XB_current_score_col_idx+score_size-1);

    % perform reduction of the minimum values (move them so each will be aligned with
    % other minimum value)
    [WF_min_scores_reduc,tmp_cycles_MAGIC,tmp_switches_MAGIC] = reduction(WF_min_scores,gap,WF_min_scores_reduc);
    total_cycles_WF_MAGIC = total_cycles_WF_MAGIC + tmp_cycles_MAGIC;
    total_switches_WF_MAGIC = total_switches_WF_MAGIC + tmp_switches_MAGIC;
    XB(XB_process_rows_begin:XB_process_rows_end,XB_current_score_col_idx:XB_current_score_col_idx+score_size-1) = WF_min_scores_reduc;


    % calculate the minimium (only for the rows with the minimum values)
    scores_A = WF_min_scores(1:gap:end,:);
    scores_B = WF_min_scores_reduc(1:gap:end,:);
    %rows_active_idx = ceil(XB_process_rows/gap);
    out_min = XB(XB_process_rows_begin:gap:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+score_size*Num_ops_MIN-1);
    [tmp_out_min,tmp_out_inter,tmp_cycles_MAGIC,tmp_switches_MAGIC] = MIN_Nbits(scores_A,scores_B,out_min);
    total_cycles_WF_MAGIC = total_cycles_WF_MAGIC + tmp_cycles_MAGIC;
    total_switches_WF_MAGIC = total_switches_WF_MAGIC + tmp_switches_MAGIC;
    % writing the results and intermediates to XB
    tmp_out = ones(XB_process_rows,score_size);
    tmp_out(1:gap:end,:) = tmp_out_min;
    XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+score_size-1) = tmp_out;
    tmp_inter = ones(XB_process_rows,score_size*(Num_ops_MIN-1));
    tmp_inter(1:gap:end,:) = tmp_out_inter;
    XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx+score_size:XB_current_inter_col_idx+score_size*Num_ops_MIN-1) = tmp_inter;        
    XB_current_inter_col_idx = XB_current_inter_col_idx+score_size*Num_ops_MIN;
    XB_current_score_col_idx = XB_current_score_col_idx + 2*score_size;
        
end

% reset the processing area (only one row) 
XB_init_start = XB_current_score_col_idx;
XB_init_end = XB_current_inter_col_idx-1;
[XB(XB_process_rows_begin,XB_current_score_col_idx:XB_init_end),tmp_cycles_wr1,tmp_switches_wr1] = write1(1,XB_init_end-XB_init_start+1);
total_cycles_WF_wr1 = total_cycles_WF_wr1 + tmp_cycles_wr1;
total_switches_WF_wr1 = total_switches_WF_wr1 + tmp_switches_wr1;
XB_current_inter_col_idx = XB_current_score_col_idx;

% \\\\\ Finding the row with the global minimum, and copying it to the affine buffer \\\\\\\
XB_min_score_col_idx = XB_current_score_col_idx - score_size;
% copy the minimum to all rows
    % NOT to the last row
[XB(XB_rows,XB_min_score_col_idx:XB_min_score_col_idx+score_size-1),tmp_cycles_MAGIC,tmp_switches_MAGIC] = NOT_bitwise(XB(XB_reads_FIFO_rows+1,XB_min_score_col_idx:XB_min_score_col_idx+score_size-1),XB(XB_rows,XB_min_score_col_idx:XB_min_score_col_idx+score_size-1));
total_cycles_WF_MAGIC = total_cycles_WF_MAGIC + tmp_cycles_MAGIC;
total_switches_WF_MAGIC = total_switches_WF_MAGIC + tmp_switches_MAGIC;
    % NOT from the last row to all process rows 
for row = XB_reads_FIFO_rows+2:XB_reads_FIFO_rows+XB_process_rows
    [XB(row,XB_min_score_col_idx:XB_min_score_col_idx+score_size-1),tmp_cycles_MAGIC,tmp_switches_MAGIC] = NOT_bitwise(XB(XB_rows,XB_min_score_col_idx:XB_min_score_col_idx+score_size-1),XB(row,XB_min_score_col_idx:XB_min_score_col_idx+score_size-1));
    total_cycles_WF_MAGIC = total_cycles_WF_MAGIC + tmp_cycles_MAGIC;
    total_switches_WF_MAGIC = total_switches_WF_MAGIC + tmp_switches_MAGIC;
end

XB_global_min_score_col_idx = XB_min_score_col_idx;

% compare global minimum with all rows - get a '1' only for the rows that
% have that minimum value
WF_min_scores = XB(XB_process_rows_begin:XB_process_rows_end,XB_score_col_idx:XB_score_col_idx+score_size-1);
WF_global_min_scores = XB(XB_process_rows_begin:XB_process_rows_end,XB_global_min_score_col_idx:XB_global_min_score_col_idx+score_size-1);
out_comp = XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_comp-1);

[tmp_out_comp,tmp_out_inter,tmp_cycles_MAGIC,tmp_switches_MAGIC] = compare(WF_min_scores,WF_global_min_scores,out_comp);
XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx) = tmp_out_comp;
XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx+2:XB_current_inter_col_idx+Num_ops_comp) = tmp_out_inter;
total_cycles_WF_MAGIC = total_cycles_WF_MAGIC + tmp_cycles_MAGIC;
total_switches_WF_MAGIC = total_switches_WF_MAGIC + tmp_switches_MAGIC;

XB_if_global_min_col_idx = XB_current_inter_col_idx;
XB_current_inter_col_idx = XB_current_inter_col_idx + Num_ops_comp + 1;

% Find the first row with the global minimum - get a '1' only for it
if_match = XB(XB_process_rows_begin:XB_process_rows_end,XB_if_global_min_col_idx);
out = [XB(XB_process_rows_begin:XB_process_rows_end,XB_if_global_min_col_idx+1) XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_first_match-2)];  
[tmp_out_first_match,tmp_out_inter,tmp_cycles_MAGIC,tmp_switches_MAGIC] = find_first_match(if_match,out);
XB(XB_process_rows_begin:XB_process_rows_end,XB_if_global_min_col_idx+1) = tmp_out_first_match;
XB(XB_process_rows_begin:XB_process_rows_end,XB_current_inter_col_idx:XB_current_inter_col_idx+Num_ops_first_match-2) = tmp_out_inter;
total_cycles_WF_MAGIC = total_cycles_WF_MAGIC + tmp_cycles_MAGIC;
total_switches_WF_MAGIC = total_switches_WF_MAGIC + tmp_switches_MAGIC;

XB_first_global_min_col_idx = XB_if_global_min_col_idx + 1;
XB_current_inter_col_idx = XB_current_inter_col_idx + Num_ops_first_match - 1;

toc;

%% Summarize all results


% Runtime cycles:
total_cycles_runtime_read = total_cycles_seeding_read + total_cycles_WF_read;
total_cycles_runtime_wr0 = total_cycles_seeding_wr0 + total_cycles_WF_wr0;
total_cycles_runtime_wr1 = total_cycles_seeding_wr1 + total_cycles_WF_wr1;
total_cycles_runtime_MAGIC = total_cycles_seeding_MAGIC + total_cycles_WF_MAGIC;
total_cycles_runtime = total_cycles_runtime_read + total_cycles_runtime_wr0 + total_cycles_runtime_wr1 + total_cycles_runtime_MAGIC;

% Runtime switches:
total_switches_runtime_read = total_switches_seeding_read + total_switches_WF_read;
total_switches_runtime_wr0 = total_switches_seeding_wr0 + total_switches_WF_wr0;
total_switches_runtime_wr1 = total_switches_seeding_wr1 + total_cycles_WF_wr1;
total_switches_runtime_MAGIC = total_switches_seeding_MAGIC + total_switches_WF_MAGIC;



