#include <iostream>

#include "mapper.h"

Mapper::Mapper(std::string reference) : reference(reference) {

    // Compute the reference minimizers
    MinimizerMap refMinimizers = loadRefMinimizers(reference, "data/GRCh38_latest_genomic.min");

    // Filter minimizers with more than MAX_MINIMIZER_HITS appearances in the reference
    refMinimizers = filterMinimizers(refMinimizers);

    // Separate to minimizers with more and less than LOW_COUNT_MINIMIZER_THRESH appearances in the reference
    std::pair<MinimizerMap, MinimizerMap> separation = separateMinimizers(refMinimizers);
    lowMinimizers = separation.first;
    highMinimizers = separation.second;
	
	// Calculate number of XBs and minimizers
	uint32_t totalLow = 0;
	uint32_t totalLowMinimizers = 0;
    for(std::pair<uint32_t, std::vector<uint32_t> > minimizer : lowMinimizers){
		totalLowMinimizers++;
		totalLow += minimizer.second.size();
		// For RISC-V implementation:
		//for (int i=0; i < minimizer.second.size(); i++){
		//	int startIdx = minimizer.second[i] - (N - K + ETH);
		//	int endIdx = minimizer.second[i] + (N + ETH);
		//	if (startIdx < 0 || endIdx >= reference.length()) continue;
		//	std::cout << minimizer.first << "," << minimizer.second[i] << "," << reference.substr(startIdx,endIdx-startIdx) << std::endl;
		//}	
    }

    uint32_t totalHigh = 0;
	uint32_t totalHighMinimizers = 0;
    uint32_t numXBs = 0;
    for(std::pair<uint32_t, std::vector<uint32_t> > minimizer : highMinimizers){
		totalHighMinimizers++;
        totalHigh += minimizer.second.size();
        numXBs += (minimizer.second.size() + NUM_ROWS_PER_LINEAR_BUFFER - 1) / NUM_ROWS_PER_LINEAR_BUFFER;
    }
	
	// Print
	std::cout << std::endl;
    std::cout << "totalLowMinimizers = " << totalLowMinimizers << std::endl;
	std::cout << "totalLow = " << totalLow << std::endl;
	std::cout << "totalHighMinimizers (number of minimizers handled by DART-PIM)= " << totalHighMinimizers << std::endl;
	std::cout << "totalHigh (number of potential locations handled by DART-PIM) = " << totalHigh << std::endl;
	uint32_t referenceSegmentBits = 2*(2*N-K+2*ETH);
	std::cout << "referenceSegmentBits = " << referenceSegmentBits << std::endl;
	//uint32_t totalReferenceSegmentsBits = referenceSegmentBits*totalHigh;
	//uint32_t totalReferenceSegmentsBytes = totalReferenceSegmentsBits/8;
	//std::cout << "totalReferenceSegmentsBits = " << totalReferenceSegmentsBits << std::endl;
	//std::cout << "totalReferenceSegmentsBytes = " << totalReferenceSegmentsBytes << std::endl;
	std::cout << "numXBs = " << numXBs << std::endl;
	//uint32_t totalMemoryCapacityBytes = numXBs*CROSSBAR_SIZE_BITS/8;
	//uint32_t MemoryCapacityLinearBufferBytes = numXBs*NUM_COLS_PER_CROSSBAR*NUM_ROWS_PER_LINEAR_BUFFER/8;
	//std::cout << "totalMemoryCapacityBytes = " << totalMemoryCapacityBytes << std::endl;
	//std::cout << "MemoryCapacityLinearBufferBytes = " << MemoryCapacityLinearBufferBytes << std::endl;

}