function [read,cycles,cells_wr0,cells_wr1] = get_read(read_len_bits,k_mer)
% receives number of rows and size of each reference segment and returns
% the data

k_mer_loc = randi([1 (read_len_bits-length(k_mer)+2)/2],1,1);

read = randi([0 1],1,read_len_bits);
read(k_mer_loc*2-1:k_mer_loc*2+length(k_mer)-2) = k_mer;

cycles = 2;
cells_wr1 = nnz(read);
cells_wr0 = length(read)-cells_wr1;


% Change to reading from file
% ref = importdata("C:\Users\rotem\Google Drive\PhD\Thesis\In-memory application\DNA sequencing\Whole DNA Sequencing\Simulators\Cycle Accurate MAT Simulator\Data\ref.txt");

% Change letters to bits 
    