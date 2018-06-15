#include <fstream>
#include <cassert>
#include <cctype>
#include <iostream>
#include "driver.h"
#include "absyn.h"

extern int yyparse();

extern std::shared_ptr<AST_Block> programBlock;

std::istream *lexer_ins_;

Driver::~Driver() = default;

void Driver::parse(std::string filename)
{
    assert(!filename.empty());

    std::ifstream infile(filename);
    if (!infile.good())
    {
        exit(EXIT_FAILURE);
    }
    parse_helper(infile);
}

void Driver::parse(std::istream &iss)
{
    if (!iss.good() && iss.eof())
    {
        return;
    }
    parse_helper(iss);
}

void Driver::parse_helper(std::istream &stream)
{
    const int accept(0);

    lexer_ins_ = &stream;

    if (yyparse() != accept)
    {
        std::cerr << "parse failed" << std::endl;
    }

    std::cout << programBlock << std::endl;
    programBlock->print("--");
}
