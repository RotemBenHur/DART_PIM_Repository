//
// Created by Orian Leitersdorf on 12/02/2023.
//

#include <fstream>
#include <iostream>
#include <cassert>

#include "utility.h"
#include "minimizer.h"

std::string loadFASTA(std::string filename){

    // Opens the file
    std::ifstream in;
    in.open(filename);

    std::string reference;
    // Read the rows of the file
    std::string s;
    getline(in, s);
	
    while(in){

        assert(s[0] == '>');

        getline(in, s);
				
        while(s[0] != '>' && in){
            reference += s;
            getline(in, s);
        }

    }

    return reference;

}

std::vector<std::string> loadFASTQ(std::string filename){

    // Opens the file
    std::ifstream in;
    in.open(filename);

    std::string s;
    std::vector<std::string> reads;

    while(in){

        getline(in, s);
        if(s.empty()) break;

        assert(s[0] == '@');

        getline(in, s);
        reads.push_back(s);
		
        getline(in, s);
        getline(in, s);

    }

    return reads;

}

MinimizerMap filterMinimizers(const MinimizerMap& minimizers){

    MinimizerMap pass;

    for(std::pair<uint32_t, std::vector<uint32_t> > minimizer : minimizers){
        if(minimizer.second.size() <= MAX_MINIMIZER_HITS){
            pass[minimizer.first] = minimizer.second;
        }
    }

    return pass;

}

std::pair<MinimizerMap, MinimizerMap> separateMinimizers(const MinimizerMap& minimizers){

    MinimizerMap low;
    MinimizerMap high;

    for(std::pair<uint32_t, std::vector<uint32_t> > minimizer : minimizers){
        if(minimizer.second.size() <= LOW_COUNT_MINIMIZER_THRESH){
            low[minimizer.first] = minimizer.second;
        }
        else{
            high[minimizer.first] = minimizer.second;
        }
    }

    return {low, high};

}

void saveMinimizers(const MinimizerMap& minimizers, std::string filename){

    std::ofstream out(filename);

    for(std::pair<uint32_t, std::vector<uint32_t> > minimizer : minimizers){
        out << minimizer.first << " ";
        for(uint32_t x : minimizer.second) out << x << " ";
        out << "-1";
        out << std::endl;
    }

}

MinimizerMap loadRefMinimizers(std::string &reference, std::string cache_filename){
    std::ifstream f(cache_filename);
    if(f.good()){
        return loadMinimizers(cache_filename);
    }
    else{
        MinimizerMap minimizers = findMinimizers(reference);
        saveMinimizers(minimizers, cache_filename);
        return minimizers;
    }
}

void saveMinimizersData(const MinimizerMap& minimizers, std::string filename){

    std::ofstream out(filename);

    for(std::pair<uint32_t, std::vector<uint32_t> > minimizer : minimizers){
        out << minimizer.second.size();
        out << std::endl;
    }

}

MinimizerMap loadMinimizers(std::string filename){

    MinimizerMap minimizers;

    std::ifstream in;
    in.open(filename);

    while(in){

        uint32_t minimizer;
        in >> minimizer;

        minimizers[minimizer] = std::vector<uint32_t>();

        int64_t x;
        while((in >> x) && (x != -1)){
            minimizers[minimizer].push_back((uint32_t)x);
        }

    }

    return minimizers;

}

