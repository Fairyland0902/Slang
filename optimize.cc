#include <llvm/Analysis/Passes.h>
#include <llvm/Analysis/LoopPass.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/PassManager.h>
#include <llvm/IR/Verifier.h>
#include <llvm/Support/CommandLine.h>
#include <llvm/Support/DynamicLibrary.h>
#include <llvm/Support/PluginLoader.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Transforms/IPO.h>
#include <llvm/Transforms/Scalar.h>
#include "optimize.h"

void Optimizer::addStandardCompilePasses(llvm::legacy::PassManager &PM)
{
    // Verify that input is correct.
    if (!DontVerify)
        PM.add(llvm::createVerifierPass());
    if (OptimizationLevel == 0)
        return;

    switch (OptimizationLevel)
    {
        case 3:
            // Scalarize uninlined fn args.
            addPass(PM, llvm::createArgumentPromotionPass());
        case 2:
            // Remove redundancies.
//            addPass(PM, llvm::createGVNPass());
            // Inline small functions.
            addPass(PM, llvm::createFunctionInliningPass());
            // Remove unused fns and globs.
            addPass(PM, llvm::createGlobalDCEPass());
            // Merge dup global constants.
            addPass(PM, llvm::createConstantMergePass());
        case 1:
            // Clean up disgusting code.
            addPass(PM, llvm::createCFGSimplificationPass());
            // Kill useless allocas.
            addPass(PM, llvm::createPromoteMemoryToRegisterPass());
            // Optimize out global vars.
            addPass(PM, llvm::createGlobalOptimizerPass());
            // Remove unused fns and globs.
            addPass(PM, llvm::createGlobalDCEPass());
            // IP Constant Propagation.
            addPass(PM, llvm::createIPConstantPropagationPass());
            // Dead argument elimination.
            addPass(PM, llvm::createDeadArgEliminationPass());
            // Clean up after IPCP & DAE.
            addPass(PM, llvm::createInstructionCombiningPass());
            // Clean up after IPCP & DAE.
            addPass(PM, llvm::createCFGSimplificationPass());

            // Remove dead EH info.
            addPass(PM, llvm::createPruneEHPass());
            // Deduce function attrs.
//            addPass(PM, llvm::createFunctionAttrsPass());
            // Cleanup for scalarrepl.
            addPass(PM, llvm::createInstructionCombiningPass());
            // Thread jumps.
            addPass(PM, llvm::createJumpThreadingPass());
            // Merge & remove BBs.
            addPass(PM, llvm::createCFGSimplificationPass());
            // Break up aggregate allocas.
//            addPass(PM, llvm::createScalarReplAggregatesPass());
            // Combine silly seq's.
            addPass(PM, llvm::createInstructionCombiningPass());

            // Eliminate tail calls.
            addPass(PM, llvm::createTailCallEliminationPass());
            // Merge & remove BBs.
            addPass(PM, llvm::createCFGSimplificationPass());
            // Reassociate expressions.
            addPass(PM, llvm::createReassociatePass());
            addPass(PM, llvm::createLoopRotatePass());
            // Hoist loop invariants.
            addPass(PM, llvm::createLICMPass());
            // Unswitch loops.
            addPass(PM, llvm::createLoopUnswitchPass());
            // @FIXME : Removing instcombine causes nestedloop regression.
            addPass(PM, llvm::createInstructionCombiningPass());
            // Canonicalize indvars.
            addPass(PM, llvm::createIndVarSimplifyPass());
            // Delete dead loops.
            addPass(PM, llvm::createLoopDeletionPass());
            // Unroll small loops.
            addPass(PM, llvm::createLoopUnrollPass());
            // Clean up after the unroller.
            addPass(PM, llvm::createInstructionCombiningPass());

            // Remove memcpy / form memset.
            addPass(PM, llvm::createMemCpyOptPass());
            // Constant prop with SCCP.
            addPass(PM, llvm::createSCCPPass());

            // Run instcombine after redundancy elimination to exploit opportunities opened up by them.
            addPass(PM, llvm::createInstructionCombiningPass());
            // Delete dead stores.
            addPass(PM, llvm::createDeadStoreEliminationPass());
            // Delete dead instructions.
            addPass(PM, llvm::createAggressiveDCEPass());
            // Merge & remove BBs.
            addPass(PM, llvm::createCFGSimplificationPass());
            // Get rid of dead prototypes.
            addPass(PM, llvm::createStripDeadPrototypesPass());
    }

    // Make sure everything is still good.
    if (!DontVerify)
        addPass(PM, llvm::createVerifierPass());
}
