#include "driver.h"
#include <cctype>
#include <iostream>

int main(int argc, char **argv)
{
    // Check for the right # of arguments.
    if (argc == 2)
    {
        // Compile from an input file.
        Driver driver;
        driver.parse(argv[1]);
    } else
    {
        std::cout << "Just give a file name to compile from a file." << std::endl;
        exit(EXIT_FAILURE);
    }
    // You may need to link obj files manually here.
//    system("echo 23333");
    return EXIT_SUCCESS;
}
