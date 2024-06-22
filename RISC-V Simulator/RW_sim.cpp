#include <iostream>
#include <fstream>
#include <cstdint>

#define WRITE_SIZE 162 // READ + MINIMIZER
#define NUM_WRITES_EACH_LNEAR 12095 //num read-minimizer pairs / num_writes_total (nume_writes_total = num_linear_iterations_total = 254710)
#define READ_SIZE 805717782525 
#define CMD_SIZE 8 // in bytes
#define BYTE 8 
#define WRITE_FILE "write_file.txt"
#define READ_FILE "read_file.txt"
#define NUM_AFFINE 10 // THIS IS THE REAL VALUE : 15908, mult the sim time by 15908/10 to get the real time
#define NUM_LINEAR 16 // The total num of linear comps (254710) devided by NUM_AFFINE 
#define NUM_LINEAR_CMDS 23707 // Defined by WF matrix size (number of cells)
#define NUM_AFFINE_CMDS 71121 // Defined by WF matrix size (number of cells) * 3 (3 matrices)

using namespace std;

int main(){

    ofstream writeFile(WRITE_FILE);
    ifstream readFile(READ_FILE);

    char writeData[WRITE_SIZE];
    char readData[1];
    char cmd[CMD_SIZE];
/*
    // generate write data (read + minimizers)
    for(int i = 0; i < WRITE_SIZE; i++){
        writeData[i] = 'a';
    }

    //generate cmd data
    for (int i = 0; i < CMD_SIZE; i++){
        cmd[i] = 'b';
    }

    if(!writeFile.is_open()) {
        perror("cant open write file");
    }

    if(!readFile.is_open()) {
        perror("cant open read file");
    }

    for(int affine_it = 0; affine_it < NUM_AFFINE; affine_it++){
        for(int linear_it = 0; linear_it < NUM_LINEAR; linear_it++) {
            std::cout << "writing for " << linear_it << " linear iteration" << std::endl;
            // write data to mem (read + minimizers)
            for(int write_it = 0; write_it < NUM_WRITES_EACH_LNEAR; write_it++){
                writeFile.write(writeData, WRITE_SIZE);
            }

            std::cout << "sending cmds for " << linear_it << " linear iteration" << std::endl;
            // linear computation (sending commands)
            for(int linear_cmd_it = 0; linear_cmd_it < NUM_LINEAR_CMDS; linear_cmd_it++){
                writeFile.write(cmd, CMD_SIZE);
            }
        }

        std::cout << "sending cmds for " << affine_it << " affine iteration" << std::endl;

        // afine computation (sending commands)
        for(int affine_cmd_it = 0; affine_cmd_it < NUM_AFFINE_CMDS; affine_cmd_it++){
            writeFile.write(cmd, CMD_SIZE);
        }

        std::cout << "reading for " << affine_it << " affine iteration" << std::endl;
*/
        // read results
        for(uint64_t read_it = 0; read_it < 10; read_it++){
            readFile.read(readData, 1);
            //readFile.seekg(0, std::ios::beg);
        }

    
    //}


}