function ref_seg = init_ref_seg(XB_process_rows, ref_seg_len_bits, k_mer)
% receives number of rows and size of each reference segment and returns
% the data


% change to generating the data (according to the reads or something)
% or to reading from file (and converting from bases to bits)

ref_seg = randi([0 1],XB_process_rows,ref_seg_len_bits);

k_mer_mat = k_mer.*ones(XB_process_rows,size(k_mer,2));

idx_kmer_begin = ref_seg_len_bits/2 - length(k_mer)/2 + 1;

ref_seg(:,idx_kmer_begin:idx_kmer_begin+length(k_mer)-1) = k_mer_mat;



% Reading from file
% ref = importdata("C:\Users\rotem\Google Drive\PhD\Thesis\In-memory application\DNA sequencing\Whole DNA Sequencing\Simulators\Cycle Accurate MAT Simulator\Data\ref.txt");

% Change letters to bits 
    