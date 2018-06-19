#include <llvm/ADT/Optional.h>
#include <llvm/CodeGen/LinkAllAsmWriterComponents.h>
#include <llvm/CodeGen/LinkAllCodegenComponents.h>
#include <llvm/CodeGen/MIRParser/MIRParser.h>
#include <llvm/CodeGen/MachineFunctionPass.h>
#include <llvm/CodeGen/MachineModuleInfo.h>
#include <llvm/CodeGen/TargetPassConfig.h>
#include "llvm/CodeGen/TargetSubtargetInfo.h"
#include <llvm/IR/IRPrintingPasses.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/FormattedStream.h>
#include <llvm/Support/Host.h>
#include <llvm/Support/TargetRegistry.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Support/ToolOutputFile.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Target/TargetOptions.h>
#include <llvm/Transforms/Utils/Cloning.h>
#include "IR.h"
#include "target_gen.h"
#include "debug.h"

using namespace llvm;

extern bool EmitIR;
extern bool EmitASM;
extern std::string Prefix;

void generateTarget(CodeGenContext &context, const std::string &filename)
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

    // Build up all of the passes that we want to do to the module.
    legacy::PassManager PM;
    std::error_code EC;
    sys::fs::OpenFlags OpenFlags = sys::fs::F_None;
    if (EmitIR || EmitASM)
    {
        OpenFlags |= sys::fs::F_Text;
    }
    raw_fd_ostream OS(filename, EC, OpenFlags);

    if (EC)
    {
        errs() << "Could not open file: " << EC.message();
        return;
    }

    if (EmitIR)
    {
        PM.add(createPrintModulePass(OS));
        PM.run(*context.theModule);
        OS.flush();
        return;
    }

    LLVMTargetMachine &LLVMTM = dynamic_cast<LLVMTargetMachine &>(*TargetMachine);
    MachineModuleInfo *MMI = new MachineModuleInfo(&LLVMTM);
    TargetMachine::CodeGenFileType FileType = TargetMachine::CGFT_ObjectFile;
    if (EmitASM)
    {
        FileType = TargetMachine::CGFT_AssemblyFile;

        if (TargetMachine->addPassesToEmitFile(PM, OS, FileType, true, MMI))
        {
            errs() << "TargetMachine can't emit a file of this type";
            return;
        }
        std::string OutputFile = "clang -Wno-everything -S " + Prefix + ".c" + " -o " + filename;
        system(OutputFile.c_str());
        return;
    }

    if (TargetMachine->addPassesToEmitFile(PM, OS, FileType, true, MMI))
    {
        errs() << "TargetMachine can't emit a file of this type";
        return;
    }

    PM.run(*context.theModule);
    OS.flush();


#ifdef OBJ_DEBUG
    outs() << "Object code wrote to " << filename.c_str() << "\n";
#endif
}
