# DART-PIM - Full-System Simulator
DART-PIM: DNA read mApping acceleRaTor Using Processing-In-Memory
Full-System Simulator: C++ simulator that emulates the entire DART-PIM operation. It incorporates the full-size PIM memory and executes all (offline and online) stages of read mapping using the aforementioned datasets. During the offline phase, the simulator partitions the reference genome into crossbars, and then conducts seeding, filtering, and read alignment. The simulator also provides
the exact number of linear and affine WF instances and iterations performed by DART-PIM throughout the process.
Additionally, it quantifies the total utilized memory capacity and the resulting read-mapping accuracy.

## Dependencies
In order to run the Full-System Simulator, you will need a Linux machine with:
1. Python 3

## Manual
1. **Download**: all Full-System Simulator files

2. **Configure**: 

In main.cpp - define the input reference and read files, for example:
```ini
// Load the reference
std::string ref_filename = "data/GRCh38_latest_genomic.fna";

// Load the reads
std::string reads_filename = "data/HG002.hiseqx.pcr-free.30x.R1.fastq";
```

In utility.h - 

a. Define the working mode:
```ini
/**
 * When COMPARISON_MODE is true, the affine Smith Waterman is calculated and compared to DART-PIM results
 */
constexpr bool COMPARISON_MODE = true;
```

b. Define all Wagner-Fischer parameters:
```ini
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
```

c. Define all read mapping parameters:
```ini
/**
 * Minimizers with more than this number of hits will be excluded
 */
constexpr uint32_t MAX_MINIMIZER_HITS = 10000;  
/**
 * Crossbars with more reads than this number will stop adding reads
 */
constexpr uint32_t MAX_READS_PER_CROSSBAR = 50000;
```

d. Define all crossbar parameters:
```ini
/**
 * The number of rows in the buffers in the crossbar
 */
constexpr uint32_t NUM_ROWS_PER_READS_BUFFER = 160;
constexpr uint32_t NUM_ROWS_PER_LINEAR_BUFFER = 32; 
constexpr uint32_t NUM_ROWS_PER_AFFINE_BUFFER = 64;
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
```

3. **Run**:

Open build directory:
```sh
cd build/  
```

Compile:
```sh
make  
```

Run:
```sh
cd ../  

./build/dart
```