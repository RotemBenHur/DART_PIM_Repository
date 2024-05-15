#include <iostream>
#include "utility.h"
#include "pimMapper.h"

int main(){

    // Print parameters
	std::cout << "FIXED AFFINE WFs!" << std::endl;
	std::cout << "NUM_ROWS_PER_CROSSBAR = " << NUM_ROWS_PER_CROSSBAR << std::endl;
	std::cout << "CROSSBAR_SIZE_BITS = " << CROSSBAR_SIZE_BITS << std::endl;
	std::cout << "MAX_MINIMIZER_HITS = " << MAX_MINIMIZER_HITS << std::endl;
	std::cout << "MAX_READS_PER_CROSSBAR = " << MAX_READS_PER_CROSSBAR << std::endl;
	std::cout << "NUM_ROWS_PER_READS_BUFFER = " << NUM_ROWS_PER_READS_BUFFER << std::endl;
	std::cout << "NUM_ROWS_PER_LINEAR_BUFFER = " << NUM_ROWS_PER_LINEAR_BUFFER << std::endl;
	std::cout << "NUM_ROWS_PER_AFFINE_BUFFER = " << NUM_ROWS_PER_AFFINE_BUFFER << std::endl;
	std::cout << "NUM_COMPUTe_ROWS_PER_AFFINE_BUFFER = " << NUM_COMPUTE_ROWS_PER_AFFINE_BUFFER << std::endl;
	std::cout << "LOW_COUNT_MINIMIZER_THRESH = " << LOW_COUNT_MINIMIZER_THRESH << std::endl;
	std::cout << "Read size (N) = " << N << std::endl;
	std::cout << "K = " << K << std::endl;
	std::cout << "W = " << W << std::endl;
	std::cout << "ETH = " << ETH << std::endl;
	std::cout << "NUM_READS_IN_BUFFER = " << NUM_READS_IN_BUFFER << std::endl;
		
	 
	// Load the reference
	std::string ref_filename = "data/GRCh38_latest_genomic.fna";
    std::string reference = loadFASTA(ref_filename);
    std::cout << "Received reference of " << reference.size() << " characters" << std::endl;
	
    // Initialize the mapper
    PIMMapper mapper = PIMMapper(reference);

    // Load the reads
    std::string reads_filename = "data/reads_R1_01per.fastq";
    std::vector<std::string> reads = loadFASTQ(reads_filename);
    std::cout << "Loaded " << reads.size() << " reads" << std::endl;
	
    // Map the reads
    std::vector<uint32_t> locations = mapper.mapReads(reads);

    return 0;
	
}