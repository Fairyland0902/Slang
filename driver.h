#ifndef SLANG_DRIVER_H
#define SLANG_DRIVER_H

#include <string>
#include <istream>

class Driver
{
public:
    Driver() = default;

    virtual ~Driver();

    /*
     * parse: parse from a file.
     * @param filename -- valid string with input file.
     */
    void parse(std::string filename);

    /*
     * parse: parse from a c++ input stream.
     * @param: iss -- std::istream, valid input stream.
     */
    void parse(std::istream &iss);

private:
    void parse_helper(std::istream &stream);
};

#endif //SLANG_DRIVER_H
