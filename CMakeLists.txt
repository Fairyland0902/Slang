cmake_minimum_required(VERSION 3.10)
project(Slang)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=g++11 -O3")

find_package(BISON)
find_package(FLEX)

BISON_TARGET(MyParser parser.y ${CMAKE_CURRENT_BINARY_DIR}/parser.cc DEFINES_FILE ${CMAKE_CURRENT_BINARY_DIR}/parser.h)
FLEX_TARGET(MyScanner scanner.l ${CMAKE_CURRENT_BINARY_DIR}/scanner.cc)
ADD_FLEX_BISON_DEPENDENCY(MyScanner MyParser)

include_directories(${CMAKE_CURRENT_BINARY_DIR})
set(SOURCE_FILES
        main.cc
        ${BISON_MyParser_OUTPUTS}
        ${FLEX_MyScanner_OUTPUTS}
        driver.h
        driver.cc)
add_executable(Slang ${SOURCE_FILES})
