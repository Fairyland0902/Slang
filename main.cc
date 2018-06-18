#include <cctype>
#include <iomanip>
#include <iostream>
#include <fstream>
#include "absyn.h"
#include "driver.h"

const char *yyfile;
extern bool emptyFile;
extern std::shared_ptr<AST_Block> programBlock;

bool DontLink = false;
bool EmitIR = false;
bool EmitASM = false;
bool EmitBC = false;
std::string OptimizationLevel = "-O0";
std::string OutputFile;
bool OutputName = false;
std::string Prefix;

void showHelpInfo()
{
    std::cout << "OVERVIEW: Small cLANG LLVM compiler\n" << std::endl;
    std::cout << "USAGE: slang [options] <inputs>\n" << std::endl;
    std::cout << "OPTIONS:" << std::endl;
    std::cout << "  " << std::setw(16) << std::left << "-c" << "Only run preprocess, compile, and assemble steps"
              << std::endl;
    std::cout << "  " << std::setw(16) << std::left << "-emit-llvm"
              << "Use the LLVM representation for assembler and object files" << std::endl;
    std::cout << "  " << std::setw(16) << std::left << "-o <file>" << "Write output to <file>" << std::endl;
    std::cout << "  " << std::setw(16) << std::left << "-S" << "Only run preprocess and compilation steps" << std::endl;
}

int main(int argc, char **argv)
{
    // Check for the right # of arguments.
    if (argc >= 2)
    {
        if (argc == 2 && strcmp(argv[1], "--help") == 0)
        {
            showHelpInfo();
            return EXIT_SUCCESS;
        }
        // Parse from command line input.
        bool EmitLLVM = false;
        std::string InputFile;
        for (int i = 1; i < argc; i++)
        {
            if (strcmp(argv[i], "-c") == 0)
            {
                DontLink = true;
            } else if (strcmp(argv[i], "-o") == 0)
            {
                OutputFile = std::string(argv[i + 1]);
                OutputName = true;
                i++;
            } else if (strcmp(argv[i], "-S") == 0)
            {
                DontLink = true;
                EmitASM = true;
            } else if (strcmp(argv[i], "-emit-llvm") == 0)
            {
                EmitLLVM = true;
            } else if (argv[i][0] == '-' && argv[i][1] == 'O')
            {
                // Optimization level.
                OptimizationLevel = std::string(argv[i]);
            } else
            {
                // Input file.
                InputFile = std::string(argv[i]);
                size_t pos = InputFile.find(".");
                Prefix = InputFile.substr(0, pos);
            }
        }

        if (EmitLLVM && DontLink)
        {
            if (EmitASM)
            {
                EmitIR = true;
                EmitASM = false;
            } else
            {
                EmitBC = true;
            }
        } else if (EmitLLVM && !DontLink)
        {
            fprintf(stderr, "slang:\033[1;31m error:\033[0m -emit-llvm cannot be used when linking\n");
            exit(EXIT_FAILURE);
        }

        if (!OutputName)
        {
            // Give output file its default name.
            if (DontLink)
            {
                if (EmitASM)
                {
                    OutputFile = Prefix + ".s";
                } else if (EmitBC)
                {
                    OutputFile = Prefix + ".bc";
                } else if (EmitIR)
                {
                    OutputFile = Prefix + ".ll";
                } else
                {
                    OutputFile = Prefix + ".o";
                }
            } else
            {
                OutputFile = "a.out";
            }
        }

#if 0
        std::cout << "DonotLink = " << std::boolalpha << DonotLink << std::endl;
        std::cout << "EmitIR = " << std::boolalpha << EmitIR << std::endl;
        std::cout << "EmitASM = " << std::boolalpha << EmitASM << std::endl;
        std::cout << "EmitBC = " << std::boolalpha << EmitBC << std::endl;
        std::cout << "InputFile = " << InputFile << std::endl;
        std::cout << "Prefix = " << Prefix << std::endl;
        std::cout << "OutputFile = " << OutputFile << std::endl;
        std::cout << "OptimizationLevel = " << OptimizationLevel << std::endl;
#endif

        // Compile from an input file.
        Driver driver;
        yyfile = InputFile.c_str();
        driver.parse(InputFile);
        if (!emptyFile)
        {
            // You may need to link obj files manually here.
            if (!DontLink)
            {
                std::string command = std::string("clang") + " output.o -o " + OutputFile;
                system(command.c_str());
                system("rm output.o");
            }

            // Visualization.
            auto root = programBlock->generateJson();
            std::string jsonFile = "../visualization/visualization.json";
            std::ofstream os(jsonFile);
            if (os.is_open())
            {
                os << root;
                os.close();
            }
        }
    } else
    {
        fprintf(stderr, "slang:\033[1;31m error:\033[0m no input files\n");
        exit(EXIT_FAILURE);
    }

    return EXIT_SUCCESS;
}
