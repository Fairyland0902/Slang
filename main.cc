#include "driver.h"
#include <cctype>
#include <iostream>

int main(int argc, char **argv){
    // Check for the right # of arguments.
    if(argc == 2) {
        // Compile from an input file.
        Driver driver;
        driver.parse(argv[1]);
    } else {
        std::cout << "Just give a file name to compile from a file." << std::endl;
        exit(EXIT_FAILURE);
    }

//    std::cout << "Fuck" << std::endl;
    return EXIT_SUCCESS;
}
