
#define MAX_RUNNING_JOBS 3 // Max threads CPU can handle
// Nucleotides
#define A 0
#define C 1
#define G 2
#define T 3

#define KMER_LENGTH                12 
#define WINDOW_SIZE                4 //TODO: What window size does Rotem use?
#define READ_LENGTH                150
#define ERROR_THRESHOLD            3
#define REF_SUB_SEQUENCE_LENGTH    READ_LENGTH + 2 * ERROR_THRESHOLD
#define REF_GENOME_LENGTH          3000000000

#include <iostream>
#include <vector>
#include <algorithm>
#include <unordered_set>
#include <deque>
#include <map>
#include <thread>
#include <cstdlib>
#include <ctime>
#include <fstream>
#include <mutex>
#include <sstream>
#include <climits>
#include <list>
#include <utility>
#include <functional> // for std::hash
#include <chrono>
#include <queue>
#include <unordered_map>
#include <functional> // for std::greater


using namespace std;

// This is class that represent Kmer and its position in the genome
class Kmer {
public:
    int position;
    string kmerSeq;

    Kmer(int, const string &);
    Kmer(const Kmer&);
};


//This is a row in the CPU minimizers list
class RefGenomeMinimizer {
public:
    Kmer   minimizer;  // Position is relative to the whole reference genome.     
    string refSegment; // Reference segment, the minimizer is in the middle (sort of).
    int    refSegmentPosition; // The position of the refSegment relative to the whole genome.

    RefGenomeMinimizer(Kmer, string);
    int getWFSeq(int, string*); // Extracts the relevant subRefSegment to send to WF. returns the potential location in refGenome. 
    void print();
};
//This is a row in the reads mapping list
class ReadResultPIM {
public:
    int readIndex;
    int position;
    int score;

    ReadResultPIM(int readIndex, int position, int score);

};

// Hash table class that will contain the minimizers the cpu is responsible
template <typename K, typename V>
class HashTable {
private:
    std::vector<std::list<std::pair<K, V>>> table;
    int numBuckets;
    int size;

    int getBucketIndex(const K& key) const {
        std::hash<K> hashFunc;
        return hashFunc(key) % numBuckets;
    }


public:
    HashTable(int buckets = 10000) : numBuckets(buckets), size(0) {
        table.resize(numBuckets);
    }

    bool insert(const K& key, const V& value) {
        int bucketIndex = getBucketIndex(key);
        for (auto& pair : table[bucketIndex]) {
            if (pair.first == key) {
                // Key already exists, update value
                pair.second = value;
                return true;
            }
        }
        // Key does not exist, insert new pair
        table[bucketIndex].emplace_back(key, value);
        size++;
        return true;
    }

    bool remove(const K& key) {
        int bucketIndex = getBucketIndex(key);
        auto& bucket = table[bucketIndex];
        for (auto it = bucket.begin(); it != bucket.end(); ++it) {
            if (it->first == key) {
                bucket.erase(it);
                size--;
                return true;
            }
        }
        return false; // Key not found
    }


    V* find(const K& key) {
        int bucketIndex = getBucketIndex(key);
        for (auto& pair : table[bucketIndex]) {
            if (pair.first == key) {
                return &pair.second;
            }
        }
        return nullptr; // Key not found
    }
};


// This is the CPU minimizers list type
typedef vector<ReadResultPIM> PIMReads;

// This is the CPU minimizers list type
typedef HashTable<string,RefGenomeMinimizer> CPUMinimizers;


// This is a type for a minimizer of a read
// Eventually it will get a score and a potenatial_location in the ref genome(either from CPU or DART-PIM)
class ReadMinimizer{
public:
    Kmer minimizer; // Position is relative to the read. 
    int score;      // WF score
    int readPotentialLocation; // potential location of the read in the genome
    string refSubSeq;          // reference sub-sequence of the minimizer
    string mapping;            // mapping result from the WF

    ReadMinimizer(Kmer);
    void print();
};

// This is a type for a read. it hase a minimizers list and a location (will be updated eventualy based on the scores of the minimizers)
class Read{
public:
    string                seq;
    vector<ReadMinimizer> minimizers;
    int                   location;  // This is the actual result (location in the whole refrence genome).

    Read(string);
    /**
    * find the minimizers of the read
    * @param s read above (A, C, G, T)
    * @return hash
    */
    std::vector<Kmer> findMinimizers(string s);
    void print();
};


//This is the manager type. 
class Manager{
public:

    CPUMinimizers       CPUMins; // List of cpu minimizers
    vector<Read>        reads; // Reads to handle
    int                 numRunningJobs; // Holds the current number of WF running threads
    mutex               runningJobsMtx; // The WF function reduces the number of running threads when its done. This is a shared variable across all WF jobs, protecting it with mutex.
    string              genome;         // the reconstructed genome
    PIMReads            PIMReadsResults;


    Manager(CPUMinimizers, vector<Read>, PIMReads results);

    /**
     * loop over the reads, for minimizers that the CPU is responsible: calculate WF of the
     * read and corresponding sub reference segment
     * @return void
     */
    void handleReads();
    /**
     * calculate Wanger Fischer affine gap algorithm for two strings and saves the score and the mapping
     * @return int - score
     */
    void wagnerFischerAffineGap(const string& S1, const string& S2, int* score, string* readMapping, bool backtracking, int wop=1, int wex=1, int wsub=1);
    /**
     * loop over the reads, and for each read check the minimizer with the lowest score.
     * the location of the read in the genome is the location of the sub reference segment
     * @return void
     */
    void reconstructGenome();

    void printReads();
    void printCPUMinimizers();
};

namespace std {
    template<>
    struct hash<Kmer> {
        std::size_t operator()(const Kmer &m) const {
            return std::hash<std::string>()(m.kmerSeq);
        }
    };

    template<>
    struct hash<ReadMinimizer> {
        std::size_t operator()(const ReadMinimizer &rm) const {
            return std::hash<Kmer>()(rm.minimizer);
        }
    };
}

