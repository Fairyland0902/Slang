cmake_minimum_required(VERSION 3.9.1)
project(Slang)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -O3")

find_package(BISON)
find_package(FLEX)
find_package(LLVM REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

BISON_TARGET(MyInterpreter interpreter.y ${CMAKE_CURRENT_BINARY_DIR}/interpreter.cc DEFINES_FILE ${CMAKE_CURRENT_BINARY_DIR}/interpreter.h)
BISON_TARGET(MyParser parser.y ${CMAKE_CURRENT_BINARY_DIR}/parser.cc DEFINES_FILE ${CMAKE_CURRENT_BINARY_DIR}/parser.h)
FLEX_TARGET(MyScanner scanner.l ${CMAKE_CURRENT_BINARY_DIR}/scanner.cc)
ADD_FLEX_BISON_DEPENDENCY(MyScanner MyParser MyASTTree)

include_directories(${PROJECT_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_BINARY_DIR})
include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

set(SOURCE_FILES
        main.cc
        ${BISON_MyParser_OUTPUTS}
        ${FLEX_MyScanner_OUTPUTS}
        driver.h
        driver.cc
        absyn.h)
add_executable(Slang ${SOURCE_FILES})

llvm_map_components_to_libnames(llvm_libs support core irreader mcjit native)
target_link_libraries(Slang ${llvm_libs})
