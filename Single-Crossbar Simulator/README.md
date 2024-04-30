# DART-PIM - Single-Crossbar Simulator
DART-PIM: DNA read mApping acceleRaTor Using Processing-In-Memory
Single-Crossbar Simulator - this simulator models a single crossbar operation cycle by cycle. It verifies the functionality of algorithms implemented using MAGIC NOR operations within DART-PIM. It provides an exact calculation of the execution time by computing the number of cycles required for executing linear and affine WF, including pre- and post-processing operations. Additionally, it quantifies the energy consumption by counting the number of write/MAGIC NOR switches and number of read bits.

## Dependencies
In order to use SIMPLE-MAGIC, you will need:
1. Matlab (we used Matlab Rc2021a)

## Manual
1. **Download**: all Single-Crossbar Simulator files

2. **Open**: Cycle_accurate_simulator.m using matlab

3. **Configure**: the Wagner-Fischer and crossbar (XB) parameters in the file Cycle_accurate_simulator.m  
(The parameters used in DART-PIM paper are currently defined)

4. **Run**: run Cycle_accurate_simulator.m and receive the number of cycles and switches for each step of read mapping that is doen by DART-PIM within a single crossbar.
The state of each crossbar cell can be seen cycle-by-cycle in "XB" array.
