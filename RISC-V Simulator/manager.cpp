
#include "manager.h"

/*============================================= Kmer ===============================================*/
/*==================================================================================================*/

Kmer::Kmer(int pos, const string &kmerSeq) : position(pos), kmerSeq(kmerSeq) {}
Kmer::Kmer(const Kmer &kmer): position(kmer.position), kmerSeq(kmer.kmerSeq) {}

/*==================================================================================================*/
/*==================================================================================================*/




/*======================================= RefGenomeMinimizer =======================================*/
/*==================================================================================================*/

RefGenomeMinimizer::RefGenomeMinimizer(Kmer minimizer, string refSegment): minimizer(minimizer), refSegment(refSegment) {
    refSegmentPosition = minimizer.position - (READ_LENGTH- KMER_LENGTH + ERROR_THRESHOLD);
}


int RefGenomeMinimizer::getWFSeq(int readMinimizerPosition, string* refSubSeq){
    int refSubSeqPosition = minimizer.position - readMinimizerPosition; // The location of the ref sub sequence relative to the whole genome;
    refSubSeqPosition -= refSegmentPosition; // The location of the ref sub sequence relative to the refSegment;
    refSubSeqPosition -= ERROR_THRESHOLD; // Adding the error threshhold
    *refSubSeq = refSegment.substr(refSubSeqPosition, REF_SUB_SEQUENCE_LENGTH);
    return refSubSeqPosition + refSegmentPosition; // location in refGenome
}

void RefGenomeMinimizer::print(){
    std::cout << "minimizer: " << minimizer.kmerSeq << endl;
    std::cout << "minimizer position (in reference genome): " << minimizer.position << endl;
    std::cout << "reference segment: " << refSegment << endl;
}

/*==================================================================================================*/
/*==================================================================================================*/






/*========================================= ReadMinimizer ==========================================*/
/*==================================================================================================*/

ReadMinimizer::ReadMinimizer(Kmer minimizer) : minimizer(minimizer) {}

void ReadMinimizer::print(){
    if (score != -1) {
        std::cout << "---------------" << endl;
        std::cout << "minimizer: " << minimizer.kmerSeq << endl;
        std::cout << "minimizer position (in read): " << minimizer.position << endl;
        std::cout << "read potential location: " << readPotentialLocation << endl;
        std::cout << "score: " << score << endl;
        std::cout << "---------------" << endl;
    }

}


/*========================================= ReadResultPIM ==========================================*/
/*==================================================================================================*/

ReadResultPIM::ReadResultPIM(int readIndex, int position, int score): readIndex(readIndex),
                                                                      position(position), score(score) {};


/*==================================================================================================*/
/*==================================================================================================*/





void convertSeq2Nums(string& seq){
    for(int i = 0; i < seq.size(); i++){
        switch(seq[i]){
            case 'A':
            case 'a':
                seq[i] = '0' + A;
                break;
            case 'C':
            case 'c':
                seq[i] = '0' + C;
                break;
            case 'G':
            case 'g':
                seq[i] = '0' + G;
                break;
            case 'T':
            case 't':
                seq[i] = '0' + T;
                break;
                //case 'N':   // Unknown letter, could be every letter
                //   seq[i] = '0' + (rand() % 4);
            default:
                seq[i] = seq[i];
                //std:cout << "Can't convert seq element " << seq[i] << "to number representasion" << endl;
        }
    }
}

/*============================================= Read ===============================================*/
/*==================================================================================================*/

Read::Read(string readSeq) {
    vector<Kmer> readMinimizers = findMinimizers(readSeq);
    convertSeq2Nums(readSeq);
    this->seq = readSeq;

    for(Kmer minimizer : readMinimizers){
        ReadMinimizer readMinimizer(minimizer);
        this->minimizers.push_back(readMinimizer);
    }
}


uint32_t invertibleHash(uint32_t x){
    uint32_t m = UINT_MAX;
    x = (~x + (x << 21)) & m;
    x = x ^ (x >> 24);
    x = (x + (x << 3) + (x << 8)) & m;
    x = x ^ (x >> 14);
    x = (x + (x << 2) + (x << 4)) & m;
    x = x ^ (x >> 28);
    x = (x + (x << 31)) & m;
    return x;
}
/**
 * Phi for a single character
 */
uint32_t RHO[26] = {0, 0, 1, 0, 0, 0, 2, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 3, 0, 0, 0, 0, 0, 0};
/**
 * Conversion from k-mer to dtype
 * @param s k-mer above (A, C, G, T)
 * @return hash
 */
uint32_t rho(std::string s){
    uint32_t out = 0;
    for(uint32_t i = 0; i < KMER_LENGTH; i++){
        out += RHO[s[i] - 'A'] << (2 * (KMER_LENGTH - i - 1));
    }
    return out;
}
/**
 * Hashing function on k-mers
 * @param s k-mer above (A, C, G, T)
 * @return hash
 */
uint32_t phi(std::string s) {
    return invertibleHash(rho(s));
}

std::vector<Kmer> Read::findMinimizers(string s) {

    std::map<uint32_t, std::vector<uint32_t>> minimizers;
    std::vector<Kmer> returnedMinimizers;

    std::vector<uint32_t> buffer(WINDOW_SIZE, 0);
    for(uint32_t i = 0; i < WINDOW_SIZE; i++) {
        buffer[i] = phi(s.substr(i, KMER_LENGTH));
    }

    uint32_t prev_selection = UINT_MAX;
    uint32_t prev_value = UINT_MAX;
    uint32_t size = s.size();
    uint32_t limit = size - KMER_LENGTH + 1 - WINDOW_SIZE + 1;

    for(uint32_t i = 0; i < limit; i++) {
        uint32_t iter = 0;
        for(uint32_t j = 1; j < WINDOW_SIZE; j++) {
            if(buffer[j] < buffer[iter]) {
                iter = j;
            }
        }

        uint32_t idx = i + ((iter) - (i % WINDOW_SIZE) + WINDOW_SIZE) % WINDOW_SIZE;
        uint32_t hash = buffer[iter];

        if(idx != prev_selection && (i == 0 || prev_selection == i - 1 || hash < prev_value)) {
            uint32_t val = rho(s.substr(idx, KMER_LENGTH));
            minimizers[val].push_back(idx);

            prev_selection = idx;
            prev_value = hash;
        }

        if (i + WINDOW_SIZE < size - KMER_LENGTH + 1) {
            buffer[i % WINDOW_SIZE] = phi(s.substr(i + WINDOW_SIZE, KMER_LENGTH));
        }
    }

    for (const auto &pair : minimizers) {
        uint32_t minSeq = pair.first;
        const std::vector<uint32_t> &locations = pair.second;
        for (const uint32_t &minLocation : locations) {
            Kmer kmer((int)(minLocation), std::to_string(minSeq));
            returnedMinimizers.push_back(kmer);
        }
    }

    return returnedMinimizers;
}

void Read::print(){
    std::cout << "--------------Printing Read Data--------------" << endl;
    std::cout << "Read Sequence: " << seq << endl;
    std::cout << "Minimizers:" << endl;
    for(ReadMinimizer minimizer : minimizers){
        minimizer.print();
    }
    std::cout << "----------------------------------------------" << endl;
}


/*==================================================================================================*/
/*==================================================================================================*/







/*==================================================================================================*/
/*==================================================================================================*/


/*==================================================================================================*/
/*==================================================================================================*/






/*============================================= Manager ============================================*/
/*==================================================================================================*/
Manager::Manager(CPUMinimizers CPUMins, vector<Read> reads, PIMReads results){
    this->CPUMins = CPUMins;
    this->reads = reads;
    this->numRunningJobs = 0;
    this->PIMReadsResults = results;
}

void Manager::handleReads(){
    int numofReads = 0;
    // go over all reads
    for(Read& read : reads) {
        // go over all minimizers of a read
        for(ReadMinimizer& readMinimizer : read.minimizers){
            // go over the CPU minimizers and check if this minimizer is there

            auto refMinimizer = CPUMins.find(readMinimizer.minimizer.kmerSeq);
            if (refMinimizer != nullptr) {
                string refSeq;
                // get the sub reference segment to send to WF
                readMinimizer.readPotentialLocation = refMinimizer->getWFSeq(readMinimizer.minimizer.position, &refSeq);
                readMinimizer.refSubSeq = refSeq;
                wagnerFischerAffineGap(read.seq, refSeq, &readMinimizer.score,
                        &readMinimizer.mapping, false, 1, 1, 1);
                numofReads++;
            }

        }
    }
}


void Manager::reconstructGenome() {
    int minScore = REF_SUB_SEQUENCE_LENGTH;
    int readIndex = 0;
    vector<int> readLocations;
    ReadMinimizer minReadMinimizer(Kmer(0,""));
    bool pimFlag = false;

    for(Read& read : reads) {
        for(ReadMinimizer& readMinimizer : read.minimizers){
            if (readMinimizer.score < minScore && readMinimizer.score != -1) {
                minScore = readMinimizer.score;
                ReadMinimizer minReadMinimizer(readMinimizer);
            }
        }
        if (PIMReadsResults[readIndex].score < minScore) {
            pimFlag = true;
        }
        minScore = REF_SUB_SEQUENCE_LENGTH;
        wagnerFischerAffineGap(read.seq, minReadMinimizer.refSubSeq,&minReadMinimizer.score,
                               &minReadMinimizer.mapping,true,1,1,1);
        if (pimFlag)
            readLocations.push_back(PIMReadsResults[readIndex].position);
        else
            readLocations.push_back(minReadMinimizer.readPotentialLocation);
        readIndex++;
        pimFlag = false;
        //genome.replace(minReadMinimizer.readPotentialLocation, READ_LENGTH,minReadMinimizer.mapping);
    }
}

void Manager::wagnerFischerAffineGap(const string& S1, const string& S2, int* score, string* readMapping, bool backtraching, int wop, int wex, int wsub) {
    const int n = S1.size();
    const int m = S2.size();
    vector<int> contenders;
    int minCon = 0;
    string seq1_align = "";
    string seq2_align = "";

    int D[REF_SUB_SEQUENCE_LENGTH+1][READ_LENGTH+1] = {0};
    int M1[REF_SUB_SEQUENCE_LENGTH+1][READ_LENGTH+1] = {0};
    int M2[REF_SUB_SEQUENCE_LENGTH+1][READ_LENGTH+1] = {0};

    const int max_gap = 2*ERROR_THRESHOLD;
    const int max_gap_penalty = max_gap + wop;

    // Fill the DP tables using dynamic programming
    for (int i = 1; i <= n; ++i) {
        for (int j = 1; j <= m; ++j) {
            if (abs(i - j) <= max_gap) {
                if (abs (i - 1 - j) > max_gap) {
                    M1[i - 1][j] = max_gap_penalty;
                    D[i - 1][j] = max_gap_penalty;
                }
                if (abs (i - (j - 1)) > max_gap) {
                    M2[i][j - 1] = max_gap_penalty;
                    D[i][j - 1] = max_gap_penalty;
                }

                M1[i][j] = min(M1[i - 1][j] + wex, D[i - 1][j] + wop + wex);
                M2[i][j] = min(M2[i][j - 1] + wex, D[i][j - 1] + wop + wex);
                if (S1[i - 1] == S2[j - 1])
                    D[i][j] = D[i - 1][j - 1];
                else
                    D[i][j] = min({(M1[i][j]), M2[i][j], D[i - 1][j - 1] + wsub});
            }
        }
    }
    *score = D[n][m];

    // find the alignment of the read according to sub reference sequence
    if(backtraching) {
        int i = n, j = m;
        while (i > 0 && j > 0 && D[i][j] > 0) {
            contenders = {D[i - 1][j - 1], D[i - 1][j], D[i][j - 1]};
            minCon = *(std::min_element(contenders.begin(), contenders.end()));

            if (minCon == contenders[0]) {
                if (S1[i - 1] != S2[j - 1]) {
                    seq1_align += S2[i - 1];
                    seq2_align += S2[j - 1];
                } else {
                    seq1_align += S1[i - 1];
                    seq2_align += S2[j - 1];
                }
                i -= 1;
                j -= 1;
            } else if (minCon == contenders[1]) {
                seq1_align += S1[i - 1];
                seq2_align += "-";
                i -= 1;
            } else {
                seq1_align += "-";
                seq2_align += S2[j - 1];
                j -= 1;
            }

        }

        std::reverse(seq1_align.begin(), seq1_align.end());
        std::reverse(seq2_align.begin(), seq2_align.end());
        *readMapping = seq1_align;
    }

    runningJobsMtx.lock();
    numRunningJobs--;
    runningJobsMtx.unlock();
}


void Manager::printReads(){
    int i = 0;
    std::cout << "--------------Printing Reads--------------" << endl;
    for(Read read : reads){
        std::cout << "Read " << i << ":" << endl;
        read.print();
        i++;
    }
    std::cout << "------------------------------------------" << endl;
}

/*==================================================================================================*/
/*==================================================================================================*/








/*============================================= Main ===============================================*/
/*==================================================================================================*/

void print_help(){
    std::cout << "------------------------------------------------ HELP ------------------------------------------------------" << endl;
    std::cout << "Two running modes:" << endl;
    std::cout << "   ./DART_PIM -rand                                                 :   will randomize reads and CPU minimizers" << endl;
    std::cout << "   ./DART_PIM -reads /path/to/reads/file -mins /path/to/mins/file   :   will run on cpecified reads and mins" << endl;
    std::cout << "------------------------------------------------------------------------------------------------------------" << endl;
}

/**
 * parsing file in which contains reads
 * @param readsFile reads above (A, C, G, T)
 * @param reads vector of reads that contain the reads from the file
 * @return void
 */
void getReadsFromFile(ifstream& readsFile, vector<Read>& reads){
    string line;
    //skip first line
    if(!getline(readsFile, line)){
        std::cout << "MSG: Reads file is empty." << line << endl;
        return;
    }
    while(getline(readsFile, line)){
        Read read(line);
        reads.push_back(read);

        //skip two lines
        for(int i = 0; i < 3; i++){
            if(!getline(readsFile, line)){
                break;
            }
        }
    }
}

/**
 * parsing file in which contains minimizers that the CPU is responsible,
 * their position in the reference genome and reference segment
 * @param minsFile minimizers above (A, C, G, T)
 * @param CPUMins vector of minimizers that the CPU is responsible
 * @return void
 */
void getCPUMinsFromFile(ifstream& minsFile, CPUMinimizers& CPUMins) {
    string line;
    string refSegment;
    string kmerSeq;
    string position;

    while (getline(minsFile, line)) {
        stringstream lineStream(line);
        getline(lineStream, kmerSeq , ',');
        getline(lineStream, position, ',');
        getline(lineStream, refSegment, ',');

        Kmer minimizer(stoi(position),kmerSeq);
        convertSeq2Nums(refSegment);
        RefGenomeMinimizer row(minimizer, refSegment);
        CPUMins.insert(row.minimizer.kmerSeq, row);
    }
}

/**
 * parsing file in which contains the read results that PIM calculated
 * @param minsFile readsMapFile
 * @param CPUMins vector of PIM results
 * @return void
 */
void getReadsMapFromFile(ifstream& readsMapFile, PIMReads& PIMResults) {
    string line;
    string readIndex;
    string position;
    string score;

    while (getline(readsMapFile, line)) {
        stringstream lineStream(line);
        getline(lineStream, readIndex , ',');
        getline(lineStream, position, ',');
        getline(lineStream, score, ',');
        ReadResultPIM row(stoi(readIndex), stoi(position), stoi(score));
        PIMResults.push_back(row);
    }
}


int main(int argc, char* argv[]) {

    vector<Read> reads;
    CPUMinimizers CPUMins;
    PIMReads PIMResults;
    ifstream readsFile;
    ifstream minsFile;
    ifstream pimResultFile;
    bool readsFileOpen = false;
    bool minsFileOpen = false;
    bool pimFileOpen = false;
    int numOfReads = 100; //relevant to the rand running option

    if(argc == 7 && string(argv[1]) == "-reads" && string(argv[3]) == "-mins" && string(argv[5]) == "-pim") {
        readsFile = ifstream(argv[2]);
        readsFileOpen = readsFile.is_open();
        if (!readsFileOpen) {
            std::cout << "ERROR: Can't open file " << string(argv[2]) << endl;
            return 1;
        }

        minsFile = ifstream(argv[4]);
        minsFileOpen = minsFile.is_open();
        if (!minsFileOpen) {
            std::cout << "ERROR: Can't open file " << string(argv[4]) << endl;
            return 1;
        }

        pimResultFile = ifstream(argv[6]);
        pimFileOpen = pimResultFile.is_open();
        if (!pimFileOpen) {
            std::cout << "ERROR: Can't open file " << string(argv[6]) << endl;
            return 1;
        }
        getReadsFromFile(readsFile, reads);

        getCPUMinsFromFile(minsFile, CPUMins);

        getReadsMapFromFile(pimResultFile, PIMResults);

    }
    else if(argc == 2 && string(argv[1]) == "-help"){
        print_help();
        return 0;
    }
    else{
        std::cout << "ERROR: Invalid Arguments. See help: (run with -help)" << endl;
        print_help();
        return 1;
    }


    Manager manager(CPUMins, reads, PIMResults);

    manager.handleReads();

    //manager.printReads();

    manager.reconstructGenome();



    if(readsFileOpen){
        readsFile.close();
    }

    if(minsFileOpen){
        minsFile.close();
    }

    return 0;
}

/*==================================================================================================*/
/*==================================================================================================*/