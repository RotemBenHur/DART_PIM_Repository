#include <algorithm>
#include <fstream>
#include <iostream>

#include "simulator.h"
#include "sw.h"


Simulator::Simulator(const std::string& reference, const MinimizerMap& minimizers){
	
    // Allocate the crossbars by iterating over the minimizers
    uint32_t crossbarNum = 0;
	
	//std::cout << "Simulator: reference.length() = " << reference.length() << std::endl;
	//std::string refSubstr = reference.substr(1000000, 200);
	//std::cout << "Simulator: refSubstr.length() = " << refSubstr.length() << std::endl;
	//std::cout << "Simulator: ref substring = " << refSubstr << std::endl;
	//char* tmpRefStr = new char [reference.length()+1];;
	//tmpRefStr = reference.c_str();
	//std::cout << "Simulator: ref substring.c_str() = " << std::endl;
	//std::cout.write(reference.c_str()+100000,1000) << std::endl;
	
    for(std::pair<uint32_t, std::vector<uint32_t> > minimizer : minimizers){
        // Iterate over the crossbars needed for the minimizer
        for(uint32_t i = 0; i < minimizer.second.size(); i += NUM_ROWS_PER_LINEAR_BUFFER){
			//std::cout <<"Simulator: Crossbar " <<  crossbarNum << " of minimizer " << minimizer.first << ", number of reference locations = " << minimizer.second.size() << std::endl;
            // Initialize the crossbar
            Crossbar crossbar;
            for(uint32_t j = i; j < std::min((uint32_t) minimizer.second.size(), i + NUM_ROWS_PER_LINEAR_BUFFER); j++){
				int startIdx = minimizer.second[j] - (N - K + ETH);
				int endIdx = minimizer.second[j] + (N + ETH);
				if (startIdx < 0 || endIdx >= reference.length()) continue;
				//std::cout << "minimizer.second[j]: " << minimizer.second[j] << std::endl;
				crossbar.firstBufferReferences.push_back(ReferenceBufferElement(minimizer.second[j], reference.substr(startIdx,endIdx-startIdx)));
				//std::cout << "      Simulator: " << j << ": crossbar " << crossbarNum << ", reference location = " << minimizer.second[j] << std::endl;
			}
            crossbars.push_back(crossbar);
			
            // Add the crossbar to the minimizer-to-crossbar mapping
            if(minimizerToCrossbar.find(minimizer.first) == minimizerToCrossbar.end()) minimizerToCrossbar[minimizer.first] = std::vector<uint32_t>();
            minimizerToCrossbar[minimizer.first].push_back(crossbarNum++);
			
        }
		//std::cout << " ---------------- Number of minimizerToCrossbar[minimizer.first] is " << minimizerToCrossbar[minimizer.first].size() << std::endl;

    }
	//std::cout << " ---------------- Number of minimizerToCrossbar is " << minimizerToCrossbar.size() << std::endl;
    std::cout << "Allocated " << crossbarNum << " crossbars" << std::endl;

}

void Simulator::addRead(uint32_t readNum, const std::string& read, uint32_t minimizerLoc, uint32_t minimizer){
	
	if (readNum%1000000 == 0) {
		std::cout << "Simulator: adding read " << readNum  << ", minimizer = " << minimizer << ", minimizer location = " << minimizerLoc << std::endl;
	}
	
	totnumAddMinimizers++;
	numAddMinimizers++;
	
	if (readNum != lastReadNum) numAddReads++;
	lastReadNum = readNum;
	
    // Iterate over the crossbars with the given minimizer
    bool full1 = false;
	bool crossbarFull = false;
    for(uint32_t crossbarIdx : minimizerToCrossbar[minimizer]){
		//std::cout << "Simulator: Adding read " << readNum << ", to XB " << crossbarIdx << ", minimizer " << minimizer << std::endl; 
        // Add the read to the crossbar buffer
        Crossbar &crossbar = crossbars[crossbarIdx];

		if (crossbar.totReadsNum <= MAX_READS_PER_CROSSBAR) {
			crossbar.firstBufferReads.push(ReadBufferElement(read.c_str(), readNum, minimizerLoc));
			crossbar.totReadsNum++;
			// Check if the buffer reaches capacity
			if(crossbar.firstBufferReads.size() == NUM_READS_IN_BUFFER) {
				//std::cout << "Simulator: crossbar " << crossbarIdx << " is Full1!" << std::endl;
				full1 = true;
			}
			numAffineWFsCalculated++;
		}
		else { 
			crossbarFull = true;
			numAffineWFsNotCalculated++;
		}
    }
	
	
	if (crossbarFull) numDumpedReads++;
	
    // If the buffer reached capacity, then perform a type 1 update
    if(full1) {

		numAddMinimizers = 0;
		numAddReads = 0;
		update1(); 
		
	}

}

void Simulator::update1(){
	
	//std::cout << "Simulator: one of the read buffers is full - performing update 1" << std::endl;
	
    numUpdate1++;
	int crossbarIdx = -1;
	int crossbarIdxSecondFull = -1;
	
	bool full2 = false;

    // Iterate over all crossbars
    for(Crossbar& crossbar : crossbars){
        crossbarIdx++;

		if(crossbar.firstBufferReads.empty()) continue; 
		
		//std::cout << "Crossbar " << crossbarIdx << ": crossbar.firstBufferReferences.size() = " << crossbar.firstBufferReferences.size() << std::endl;
		
		
        totalUpdate1Crossbars++; 
		iterUpdate1Crossbars++;
		totalUpdate1Locations += crossbar.firstBufferReferences.size(); 
		iterUpdate1Locations += crossbar.firstBufferReferences.size();
 
        // Retrieve the first entry in the read buffer
        ReadBufferElement readElement = crossbar.firstBufferReads.front();
        crossbar.firstBufferReads.pop();
		
        // Compute edit distance between the read and all of the reference segments in that crossbar
        int bestEdit = N;
		int refSegStartIdx = (N - K) - readElement.minimizerStart;
		int refSegSize = N + 2*ETH;
        ReferenceBufferElement* bestElement;
		//std::cout << "Simulator: Read Element: " << readElement.read << std::endl;
		//std::cout << "Simulator: Read Element minimizerStart: " << readElement.minimizerStart << std::endl;
		//std::cout << "Simulator: Read Element number: " << readElement.readNum << std::endl;
		//std::cout << "Simulator: Ref Seg startIdx : " << refSegStartIdx << std::endl;
		//std::cout << "crossbar.firstBufferReferences.size() = " << crossbar.firstBufferReferences.size() << std::endl;
		
		
		for(ReferenceBufferElement& refElement : crossbar.firstBufferReferences){
			
			//std::cout << "Simulator: refElement.refLoc: " << refElement.refLoc << std::endl;
			//std::cout << "Simulator: refElement.reference: " << refElement.reference.substr(refSegStartIdx,refSegSize) << std::endl;
			//std::cout << "Simulator: refElement.reference: " << refElement.reference.substr(refSegStartIdx,refSegSize) << std::endl;
			
			bestElement = &refElement; //erase
			int e = editDistance(readElement.read, refElement.reference.substr(refSegStartIdx,refSegSize));
			if (COMPARISON_MODE) {
				int s = affineSmithWaterman(readElement.read, refElement.reference.substr(refSegStartIdx,refSegSize));
				//std::cout << "Simulator: e = " << e << ", s = " << s << std::endl;
				emitSW(readElement.readNum, refElement.refLoc + refSegStartIdx, s);
			}
            if(e < bestEdit){
                bestEdit = e;
                bestElement = &refElement;
            }
			
        }
		//std::cout << "In XB num " << crossbarIdx << ", best element has e = " << bestEdit  << ", the read is: " << readElement.readNum << std::endl; //", and the reference location is " << *bestElement.refLoc << std::endl;
		
		
        // Add the read to the affine buffer
        crossbar.secondBuffer.push(std::pair<ReadBufferElement, ReferenceBufferElement>(readElement, *bestElement));
		tmp_affine++;
		
		if(crossbar.secondBuffer.size() == NUM_COMPUTE_ROWS_PER_AFFINE_BUFFER) {
			full2 = true;
			crossbarIdxSecondFull = crossbarIdx;
		}
		
    }
	
	
	//std::cout << "iterUpdate1Crossbars = " << iterUpdate1Crossbars << std::endl;
	//std::cout << "totalUpdate1Crossbars = " << totalUpdate1Crossbars << std::endl;
	//std::cout << "iterUpdate1Locations = " << iterUpdate1Locations << std::endl;
	//std::cout << "totalUpdate1Locations = " << totalUpdate1Locations << std::endl;
	//std::cout << "numUpdate1 = " << numUpdate1 << std::endl;
	//std::cout << "Number of reads in Affine Buffer = " << crossbar.secondBuffer.size() << std::endl;
		
	if(full2) {
			//std::cout << "crossbarIdx with affine buffer full = " << crossbarIdxSecondFull << std::endl;
			update2();
	}
	else {
			//std::cout << "iterUpdate2Crossbars = 0" << std::endl;
			//std::cout << "iterUpdate2Locations = 0" << std::endl;

	}
	
	iterUpdate1Crossbars = 0;
	iterUpdate1Locations = 0;

}

void Simulator::update2() {

	//std::cout << "Simulator: one of the affine buffers is full - performing update 2" << std::endl;
	
    numUpdate2++;
	int crossbarIdx = -1;
	
    // Iterate over all crossbars
    for(Crossbar& crossbar : crossbars){
		crossbarIdx++;
		
        if(crossbar.secondBuffer.empty()) continue;
		
		//std::cout << "Crossbar " << crossbarIdx << ": crossbar.secondBuffer.size() = " << crossbar.secondBuffer.size() << std::endl;
		
		totalUpdate2Crossbars++;
		iterUpdate2Crossbars++;
		totalUpdate2Locations += crossbar.secondBuffer.size(); 
		iterUpdate2Locations += crossbar.secondBuffer.size();
		
		uint32_t secondBufferSize = crossbar.secondBuffer.size();
		
        // Retrieve the entries in the affine buffer
		for (uint32_t i = 0; i < secondBufferSize; i++) {
			
			std::pair<ReadBufferElement, ReferenceBufferElement> element = crossbar.secondBuffer.front();
			crossbar.secondBuffer.pop();
			
			int refSegStartIdx = (N - K) - element.first.minimizerStart;
			int refSegSize = N + 2*ETH;

			// Compute the affine edit distance
			int e = affineEditDistance(element.first.read, element.second.reference.substr(refSegStartIdx,refSegSize));
			emit(element.first.readNum, element.second.refLoc + refSegStartIdx, e);
		}
		//std::cout << "Simulator: secondBufferSize after affine (should be empty) = " << crossbar.secondBuffer.size() << std::endl;
		
    }
	

	//std::cout << "iterUpdate2Crossbars = " << iterUpdate2Crossbars << std::endl;
	//std::cout << "totalUpdate2Crossbars = " << totalUpdate2Crossbars << std::endl;
	//std::cout << "iterUpdate2Locations = " << iterUpdate2Locations << std::endl;
	//std::cout << "totalUpdate2Locations = " << totalUpdate2Locations << std::endl;
	//std::cout << "numUpdate2 = " << numUpdate2 << std::endl;
	iterUpdate2Crossbars = 0;
	iterUpdate2Locations = 0;

}

void Simulator::done(){ // Now this function only counts. Change to acctualy perform update1 and update2 !!!!
	
	int crossbarIdx = -1;
	int max_reads_in_FIFO = 0;
	
	for(Crossbar& crossbar : crossbars){
		crossbarIdx++;
		if(crossbar.firstBufferReads.empty()) continue;
		int WFs_in_crossbar = crossbar.firstBufferReads.size()*crossbar.firstBufferReferences.size();
		left_linear_WFs += WFs_in_crossbar;
		if (crossbar.firstBufferReads.size() > max_reads_in_FIFO) {
			max_reads_in_FIFO = crossbar.firstBufferReads.size();
		}
		
		//if (crossbarIdx%10000 == 0) {
		//	std::cout << "crossbarIdx = " << crossbarIdx << ", crossbar.firstBufferReads.size() = " << crossbar.firstBufferReads.size() << ", crossbar.firstBufferReferences.size() = " << crossbar.firstBufferReferences.size() << ", WFs_in_crossbar = " << WFs_in_crossbar << ", left_linear_WFs = " << left_linear_WFs << std::endl;
		//}
	}
	
	crossbarIdx = -1;
	
	for(Crossbar& crossbar : crossbars){
		crossbarIdx++;
		//std::cout << "inside crossbar. crossbarIdx = " << crossbarIdx << std::endl;
		if(crossbar.secondBuffer.empty() && crossbar.firstBufferReads.empty()) continue;
		int Affine_WFs_in_crossbar = crossbar.secondBuffer.size() + crossbar.firstBufferReads.size(); // secondBuffer - what's already in the Affine Buffer, firstBufferReads - one Affine WF will be added for each read in the Reads FIFO
		left_affine_WFs += Affine_WFs_in_crossbar;
		//if (crossbarIdx%100000 == 0) {
		//	std::cout << "crossbarIdx = " << crossbarIdx << ", crossbar.firstBufferReads.size() = " << crossbar.firstBufferReads.size() << ", crossbar.secondBuffer.size() = " << crossbar.secondBuffer.size() << ", Affine_WFs_in_crossbar = " << Affine_WFs_in_crossbar << ", left_affine_WFs = " << left_affine_WFs << std::endl;
		//}
	}
	
	
	
	totalUpdate1Locations += left_linear_WFs;
	totalUpdate2Locations += left_affine_WFs;
	numUpdate1 += max_reads_in_FIFO;
	numUpdate2 += 1 + ceil(max_reads_in_FIFO/NUM_COMPUTE_ROWS_PER_AFFINE_BUFFER);
	
	std::cout << "WF instances that are left when all reads were added. Linear WF instances = " << left_linear_WFs << std::endl;
	std::cout << "Affine WF instances = " << left_affine_WFs << std::endl;
	std::cout << "WF iterations that are left when all reads were added. Linear WF iterations (= max_reads_in_FIFO) = " << max_reads_in_FIFO << std::endl;
	std::cout << "Affine WF iterations = " << 1 + ceil(max_reads_in_FIFO/NUM_COMPUTE_ROWS_PER_AFFINE_BUFFER) << std::endl;
	
	if (COMPARISON_MODE) {
		compareDartPIMwithSW();
	}
	
}


void Simulator::emit(uint32_t readNum, uint32_t refLoc, int e){
	
	// Add the result of the read mapping to the readsResultsMap
    if(readsResultsMap.find(readNum) == readsResultsMap.end()) readsResultsMap.insert(std::pair<uint32_t,readResElement>(readNum,readResElement(refLoc,e)));
	//std::cout << "Simulator: emit - readNum = " << readNum << ", e = " << readsResultsMap.find(readNum)->second.e << std::endl;
    else if (readsResultsMap.find(readNum)->second.e > e) {
		//std::cout << "Simulator: emit - readNum = " << readNum << ", refloc = " << refLoc << ", e: " << e << " < " << readsResultsMap.find(readNum)->second.e << std::endl;
		readsResultsMap.find(readNum)->second.e = e;
		readsResultsMap.find(readNum)->second.refLoc = refLoc;
	}
    
}

void Simulator::emitSW(uint32_t readNum, uint32_t refLoc, int s){
	
	
	// Add the result of the Smith Waterman read mapping to the readsResultsMapSW
    if(readsResultsMapSW.find(readNum) == readsResultsMapSW.end()) readsResultsMapSW.insert(std::pair<uint32_t,readResElementSW>(readNum,readResElementSW(refLoc,s)));
	//std::cout << "Simulator: emitSW - readNum = " << readNum << ", s = " << readsResultsMapSW.find(readNum)->second.s << ", refLoc = " << readsResultsMapSW.find(readNum)->second.refLoc << std::endl;
    else if (readsResultsMapSW.find(readNum)->second.s < s) {
		//std::cout << "Simulator: emitSW - readNum = " << readNum << ", refLoc" << refLoc << ", s: " << s << " > " << readsResultsMapSW.find(readNum)->second.s << std::endl;
		readsResultsMapSW.find(readNum)->second.s = s;
		readsResultsMapSW.find(readNum)->second.refLoc = refLoc;
	}
    
}

void Simulator::compareDartPIMwithSW(){
	
	std::ofstream readsMappings ("readsMappings.txt");
	
	std::cout << std::endl;
	std::cout << "COMPARISON WITH SW:" << std::endl;
	std::cout << "Simulator: size readsResultsMapSW = " << readsResultsMapSW.size() << ", size readsResultsMap = " << readsResultsMap.size() << std::endl;
	std::cout << "Simulator: affineEth = " << affineEth << std::endl;
	std::cout << "Simulator: affineSth = " << affineSth << std::endl;
	std::cout << "Simulator: refLocDistance = " << refLocDistance << std::endl;
	//std::map<uint32_t,readResElementSW>::iterator itSW=readsResultsMapSW.begin();
	std::map<uint32_t,readResElementSW>::iterator itSW;
	for (std::map<uint32_t,readResElement>::iterator it=readsResultsMap.begin(); it!=readsResultsMap.end(); ++it) { 
		readsMappings << it->first << "," << it->second.refLoc << "," << it->second.e << std::endl;
		
		itSW = readsResultsMapSW.find(it->first);
		if(itSW == readsResultsMapSW.end()) continue;
		
		//std::cout << "Simulator: readnum = " << it->first << "  " << itSW->first << std::endl;
		//std::cout << "Simulator: it->second.e = " << it->second.e << ", itSW->second.s = " << itSW->second.s << std::endl;
		//std::cout << "Simulator: it->second.refLoc = " << it->second.refLoc << ", itSW->second.refLoc = " << itSW->second.refLoc << std::endl;
		if (it->second.e <= affineEth && itSW->second.s >= affineSth) { // Locations are found for both
			if ( abs(it->second.refLoc - itSW->second.refLoc) < refLocDistance ) {
				truePositive++; //Location of DART-PIM is close to SW location
				//std::cout << "Simulator: 1st 1st if - Locations are found for both and are close" << std::endl;
			}
			else {
				falsePositive++; //Location of DART-PIM is far from SW location
				//std::cout << "Simulator: 1st 2st if - Locations are found for both and are far" << std::endl;
			}
		}
		else if (it->second.e >= affineEth && itSW->second.s <= affineSth) { // Locations are not found for either
			trueNegative++;
			//std::cout << "Simulator: 2nd if - Locations are not found for either" << std::endl;
		}
		else if (it->second.e >= affineEth && itSW->second.s >= affineSth) { // Location is found only for SW
			falseNegative++;
			//std::cout << "Simulator: 3rd if - Location is found only for SW" << std::endl;
		}
		else if (it->second.e <= affineEth && itSW->second.s <= affineSth) { // Location is found only for DART-PIM
			falsePositive++;
			//std::cout << "Simulator: 4th if - Location is found only for DART-PIM" << std::endl;
		}

	}
	std::cout << "Simulator: truePositive = " <<  truePositive << ", falsePositive = " << falsePositive << ", trueNegative = " << trueNegative << ", falseNegative = " << falseNegative << std::endl;
	std::cout << std::endl;
	readsMappings.close();
}

std::ostream& operator<<(std::ostream& os, const Simulator& sim){

    return os << "Total number of minimizers of reads: " << sim.totnumAddMinimizers << 
			  std::endl << "Num linear WF iterations (update1): " << sim.numUpdate1 << ", Num affine WF iterations (update2): " << sim.numUpdate2 << 
			  std::endl << "Number of dumped minimizers of reads, since more reads in a crossbar than MAX_READS_PER_CROSSBAR = " << sim.numDumpedReads << 
			  std::endl <<
			  std::endl << "Total Linear WFs : " << sim.totalUpdate1Locations << ", Total Affine WFs : " << sim.totalUpdate2Locations <<
			  std::endl << "Total calculated affine WFs = " << sim.numAffineWFsCalculated << ", total NOT calculated affine WFs = " << sim.numAffineWFsNotCalculated <<
			  std::endl << "WFs that are left when all reads were added. For linear WFs = " << sim.left_linear_WFs << ", for affine WFs = " << sim.left_affine_WFs;
}

//Add to print total calculated linear WFs
