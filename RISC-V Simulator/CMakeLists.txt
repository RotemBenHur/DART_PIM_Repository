cmake_minimum_required(VERSION 3.22)
project(DART_PIM)

set(CMAKE_CXX_STANDARD 17)

# Set the build type to Debug
set(CMAKE_BUILD_TYPE Debug)

# Add the executable target with debugging information and no optimization
add_executable(DART_PIM WF_sim.cpp)
target_compile_options(DART_PIM PRIVATE -g -O0)

# Link the pthread library
target_link_libraries(DART_PIM pthread)