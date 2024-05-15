//
// Created by Orian Leitersdorf on 02/02/2023.
//

#ifndef DART_PIM_MINIMIZER_H
#define DART_PIM_MINIMIZER_H

#include <map>
#include <string>

/**
 * Computes the minimizers for the given string and returns them as a map from minimizer value to locations
 * @param s the given string above {A, T, C, G}
 * @return the minimizers of the string (map from minimizer value to list of locations for that minimizer)
 */
std::map<uint32_t, std::vector<uint32_t> > findMinimizers(std::string s);

#endif //DART_PIM_MINIMIZER_H
