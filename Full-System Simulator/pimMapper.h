#ifndef DART_PIM_PIMMAPPER_H
#define DART_PIM_PIMMAPPER_H

#include "mapper.h"
#include "simulator.h"

class PIMMapper : Mapper{

    /** The simulator for the PIM crossbars */
    Simulator simulator;

public:

    /**
     * Initializes the PIM mapper given the reference
     */
    PIMMapper(std::string reference);

    /**
     * Processes the given reads and returns the best locations
     * @param reads
     * @return
     */
    std::vector<uint32_t> mapReads(std::vector<std::string> reads);

};


#endif //DART_PIM_PIMMAPPER_H
