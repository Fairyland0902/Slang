cmake_minimum_required(VERSION 3.10)
project(Slang)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=g++11 -O3")

set(SOURCE_FILES main.cpp)
add_executable(Slang ${SOURCE_FILES})
