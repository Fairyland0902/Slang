#include <llvm/IR/IRPrintingPasses.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/IR/Verifier.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/raw_ostream.h>
#include "IR.h"
#include "optimize.h"

#define ISTYPE(value, id) (value->getType()->getTypeID() == id)

extern std::string OptimizationLevel;
extern const char *yyfile;
extern int yynerrs;

/*
 * @TODO:
 * 1. unary ops
 * 2. variable declaration list
 */

static Type *TypeOf(const AST_Identifier &type, CodeGenContext &context)
{
    // Get llvm::type of variable baseD on its identifier.
    return context.typeSystem.getVarType(type);
}

static Value *CastToBoolean(CodeGenContext &context, Value *condValue)
{
    if (ISTYPE(condValue, Type::IntegerTyID))
    {
        condValue = context.builder.CreateIntCast(condValue, Type::getInt1Ty(context.llvmContext), true);
        return context.builder.CreateICmpNE(condValue, ConstantInt::get(Type::getInt1Ty(context.llvmContext), 0, true));
    } else if (ISTYPE(condValue, Type::DoubleTyID))
    {
        return context.builder.CreateFCmpONE(condValue, ConstantFP::get(context.llvmContext, APFloat(0.0)));
    } else
    {
        return condValue;
    }
}

static llvm::Value *calcArrayIndex(shared_ptr<AST_ArrayIndex> index, CodeGenContext &context)
{
    auto sizeVec = context.getArraySize(index->arrayName->name);
#ifdef IR_DEBUG
    std::cout << "sizeVec:" << sizeVec.size() << ", expressions: " << index->expressions->size() << std::endl;
#endif
    assert(sizeVec.size() > 0 && sizeVec.size() == index->expressions->size());
    auto expression = *(index->expressions->rbegin());

    for (size_t i = sizeVec.size() - 1; i >= 1; i--)
    {
        auto temp = make_shared<AST_BinaryOperator>(make_shared<AST_Integer>(sizeVec[i]), MUL_OP,
                                                    index->expressions->at(i - 1));
        expression = make_shared<AST_BinaryOperator>(temp, ADD_OP, expression);
    }

    return expression->generateCode(context);
}

void CodeGenContext::generateCode(AST_Block &root)
{
#ifdef IR_DEBUG
    std::cout << "Generating IR code" << std::endl;
#endif
    std::vector<Type *> sysArgs;
    FunctionType *mainFuncType = FunctionType::get(Type::getVoidTy(this->llvmContext), makeArrayRef(sysArgs), false);
    Function *mainFunc = Function::Create(mainFuncType, GlobalValue::ExternalLinkage, "main");
    BasicBlock *block = BasicBlock::Create(this->llvmContext, "entry");

    pushBlock(block);
    Value *retValue = root.generateCode(*this);
    popBlock();
#ifdef IR_DEBUG
    std::cout << "Generating code success" << std::endl;
#endif
    legacy::PassManager passManager;
    Optimizer optimizer;
    optimizer.OptimizationLevel = atoi(&OptimizationLevel.back());
//    std::cout << optimizer.OptimizationLevel << std::endl;
    optimizer.addStandardCompilePasses(passManager);
#ifdef OBJ_DEBUG
    passManager.add(createPrintModulePass(outs()));
#endif

    passManager.run(*(this->theModule));
}

llvm::Value *AST_Assignment::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating assignment of " << this->lhs->name << std::endl;
#endif
    Value *dst = context.getSymbolValue(this->lhs->name);
    if (dst == nullptr)
    {
        return LogErrorV(this->lhs->row, this->lhs->col, "use of undeclared identifier '" + this->lhs->name + "'");
    }
    auto dstType = context.getSymbolType(this->lhs->name);
    std::string dstTypeStr = dstType->name;
    Value *exp = this->rhs->generateCode(context);
    if (exp == nullptr)
    {
        return nullptr;
    }
#ifdef IR_DEBUG
    std::cout << "dst typeid = " << TypeSystem::llvmTypeToStr(context.typeSystem.getVarType(dstTypeStr)) << std::endl;
    std::cout << "exp typeid = " << TypeSystem::llvmTypeToStr(exp) << std::endl;
#endif

    exp = context.typeSystem.cast(exp, context.typeSystem.getVarType(dstTypeStr), context.currentBlock());
    context.builder.CreateStore(exp, dst);
    return dst;
}

llvm::Value *AST_BinaryOperator::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating binary operator" << std::endl;
#endif
    Value *L = this->lhs->generateCode(context);
    Value *R = this->rhs->generateCode(context);
    if (L == nullptr || R == nullptr)
    {
        return nullptr;
    }

    bool fp = false;
    if ((L->getType()->getTypeID() == Type::DoubleTyID) || (R->getType()->getTypeID() == Type::DoubleTyID))
    {
        // Type upcasting.
        fp = true;
        if ((R->getType()->getTypeID() != Type::DoubleTyID))
        {
            R = context.builder.CreateUIToFP(R, Type::getDoubleTy(context.llvmContext), "ftmp");
        }
        if ((L->getType()->getTypeID() != Type::DoubleTyID))
        {
            L = context.builder.CreateUIToFP(L, Type::getDoubleTy(context.llvmContext), "ftmp");
        }
    }

#ifdef IR_DEBUG
    std::cout << "fp = " << std::boolalpha << fp << std::endl;
    std::cout << "L is " << TypeSystem::llvmTypeToStr(L) << std::endl;
    std::cout << "R is " << TypeSystem::llvmTypeToStr(R) << std::endl;
#endif
    switch (this->op)
    {
        case ADD_OP:
            return fp ? context.builder.CreateFAdd(L, R, "addftmp") : context.builder.CreateAdd(L, R, "addtmp");
        case SUB_OP:
            return fp ? context.builder.CreateFSub(L, R, "subftmp") : context.builder.CreateSub(L, R, "subtmp");
        case MUL_OP:
            return fp ? context.builder.CreateFMul(L, R, "mulftmp") : context.builder.CreateMul(L, R, "multmp");
        case DIV_OP:
            return fp ? context.builder.CreateFDiv(L, R, "divftmp") : context.builder.CreateSDiv(L, R, "divtmp");
        case AND_OP:
        case BIT_AND_OP:
            return fp ? LogErrorV(this->row, this->col, "invalid operands to binary expression ('double' and 'double')")
                      : context.builder.CreateAnd(L, R, "andtmp");
        case OR_OP:
        case BIT_OR_OP:
            return fp ? LogErrorV(this->row, this->col, "invalid operands to binary expression ('double' and 'double')")
                      : context.builder.CreateOr(L, R, "ortmp");
        case BIT_XOR_OP:
            return fp ? LogErrorV(this->row, this->col, "invalid operands to binary expression ('double' and 'double')")
                      : context.builder.CreateXor(L, R, "xortmp");
        case LEFT_OP:
            return fp ? LogErrorV(this->row, this->col, "invalid operands to binary expression ('double' and 'double')")
                      : context.builder.CreateShl(L, R, "shltmp");
        case RIGHT_OP:
            return fp ? LogErrorV(this->row, this->col, "invalid operands to binary expression ('double' and 'double')")
                      : context.builder.CreateAShr(L, R, "ashrtmp");
        case LT_OP:
            return fp ? context.builder.CreateFCmpULT(L, R, "cmpftmp") : context.builder.CreateICmpULT(L, R, "cmptmp");
        case LE_OP:
            return fp ? context.builder.CreateFCmpOLE(L, R, "cmpftmp") : context.builder.CreateICmpSLE(L, R, "cmptmp");
        case GE_OP:
            return fp ? context.builder.CreateFCmpOGE(L, R, "cmpftmp") : context.builder.CreateICmpSGE(L, R, "cmptmp");
        case GT_OP:
            return fp ? context.builder.CreateFCmpOGT(L, R, "cmpftmp") : context.builder.CreateICmpSGT(L, R, "cmptmp");
        case EQ_OP:
            return fp ? context.builder.CreateFCmpOEQ(L, R, "cmpftmp") : context.builder.CreateICmpEQ(L, R, "cmptmp");
        case NE_OP:
            return fp ? context.builder.CreateFCmpONE(L, R, "cmpftmp") : context.builder.CreateICmpNE(L, R, "cmptmp");
        default:
            return LogErrorV(this->row, this->col, "unknown binary operator");
    }
}

llvm::Value *AST_Block::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating block" << std::endl;
#endif
    Value *last = nullptr;
    for (auto it = this->statements->begin(); it != this->statements->end(); it++)
    {
        last = (*it)->generateCode(context);
    }
    return last;
}

llvm::Value *AST_Integer::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating integer: " << this->value << std::endl;
#endif
    return ConstantInt::get(Type::getInt32Ty(context.llvmContext), this->value, true);
}

llvm::Value *AST_Double::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating double: " << this->value << std::endl;
#endif
    return ConstantFP::get(Type::getDoubleTy(context.llvmContext), this->value);
}

llvm::Value *AST_Identifier::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating identifier " << this->name << std::endl;
#endif
    Value *value = context.getSymbolValue(this->name);
    if (value == nullptr)
    {
        return LogErrorV(this->row, this->col, "use of undeclared identifier '" + this->name + "'");
    }
    if (value->getType()->isPointerTy())
    {
        auto arrayPtr = context.builder.CreateLoad(value, "arrayPtr");
        if (arrayPtr->getType()->isArrayTy())
        {
#ifdef IR_DEBUG
            std::cout << "(Array Type)" << std::endl;
#endif
            std::vector<Value *> indices;
            indices.push_back(ConstantInt::get(context.typeSystem.intTy, 0, false));
            auto ptr = context.builder.CreateInBoundsGEP(value, indices, "arrayPtr");
            return ptr;
        }
    }
    return context.builder.CreateLoad(value, false, "");
}

llvm::Value *AST_ExpressionStatement::generateCode(CodeGenContext &context)
{
    return this->expression->generateCode(context);
}

llvm::Value *AST_FunctionDeclaration::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating function declaration of " << this->id->name << std::endl;
#endif
    std::vector<Type *> argTypes;

    for (auto &arg : *this->arguments)
    {
        if (arg->type->isArray)
        {
            argTypes.push_back(PointerType::get(context.typeSystem.getVarType(arg->type->name), 0));
        } else
        {
            argTypes.push_back(TypeOf(*arg->type, context));
        }
    }
    Type *retType = nullptr;
    if (this->type->isArray)
        retType = PointerType::get(context.typeSystem.getVarType(this->type->name), 0);
    else
        retType = TypeOf(*this->type, context);

    FunctionType *functionType = FunctionType::get(retType, argTypes, false);
    Function *function = Function::Create(functionType, GlobalValue::ExternalLinkage, this->id->name,
                                          context.theModule.get());

    if (!this->isExternal)
    {
        BasicBlock *basicBlock = BasicBlock::Create(context.llvmContext, "entry", function, nullptr);

        context.builder.SetInsertPoint(basicBlock);
        context.pushBlock(basicBlock);

        // Declare function parameters.
        auto origin_arg = this->arguments->begin();

        for (auto &ir_arg_it : function->args())
        {
            ir_arg_it.setName((*origin_arg)->id->name);
            Value *argAlloc;
            if ((*origin_arg)->type->isArray)
                argAlloc = context.builder.CreateAlloca(
                        PointerType::get(context.typeSystem.getVarType((*origin_arg)->type->name), 0));
            else
                argAlloc = (*origin_arg)->generateCode(context);

            context.builder.CreateStore(&ir_arg_it, argAlloc, false);
            context.setSymbolValue((*origin_arg)->id->name, argAlloc, false);
            context.setSymbolType((*origin_arg)->id->name, (*origin_arg)->type, false);
            context.setFuncArg((*origin_arg)->id->name, true);
            origin_arg++;
        }

        this->block->generateCode(context);
        if (context.getCurrentReturnValue())
        {
            context.builder.CreateRet(context.getCurrentReturnValue());
        } else
        {
            return LogErrorV(this->block->row, this->block->col, "control reaches end with no return value");
        }
        context.popBlock();
    }

    return function;
}

llvm::Value *AST_StructDeclaration::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating struct declaration of " << this->name->name << std::endl;
#endif
    std::vector<Type *> memberTypes;

    auto structType = StructType::create(context.llvmContext, this->name->name);
    context.typeSystem.addStructType(this->name->name, structType);

    for (auto &member : *this->members)
    {
        context.typeSystem.addStructMember(this->name->name, member->type->name, member->id->name);
        memberTypes.push_back(TypeOf(*member->type, context));
    }

    structType->setBody(memberTypes);

    return nullptr;
}

llvm::Value *AST_MethodCall::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating method call of " << this->id->name << std::endl;
#endif
    Function *calleeF = context.theModule->getFunction(this->id->name);
    if (calleeF == nullptr)
    {
        return LogErrorV(this->id->row, this->id->col,
                         "implicit declaration of function '" + (this->id->name) + "' is invalid");
    }
    if (calleeF->arg_size() < this->arguments->size())
    {
        return LogErrorV(this->id->row, this->id->col, "too many arguments in call to '" + (this->id->name) + "'");
    }
    if (calleeF->arg_size() > this->arguments->size())
    {
        return LogErrorV(this->id->row, this->id->col, "too few arguments in call to '" + (this->id->name) + "'");
    }
    std::vector<Value *> argsv;
    for (auto it = this->arguments->begin(); it != this->arguments->end(); it++)
    {
        argsv.push_back((*it)->generateCode(context));
        if (!argsv.back())
        {
            // If any argument's code generation fail:
            return nullptr;
        }
    }
    return context.builder.CreateCall(calleeF, argsv, "calltmp");
}

llvm::Value *AST_VariableDeclaration::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating variable declaration of " << this->type->name << " " << this->id->name
              << (this->isGlobal ? " (global)" : "") << std::endl;
#endif
    Type *type = TypeOf(*this->type, context);

    Value *inst = nullptr;

    if (this->type->isArray)
    {
        uint64_t arraySize = 1;
        std::vector<uint64_t> arraySizes;
        for (auto it = this->type->arraySize->begin(); it != this->type->arraySize->end(); it++)
        {
            AST_Integer *integer = dynamic_cast<AST_Integer *>(it->get());
            arraySize *= integer->value;
            arraySizes.push_back(integer->value);
        }

        context.setArraySize(this->id->name, arraySizes);
        Value *arraySizeValue = AST_Integer(arraySize).generateCode(context);
        auto arrayType = ArrayType::get(context.typeSystem.getVarType(this->type->name), arraySize);
        if (isGlobal)
        {
            GlobalVariable *gvar_array_a = new GlobalVariable(*context.theModule, arrayType, false,
                                                              GlobalValue::ExternalLinkage, 0, "arraytmp");
            // Constant Definitions.
            ConstantAggregateZero *const_array_2 = ConstantAggregateZero::get(arrayType);
            // Global Variable Definitions.
            gvar_array_a->setInitializer(const_array_2);
            inst = static_cast<Value *>(gvar_array_a);
        } else
        {
            inst = context.builder.CreateAlloca(arrayType, arraySizeValue, "arraytmp");
        }
    } else
    {
        if (isGlobal)
        {
            Constant *initial = context.getInitial(type);
            if (initial == nullptr)
            {
                return nullptr;
            }
            inst = new GlobalVariable(*context.theModule, type, false, GlobalValue::ExternalLinkage, initial);
        } else
        {
            inst = context.builder.CreateAlloca(type);
        }
    }

    context.setSymbolType(this->id->name, this->type, isGlobal);
    context.setSymbolValue(this->id->name, inst, isGlobal);
#ifdef IR_DEBUG
    context.PrintSymTable();
#endif

    if (this->assignmentExpr != nullptr)
    {
        AST_Assignment assignment(this->id, this->assignmentExpr);
        assignment.generateCode(context);
    }
    return inst;
}

llvm::Value *AST_ReturnStatement::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating return statement" << std::endl;
#endif
    Value *returnValue = this->expression->generateCode(context);
    context.setCurrentReturnValue(returnValue);
    return returnValue;
}

llvm::Value *AST_IfStatement::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating if statement" << std::endl;
#endif
    Value *condValue = this->condition->generateCode(context);
    if (!condValue)
        return nullptr;

    condValue = CastToBoolean(context, condValue);
    // The function where if statement is in.
    Function *theFunction = context.builder.GetInsertBlock()->getParent();

    BasicBlock *thenBB = BasicBlock::Create(context.llvmContext, "then", theFunction);
    BasicBlock *falseBB = BasicBlock::Create(context.llvmContext, "else");
    BasicBlock *mergeBB = BasicBlock::Create(context.llvmContext, "ifcont");

    if (this->falseBlock)
    {
        context.builder.CreateCondBr(condValue, thenBB, falseBB);
    } else
    {
        context.builder.CreateCondBr(condValue, thenBB, mergeBB);
    }

    context.builder.SetInsertPoint(thenBB);

    context.pushBlock(thenBB);

    this->trueBlock->generateCode(context);

    context.popBlock();

    thenBB = context.builder.GetInsertBlock();

    if (thenBB->getTerminator() == nullptr)
    { //
        context.builder.CreateBr(mergeBB);
    }

    if (this->falseBlock)
    {
        theFunction->getBasicBlockList().push_back(falseBB);
        context.builder.SetInsertPoint(falseBB);

        context.pushBlock(thenBB);
        this->falseBlock->generateCode(context);
        context.popBlock();

        context.builder.CreateBr(mergeBB);
    }

    theFunction->getBasicBlockList().push_back(mergeBB);
    context.builder.SetInsertPoint(mergeBB);

    return nullptr;
}

llvm::Value *AST_ForStatement::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating for statement" << std::endl;
#endif
    Function *theFunction = context.builder.GetInsertBlock()->getParent();

    BasicBlock *block = BasicBlock::Create(context.llvmContext, "forloop", theFunction);
    BasicBlock *after = BasicBlock::Create(context.llvmContext, "forcont");

    // Execute the initial.
    if (this->initial)
        this->initial->generateCode(context);

    Value *condValue = this->condition->generateCode(context);
    if (!condValue)
        return nullptr;

    condValue = CastToBoolean(context, condValue);

    // Fall to the block.
    context.builder.CreateCondBr(condValue, block, after);
    context.builder.SetInsertPoint(block);
    context.pushBlock(block);
    this->block->generateCode(context);
    context.popBlock();

    // Do increment.
    if (this->increment)
    {
        this->increment->generateCode(context);
    }

    // Execute the again or stop.
    condValue = this->condition->generateCode(context);
    condValue = CastToBoolean(context, condValue);
    context.builder.CreateCondBr(condValue, block, after);

    // Insert the after block.
    theFunction->getBasicBlockList().push_back(after);
    context.builder.SetInsertPoint(after);

    return nullptr;
}

llvm::Value *AST_StructMember::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating struct member expression of " << this->id->name << "." << this->member->name << std::endl;
#endif
    auto varPtr = context.getSymbolValue(this->id->name);
    auto structPtr = context.builder.CreateLoad(varPtr, "structPtr");
    structPtr->setAlignment(4);

    if (!structPtr->getType()->isStructTy())
    {
        return LogErrorV(this->id->row, this->id->col,
                         "member reference base type '" + (this->id->name) + "' is not a structure or union");
    }

    string structName = structPtr->getType()->getStructName().str();
    long memberIndex = context.typeSystem.getStructMemberIndex(structName, this->member->name, this->member->row,
                                                               this->member->col);

    std::vector<Value *> indices;
    indices.push_back(ConstantInt::get(context.typeSystem.intTy, 0, false));
    indices.push_back(ConstantInt::get(context.typeSystem.intTy, (uint64_t) memberIndex, false));
    auto ptr = context.builder.CreateInBoundsGEP(varPtr, indices, "memberPtr");

    return context.builder.CreateLoad(ptr);
}

llvm::Value *AST_StructAssignment::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating struct assignment of " << this->structMember->id->name << "."
              << this->structMember->member->name << std::endl;
#endif
    auto varPtr = context.getSymbolValue(this->structMember->id->name);
    auto structPtr = context.builder.CreateLoad(varPtr, "structPtr");
    structPtr->setAlignment(4);

    if (!structPtr->getType()->isStructTy())
    {
        return LogErrorV(this->structMember->id->row, this->structMember->id->col,
                         "member reference base type '" + (this->structMember->id->name) +
                         "' is not a structure or union");
    }

    string structName = structPtr->getType()->getStructName().str();
    long memberIndex = context.typeSystem.getStructMemberIndex(structName, this->structMember->member->name,
                                                               this->structMember->member->row,
                                                               this->structMember->member->col);

    std::vector<Value *> indices;
    auto value = this->expression->generateCode(context);
    indices.push_back(ConstantInt::get(context.typeSystem.intTy, 0, false));
    indices.push_back(ConstantInt::get(context.typeSystem.intTy, (uint64_t) memberIndex, false));

    auto ptr = context.builder.CreateInBoundsGEP(varPtr, indices, "structMemberPtr");

    return context.builder.CreateStore(value, ptr);
}

llvm::Value *AST_ArrayIndex::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating array index expression of " << this->arrayName->name << std::endl;
#endif
    auto varPtr = context.getSymbolValue(this->arrayName->name);
    auto type = context.getSymbolType(this->arrayName->name);
    std::string typeStr = type->name;

    assert(type->isArray);

    auto value = calcArrayIndex(make_shared<AST_ArrayIndex>(*this), context);
    std::vector<Value *> indices;
    if (context.isFuncArg(this->arrayName->name))
    {
        std::cout << "isFuncArg" << std::endl;
        varPtr = context.builder.CreateLoad(varPtr, "actualArrayPtr");
        indices = {value};
        indices = ArrayRef<Value *>(value);
    } else if (varPtr->getType()->isPointerTy())
    {
        std::cout << this->arrayName->name << "Not isFuncArg" << std::endl;
        indices = {ConstantInt::get(Type::getInt64Ty(context.llvmContext), 0), value};
    } else
    {
        return LogErrorV(this->arrayName->row, this->arrayName->col, "subscripted value is not an array");
    }
    auto ptr = context.builder.CreateInBoundsGEP(varPtr, indices, "elementPtr");

    return context.builder.CreateAlignedLoad(ptr, 4);
}

llvm::Value *AST_ArrayAssignment::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating array index assignment of " << this->arrayIndex->arrayName->name << std::endl;
#endif
    auto varPtr = context.getSymbolValue(this->arrayIndex->arrayName->name);

    if (varPtr == nullptr)
    {
        return LogErrorV(this->arrayIndex->arrayName->row, this->arrayIndex->arrayName->col,
                         "use of undeclared identifier '" + this->arrayIndex->arrayName->name + "'");
    }

    auto arrayPtr = context.builder.CreateLoad(varPtr, "arrayPtr");

    if (!arrayPtr->getType()->isArrayTy() && !arrayPtr->getType()->isPointerTy())
    {
        return LogErrorV(this->arrayIndex->arrayName->row, this->arrayIndex->arrayName->col,
                         "subscripted value is not an array");
    }
    auto index = calcArrayIndex(arrayIndex, context);
    std::vector<Value *> indices = {ConstantInt::get(Type::getInt64Ty(context.llvmContext), 0), index};
    assert(indices[1] != nullptr);
    auto ptr = context.builder.CreateInBoundsGEP(varPtr, indices, "elementPtr");

    return context.builder.CreateAlignedStore(this->expression->generateCode(context), ptr, 4);
}

llvm::Value *AST_ArrayInitialization::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating array initialization of " << this->declaration->id->name << std::endl;
#endif
    if (isGlobal)
    {
        this->declaration->isGlobal = true;
    }
    auto arrayPtr = this->declaration->generateCode(context);
    auto sizeVec = context.getArraySize(this->declaration->id->name);
    // @TODO: multi-dimension array initialization
    assert(sizeVec.size() == 1);

    for (size_t index = 0; index < this->expressionList->size(); index++)
    {
        shared_ptr<AST_Integer> indexValue = make_shared<AST_Integer>(index);

        shared_ptr<AST_ArrayIndex> arrayIndex = make_shared<AST_ArrayIndex>(this->declaration->id, indexValue);
        AST_ArrayAssignment assignment(arrayIndex, this->expressionList->at(index));
        assignment.generateCode(context);
    }
    return nullptr;
}

llvm::Value *AST_Literal::generateCode(CodeGenContext &context)
{
#ifdef IR_DEBUG
    std::cout << "Generating string literal: " << this->value << std::endl;
#endif
    return context.builder.CreateGlobalString(this->value, "string");
}

/*
 * Global Functions
 *
 */
std::unique_ptr<AST_Expression> LogError(const int row, const int col, const char *str)
{
    fflush(stdout);
    fprintf(stderr, "\033[1m%s:%d:%d:\033[1;31m error: \033[0m", yyfile, row, col);
    fprintf(stderr, "\033[1m%s\033[0m\n", str);
    yynerrs++;
    return nullptr;
}

Value *LogErrorV(const int row, const int col, const std::string &str)
{
    return LogErrorV(row, col, str.c_str());
}

Value *LogErrorV(const int row, const int col, const char *str)
{
    LogError(row, col, str);
    return nullptr;
}
