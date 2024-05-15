#ifndef DART_PIM_MAPPER_H
#define DART_PIM_MAPPER_H

#include <vector>
#include <string>
#include "utility.h"

class Mapper {

protected:

    /**
     * The overall reference
     */
    std::string reference;

    /**
     * The overall minimizer map of the reference
     */
    MinimizerMap refMinimizers;

    /**
     * The map of the low occurrence minimizers
     */
    MinimizerMap lowMinimizers;
    /**
     * The map of the high occurrence minimizers
     */
    MinimizerMap highMinimizers;
	/**
     * The map of the reads minimizers
     */
    MinimizerMap allReadsMinimizers;

    /**
     * Initializes the mapper with the given reference
     * @param reference
     */
    Mapper(std::string reference);

public:

    /**
     * Maps the given reads to the reference
     * @param reads
     * @return
     */
    virtual std::vector<uint32_t> mapReads(std::vector<std::string> reads) = 0;

};


#endif //DART_PIM_MAPPER_H
