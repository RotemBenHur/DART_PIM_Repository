#ifndef DART_PIM_SIMULATOR_H
#define DART_PIM_SIMULATOR_H

#include <queue>
#include <ostream>
#include <iostream>
#include <fstream>

#include "utility.h"


/**
 * An entry with the edit distance result of a read (reference location and edit distance)
 */
struct readResElement{

    /**
     * The ref location
     */
    uint32_t refLoc;

    /**
     * The edit distance value
     */
    int e;

    /**
     * Initializes the given read result entry
     * @param refLoc
     * @param e
     */
    readResElement(uint32_t refLoc, int e) :
      refLoc(refLoc), e(e) {}

};

/**
 * An entry with the Smith Waterman result of a read (reference location and score)
 */
struct readResElementSW{

    /**
     * The ref location
     */
    uint32_t refLoc;

    /**
     * The Smith Waterman score value
     */
    int s;

    /**
     * Initializes the given read result entry
     * @param refLoc
     * @param s
     */
    readResElementSW(uint32_t refLoc, int s) :
      refLoc(refLoc), s(s) {}

}; 

/**
 * A read entry in the crossbar buffers
 */
struct ReadBufferElement{

    /**
     * The read of the entry
     */
    const char *read;

    /**
     * The read number
     */
    uint32_t readNum;

    /**
     * The start index of the minimizer in the read
     */
    uint32_t minimizerStart;

    /**
     * Initializes the given read buffer entry
     * @param read
     * @param readNum
     * @param minimizerStart
     */
    ReadBufferElement(const char *read, uint32_t readNum, uint32_t minimizerStart) :
      read(read), readNum(readNum), minimizerStart(minimizerStart) {}

};

/**
 * The reference segments stored in the crossbars
 */
struct ReferenceBufferElement{

    /**
     * The location of the minimizer in the reference
     */
    uint32_t refLoc;

    /**
     * The padded reference segment (N - k + eth from the left, N - k + eth to the right)
     */
    const std::string reference;

    /**
     * Initializes the reference buffer segment
     * @param refLoc
     * @param reference
     */
    ReferenceBufferElement(uint32_t refLoc, const std::string& reference) : refLoc(refLoc), reference(reference) {}

};

/**
 * Represents the data stored in a single crossbar
 */
struct Crossbar{

    /**
     * The queue of reads for the first buffer
     */
    std::queue<ReadBufferElement> firstBufferReads;
    /**
     * The reference segments stored in the crossbar
     */
    std::vector<ReferenceBufferElement> firstBufferReferences;

    /**
     * The read and reference pairs of the second buffer
     */
    std::queue<std::pair<ReadBufferElement, ReferenceBufferElement> > secondBuffer;
	/**
     * The number of reads that were mapped to this crossbar so far
     */
	long totReadsNum = 0;

};

/**
 * Manages the PIM crossbars for the PIM mapping
 */
class Simulator{

    long numAddMinimizers = 0; // Counts the number of minimizers of reads that are sent to the crossbars per iteration
	long totnumAddMinimizers = 0; // Counts the number of minimizers of all reads sent to the crossbars
	long numAddReads = 0; // Counts the number of all reads sent to the crossbars
	long numUpdate1 = 0; long totalUpdate1Crossbars = 0; long iterUpdate1Crossbars = 0; long totalUpdate1Locations = 0; long iterUpdate1Locations = 0;
    long numUpdate2 = 0; long totalUpdate2Crossbars = 0; long iterUpdate2Crossbars = 0; long totalUpdate2Locations = 0; long iterUpdate2Locations = 0;
	long numDumpedReads = 0; // Counts the number of reads that are dumed because a crossbar has a total of too many reads to take care of (according to MAX_READS_PER_CROSSBAR). Can count the same read with different minimizers !
	long numAffineWFsNotCalculated; 
	long numAffineWFsCalculated;
    
	uint32_t lastReadNum = -1;

	uint32_t left_linear_WFs = 0;
	uint32_t left_affine_WFs = 0;	
	
	uint32_t tmp_affine = 0;
	
	/**
	* The mapping accuracy parameters
	*/
	uint32_t truePositive = 0;
	uint32_t falsePositive = 0;
	uint32_t trueNegative = 0;
	uint32_t falseNegative = 0;
	const int affineEth = 40;
	const int affineSth = 140;//N-affineEth;
	const int refLocDistance = N;
	

    /**
     * The crossbars of the PIM memory
     */
    std::vector<Crossbar> crossbars;

    /**
     * A mapping from a minimizer to all of the crossbar indices that contain that minimizer
     */
    std::map<uint32_t, std::vector<uint32_t>> minimizerToCrossbar;
	
	/**
	* A map with readResult (reference location and edit distance) for each read
	*/
	std::map<uint32_t, readResElement> readsResultsMap;
	
	/**
	 * A map with readResultSW (reference location and score) for each read - for comparison 
	 */
	std::map<uint32_t, readResElementSW> readsResultsMapSW;

public:

    /**
     * Initializes the PIM simulator with the given reference and the given minimizers
     * @param reference
     * @param minimizers
     */
    Simulator(const std::string& reference, const MinimizerMap& minimizers);

    /**
     * Adds the given read-minimizer pair to the simulation
     * @param readNum
     * @param read
     * @param minimizerLoc
     * @param minimizer
     */
    void addRead(uint32_t readNum, const std::string& read, uint32_t minimizerLoc, uint32_t minimizer);

    /**
     * Performs a linear buffer update
     */
    void update1();

    /**
     * Performs an affine buffer update
     */
    void update2();
	
	/**
     * 
     */
    void done();
	
	/**
	* Emits that the given read is mapped to the given reference location with affine edit distance e
	*/
	void emit(uint32_t readNum, uint32_t refLoc, int e);
	
	/**
	* Emits that the given read is mapped to the given reference location with affine score s using Smith Waterman
	*/
	void emitSW(uint32_t readNum, uint32_t refLoc, int s);
	/**
	* Compares the readsResultsMap and readsResultsMapSW results and calculates the accuracy
	*/
	void compareDartPIMwithSW();

    friend std::ostream& operator<<(std::ostream& os, const Simulator& sim);

};

std::ostream& operator<<(std::ostream& os, const Simulator& sim);

#endif //DART_PIM_SIMULATOR_H
