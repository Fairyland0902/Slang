#ifndef SLANG_IR_H
#define SLANG_IR_H

#include <llvm/IR/Value.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/Module.h>
#include <json/json.h>
#include <iostream>
#include <stack>
#include <vector>
#include <memory>
#include <string>
#include <map>
#include "absyn.h"
#include "parser.h"
#include "type.h"
#include "debug.h"

using namespace llvm;
using std::unique_ptr;
using std::string;

using SymTable = std::map<string, Value *>;

class CodeGenBlock
{
public:
    BasicBlock *block;
    Value *returnValue;
    std::map<string, Value *> locals;
    // Type name string of variables.
    std::map<string, shared_ptr<AST_Identifier>> types;
    std::map<string, bool> isFuncArg;
    std::map<string, std::vector<uint64_t>> arraySizes;
};

class CodeGenContext
{
private:
    std::vector<CodeGenBlock *> blockStack;

public:
    LLVMContext llvmContext;
    IRBuilder<> builder;
    unique_ptr<Module> theModule;
    SymTable globalVars;
    TypeSystem typeSystem;

    CodeGenContext(std::string filename) : builder(llvmContext), typeSystem(llvmContext)
    {
        theModule = std::unique_ptr<Module>(new Module(filename, this->llvmContext));
    }

    Value *getSymbolValue(const std::string &name) const
    {
        for (auto it = blockStack.rbegin(); it != blockStack.rend(); it++)
        {
            if ((*it)->locals.find(name) != (*it)->locals.end())
            {
                return (*it)->locals[name];
            }
        }
        return nullptr;
    }

    shared_ptr<AST_Identifier> getSymbolType(const std::string &name) const
    {
        for (auto it = blockStack.rbegin(); it != blockStack.rend(); it++)
        {
            if ((*it)->types.find(name) != (*it)->types.end())
            {
                return (*it)->types[name];
            }
        }
        return nullptr;
    }

    bool isFuncArg(const std::string &name) const
    {
        for (auto it = blockStack.rbegin(); it != blockStack.rend(); it++)
        {
            if ((*it)->isFuncArg.find(name) != (*it)->isFuncArg.end())
            {
                return (*it)->isFuncArg[name];
            }
        }
        return false;
    }

    void setSymbolValue(const std::string &name, Value *value)
    {
        blockStack.back()->locals[name] = value;
    }

    void setSymbolType(const std::string &name, shared_ptr<AST_Identifier> value)
    {
        blockStack.back()->types[name] = value;
    }

    void setFuncArg(const std::string &name, bool value)
    {
#ifdef IR_DEBUG
        std::cout << "Setting " << name << " as function arguments" << std::endl;
#endif
        blockStack.back()->isFuncArg[name] = value;
    }

    BasicBlock *currentBlock() const
    {
        return blockStack.back()->block;
    }

    void pushBlock(BasicBlock *block)
    {
        CodeGenBlock *codeGenBlock = new CodeGenBlock();
        codeGenBlock->block = block;
        codeGenBlock->returnValue = nullptr;
        blockStack.push_back(codeGenBlock);
    }

    void popBlock()
    {
        CodeGenBlock *codeGenBlock = blockStack.back();
        blockStack.pop_back();
        delete codeGenBlock;
    }

    void setCurrentReturnValue(Value *value)
    {
        blockStack.back()->returnValue = value;
    }

    Value *getCurrentReturnValue()
    {
        return blockStack.back()->returnValue;
    }

    void setArraySize(const std::string &name, std::vector<uint64_t> value)
    {
#ifdef IR_DEBUG
        std::cout << "[ARRAY DIMENSION]" << name << ": " << value.size() << std::endl;
        std::cout << "[ARRAY SIZE     ]" << name << ": ";
        for (auto &v: value)
        {
            std::cout << v << " ";
        }
        std::cout << std::endl;
#endif
        blockStack.back()->arraySizes[name] = value;
    }

    std::vector<uint64_t> getArraySize(const std::string &name)
    {
        for (auto it = blockStack.rbegin(); it != blockStack.rend(); it++)
        {
            if ((*it)->arraySizes.find(name) != (*it)->arraySizes.end())
            {
                return (*it)->arraySizes[name];
            }
        }
        return blockStack.back()->arraySizes[name];
    }

    void PrintSymTable() const
    {
        std::cout << "======= Print Symbol Table ========" << std::endl;
        std::string prefix = "";
        for (auto it = blockStack.begin(); it != blockStack.end(); it++)
        {
            for (auto it2 = (*it)->locals.begin(); it2 != (*it)->locals.end(); it2++)
            {
                std::cout << prefix << it2->first << " = " << it2->second << ": " << this->getSymbolType(it2->first)
                          << std::endl;
            }
            prefix += "\t";
        }
        std::cout << "===================================" << std::endl;
    }

    void generateCode(AST_Block &root);
};

Value *LogErrorV(const char *str);

Value *LogErrorV(const std::string &str);

#endif // SLANG_IR_H
