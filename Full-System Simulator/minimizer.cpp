//
// Created by Orian Leitersdorf on 02/02/2023.
//

#include <climits>
#include <vector>
#include <fstream>
#include <iostream>


#include "minimizer.h"
#include "utility.h"

/**
 * Invertible hash function used for minimizer computation
 * @param x input
 * @return hash
 */
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
    for(uint32_t i = 0; i < K; i++){
        out += RHO[s[i] - 'A'] << (2 * (K - i - 1));
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

std::map<uint32_t, std::vector<uint32_t> > findMinimizers(std::string s){

    std::map<uint32_t, std::vector<uint32_t> > minimizers;

    // Fill the buffer with the first w values
    std::vector<uint32_t> buffer(W, 0);
    for(uint32_t i = 0; i < W; i++) buffer[i] = phi(s.substr(i, K));

    uint32_t prev_selection = UINT_MAX;
    uint32_t prev_value = UINT_MAX;
    for(uint32_t i = 0; i < s.size() - (K - 1) - (W - 1); i++){

        // Choose the k-mer with the lowest value in the buffer
        uint32_t iter = 0;
        for(uint32_t j = 1; j < W; j++){
            if(buffer[j] < buffer[iter]){
                iter = j;
            }
        }
        uint32_t idx = i + ((iter) - (i % W) + W) % W;
        uint32_t hash = buffer[iter];
        if(idx != prev_selection && (i == 0 || prev_selection == i - 1 || hash < prev_value)){
            uint32_t val = rho(s.substr(idx, K));
            if(minimizers.find(val) == minimizers.end()) minimizers[val] = std::vector<uint32_t>();
            minimizers[val].push_back(idx);
			//std::cout << "Minimizer: minimizer_rho: " << val << "   minimizer: " << s.substr(idx, K) << "   location: " << idx << std::endl;
			
            prev_selection = idx;
            prev_value = hash;
        }

        buffer[i % W] = phi(s.substr(i + W, K));

        //if(i % (s.size() / 100) == 0) std::cout << "Minimizer: " << i / (s.size() / 100) << std::endl;

    }

	//std::cout << "Minimizer: number of minimizers: " << minimizers.size() << std::endl;

    return minimizers;

}

