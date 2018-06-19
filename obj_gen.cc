#include <llvm/IR/IRPrintingPasses.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/Host.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Support/TargetRegistry.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Target/TargetOptions.h>
#include <llvm/ADT/Optional.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Support/FormattedStream.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/IR/LegacyPassManager.h>

#include "IR.h"
#include "obj_gen.h"
#include "debug.h"

using namespace llvm;

extern bool EmitIR;

void generateObj(CodeGenContext &context, const std::string &filename)
{
    // Initialize the target registry etc.
    InitializeAllTargetInfos();
    InitializeAllTargets();
    InitializeAllTargetMCs();
    InitializeAllAsmParsers();
    InitializeAllAsmPrinters();

    auto TargetTriple = sys::getDefaultTargetTriple();
    context.theModule->setTargetTriple(TargetTriple);

    /*
     * Print an error and exit if we couldn't find the requested target.
     * This generally occurs if we've forgotten to initialise the
     * TargetRegistry or we have a bogus target triple.
     */
    std::string error;
    auto Target = TargetRegistry::lookupTarget(TargetTriple, error);

    if (!Target)
    {
        errs() << error;
        return;
    }

    auto CPU = "generic";
    auto features = "";

    TargetOptions opt;
    auto RM = Optional<Reloc::Model>();
    auto TargetMachine = Target->createTargetMachine(TargetTriple, CPU, features, opt, RM);

    context.theModule->setDataLayout(TargetMachine->createDataLayout());
    context.theModule->setTargetTriple(TargetTriple);

    legacy::PassManager pass;
    std::error_code EC;
    raw_fd_ostream dest(filename.c_str(), EC, sys::fs::F_None);
//    formatted_raw_ostream formattedRawOstream(dest);

    if (EC)
    {
        errs() << "Could not open file: " << EC.message();
        return;
    }

    if (EmitIR)
    {
        // Generate IR code file.
        pass.add(createPrintModulePass(dest));
        pass.run(*context.theModule);
        dest.flush();
        return;
    } else
    {
        auto fileType = TargetMachine::CGFT_ObjectFile;

        if (TargetMachine->addPassesToEmitFile(pass, dest, fileType))
        {
            errs() << "TargetMachine can't emit a file of this type";
            return;
        }
        pass.run(*context.theModule);
        dest.flush();

#ifdef OBJ_DEBUG
        outs() << "Object code wrote to " << filename.c_str() << "\n";
#endif
    }
}
