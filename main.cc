#include <iostream>

int main(int argc, char **argv){
    // Check for the right # of arguments.
    if(argc == 2) {
        // Compile from a file.
    } else {
        std::cout << "Just give a file name to compile from a file." << std::endl;
        return -1;
    }

    std::cout << "Fuck" << std::endl;
    return 0;
}
