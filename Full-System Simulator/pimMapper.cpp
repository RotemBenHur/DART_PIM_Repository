#include <iostream>
#include "pimMapper.h"
#include "minimizer.h"

PIMMapper::PIMMapper(std::string reference) : Mapper(reference), simulator(Simulator(reference, highMinimizers)) {}

std::vector<uint32_t> PIMMapper::mapReads(std::vector<std::string> reads){

    std::cout << "Mapping " << reads.size() << " reads" << std::endl;

	//long WFsByCPU = 0;
	int counter = 0;

    // Iterate over all reads
    for(uint32_t i = 0; i < reads.size(); i++){
		
		//std::cout << "PIMMapper: mapping of read " << i << std::endl;
        // Compute the read minimizers
        MinimizerMap readMinimizers = findMinimizers(reads[i]);
		
		uint32_t MinimizersNum = 0;
        // Iterate over the read minimizers
        for(std::pair<uint32_t, std::vector<uint32_t> > minimizer : readMinimizers) {
			if(lowMinimizers.find(minimizer.first) == lowMinimizers.end()){
                // Iterate over the locations of that minimizer in the read that is handled by DART-PIM
				for (uint32_t loc: minimizer.second) {
                    //std::cout << "pimMapper: PIM mapping of read " << i << " with minimizer " << minimizer.first << std::endl; //doesn't work - segmentation fault
                    simulator.addRead(i, reads[i], loc, minimizer.first);
					MinimizersNum++;
                }
				
            }
        //    else {
        //      // Iterate over the locations of that minimizer in the read that is handled by the CPU
        //      //for (uint32_t loc: minimizer.second) {
        //          //std::cout << "CPU mapping of read " << i << ", with minimizer = " << minimizer.first << ", with number of locations = " << minimizer.second.size()  << std::endl;
		//		
		//			for(std::pair<uint32_t, std::vector<uint32_t> > minimizerLow : lowMinimizers){
		//				if (minimizer.first == minimizerLow.first) {
		//					WFsByCPU += minimizer.second.size()*minimizerLow.second.size();
		//					//std::cout << "minimizerLow.first = " << minimizerLow.first << ", number of locations = " << minimizerLow.second.size() << ", total of WFsByCPU = " << WFsByCPU << std::endl;
		//				}
		//			}
		//								
		//			if (counter%10000 == 0) {
		//				std::cout << counter << ": Total number of WFs done by the CPU = " << WFsByCPU << std::endl;
		//			}
		//			counter++;
        //      //}
        //    }
        }
		//std::cout << "# of minimizers of read " << i << " = " << MinimizersNum << std::endl;
		
		
    }
	
	simulator.done();
	
    std::cout << simulator << std::endl;

}
