#ifndef SLANG_OPTIMIZE_H
#define SLANG_OPTIMIZE_H

#include <llvm/IR/LegacyPassManager.h>

class Optimizer
{
public:
    Optimizer() :
            DisableInline(true),
            OptimizationLevel(0),
            DontVerify(true),
            VerifyEach(false)
    {}

    ~Optimizer() = default;

    void addStandardCompilePasses(llvm::legacy::PassManager &PM);

    int OptimizationLevel;
    bool DisableInline;
    bool DontVerify;
    bool VerifyEach;

private:
    void addPass(llvm::legacy::PassManager &PM, llvm::Pass *P)
    {
        // Add the pass to the pass manager...
        PM.add(P);

        // If we are verifying all of the intermediate steps, add the verifier...
        if (VerifyEach)
            PM.add(llvm::createVerifierPass());
    }
};

#endif //SLANG_OPTIMIZE_H
