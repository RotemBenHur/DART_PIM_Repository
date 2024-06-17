

#ifndef DART_PIM_UTILITY_H
#define DART_PIM_UTILITY_H

#include <string>
#include <vector>
#include <map>
#include <cmath>


/**
 * When COMPARISON_MODE is true, the affine Smith Waterman is calculated and compared to DART-PIM results
 */
constexpr bool COMPARISON_MODE = true;
/**
 * Minimizer k-mer length
 */
constexpr int K = 12;
/**
 * Minimizer window length
 */
constexpr int W = 30;
/**
 * Read length
 */
constexpr int N = 150;
/**
 * The assumed error threshold
 */
constexpr int ETH = 6;

/**
 * Minimizers with more than this number of hits will be excluded
 */
constexpr uint32_t MAX_MINIMIZER_HITS = 10000;  
/**
 * Crossbars with more reads than this number will stop adding reads
 */
constexpr uint32_t MAX_READS_PER_CROSSBAR = 500;
/**
 * The number of rows in the buffers in the crossbar
 */
constexpr uint32_t NUM_ROWS_PER_READS_BUFFER = 160;
constexpr uint32_t NUM_ROWS_PER_LINEAR_BUFFER = 32; 
constexpr uint32_t NUM_ROWS_PER_AFFINE_BUFFER = 64;
constexpr uint32_t NUM_COMPUTE_ROWS_PER_AFFINE_BUFFER = NUM_ROWS_PER_AFFINE_BUFFER/4;
 
/**
 * The threshold for a "low-count" minimizer that is handled by the RISC-V
 */
constexpr uint32_t LOW_COUNT_MINIMIZER_THRESH = 3; 
/**
 * The sizes of each crossbar
 */
constexpr uint32_t NUM_ROWS_PER_CROSSBAR = NUM_ROWS_PER_READS_BUFFER+NUM_ROWS_PER_LINEAR_BUFFER+NUM_ROWS_PER_AFFINE_BUFFER;
constexpr uint32_t NUM_COLS_PER_CROSSBAR = 1024;
constexpr uint32_t CROSSBAR_SIZE_BITS = NUM_ROWS_PER_CROSSBAR*NUM_COLS_PER_CROSSBAR;
/**
 * The number of reads in the reads buffer
 */
constexpr uint32_t NUM_READS_IN_BUFFER = NUM_ROWS_PER_READS_BUFFER*floor(NUM_COLS_PER_CROSSBAR/(N*2));
/**
 * A vector with locations for each minimizer
 */
typedef std::map<uint32_t, std::vector<uint32_t> > MinimizerMap;

/**
 * Loads the given FASTA file and returns the reference as a single string
 * @param filename
 * @return
 */
std::string loadFASTA(std::string filename);

/**
 * Loads the given FASTQ file and returns the reads as a vector of strings
 * @param filename
 * @return
 */
std::vector<std::string> loadFASTQ(std::string filename);

/**
 * Filters the minimizers according to MAX_MINIMIZER_HITS
 * @param minimizers
 * @return
 */
MinimizerMap filterMinimizers(const MinimizerMap& minimizers);

/**
 * Separates the minimizers according to low vs high hit count
 * @param minimizers
 * @return
 */
std::pair<MinimizerMap, MinimizerMap> separateMinimizers(const MinimizerMap& minimizers);

/**
 * Saves the minimizer map to a given file
 * @param minimizers
 * @param filename
 */
void saveMinimizers(const MinimizerMap& minimizers, std::string filename);

/**
 * Loads the reference minimizers from the minimizer cache (and computes otherwise)
 * @param reference
 * @param cache_filename
 * @return
 */
MinimizerMap loadRefMinimizers(std::string &reference, std::string cache_filename = "GRCh38_latest_genomic.min");

/**
 * Saves the minimizer appearances frequency to a given file
 * @param minimizers
 * @param filename
 */
void saveMinimizersData(const MinimizerMap& minimizers, std::string filename);

/**
 * Loads the minimizer map from a given file
 * @param filename
 * @return
 */
MinimizerMap loadMinimizers(std::string filename);



#endif //DART_PIM_UTILITY_H
