#include "driver.h"
#include <cctype>
#include <iostream>

const char *yyfile;

int main(int argc, char **argv)
{
    // Check for the right # of arguments.
    if (argc == 2)
    {
        // Compile from an input file.
        Driver driver;
        yyfile = argv[1];
        driver.parse(argv[1]);
        // You may need to link obj files manually here.
        system("clang output.o -o a.out");
    } else
    {
        fprintf(stderr, "slang:\033[31m error:\033[0m no input files\n");
        exit(EXIT_FAILURE);
    }

    return EXIT_SUCCESS;
}
