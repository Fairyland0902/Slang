#ifndef SLANG_ASTNODES_H
#define SLANG_ASTNODES_H

#include <iostream>
#include <vector>
#include <llvm/IR/Value.h>

class CodeGenContext;

class NExpression;

class NStatement;

class NVariableDeclaration;

typedef std::vector<std::shared_ptr<NExpression>> ExpressionList;
typedef std::vector<std::shared_ptr<NStatement>> StatementList;
typedef std::vector<std::shared_ptr<NVariableDeclaration>> VariableList;

class Node
{
public:
    Node() = default;

    virtual ~Node() = default;

    virtual llvm::Value *codeGen(CodeGenContext &context)
    { return static_cast<llvm::Value *>(nullptr); }
};

class NExpression : public Node
{
public:
    NExpression() = default;
};

class NStatement : public Node
{
public:
    NStatement() = default;
};

class NDouble : public NExpression
{
public:
    double value;

    NDouble() = default;

    explicit NDouble(double value) : value(value)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NInteger : public NExpression
{
public:
    uint64_t value;

    NInteger() = default;

    explicit NInteger(uint64_t value) : value(value)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;

    operator NDouble() const
    {
        return NDouble(value);
    }
};

class NIdentifier : public NExpression
{
public:
    std::string name;
    bool isType = false;

    NIdentifier() = default;

    explicit NIdentifier(std::string &name) : name(name)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NMethodCall : public NExpression
{
public:
    const std::shared_ptr<NIdentifier> id;
    std::shared_ptr<ExpressionList> arguments = std::make_shared<ExpressionList>();

    NMethodCall() = default;

    explicit NMethodCall(const std::shared_ptr<NIdentifier> id) : id(id)
    {}

    NMethodCall(const std::shared_ptr<NIdentifier> id, std::shared_ptr<ExpressionList> arguments) :
            id(id),
            arguments(arguments)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NBinaryOperator : public NExpression
{
public:
    int op;
    std::shared_ptr<NExpression> lhs;
    std::shared_ptr<NExpression> rhs;

    NBinaryOperator() = default;

    NBinaryOperator(std::shared_ptr<NExpression> lhs, int op, std::shared_ptr<NExpression> rhs) :
            lhs(lhs),
            op(op),
            rhs(rhs)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NAssignment : public NExpression
{
public:
    std::shared_ptr<NIdentifier> lhs;
    std::shared_ptr<NExpression> rhs;

    NAssignment() = default;

    NAssignment(std::shared_ptr<NIdentifier> lhs, std::shared_ptr<NExpression> rhs) :
            lhs(lhs),
            rhs(rhs)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NBlock : public NExpression
{
public:
    std::shared_ptr<StatementList> statements = std::make_shared<StatementList>();

    NBlock() = default;

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NExpressionStatement : public NStatement
{
public:
    std::shared_ptr<NExpression> expression;

    NExpressionStatement() = default;

    NExpressionStatement(std::shared_ptr<NExpression> expression)
            : expression(expression)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NVariableDeclaration : public NStatement
{
public:
    const std::shared_ptr<NIdentifier> type;
    std::shared_ptr<NIdentifier> id;
    std::shared_ptr<NExpression> assignmentExpr = nullptr;

    NVariableDeclaration() = default;

    NVariableDeclaration(const std::shared_ptr<NIdentifier> type, std::shared_ptr<NIdentifier> id,
                         std::shared_ptr<NExpression> assignmentExpr = nullptr) :
            type(type),
            id(id),
            assignmentExpr(assignmentExpr)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NFunctionDeclaration : public NStatement
{
public:
    std::shared_ptr<NIdentifier> type;
    std::shared_ptr<NIdentifier> id;
    std::shared_ptr<VariableList> arguments = std::make_shared<VariableList>();
    std::shared_ptr<NBlock> block;

    NFunctionDeclaration() = default;

    NFunctionDeclaration(std::shared_ptr<NIdentifier> type, std::shared_ptr<NIdentifier> id,
                         std::shared_ptr<VariableList> arguments, std::shared_ptr<NBlock> block) :
            type(type),
            id(id),
            arguments(arguments),
            block(block)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NReturnStatement : public NStatement
{
public:
    std::shared_ptr<NExpression> expression;

    NReturnStatement() = default;

    explicit NReturnStatement(std::shared_ptr<NExpression> expression) : expression(expression)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NIfStatement : public NStatement
{
public:
    std::shared_ptr<NExpression> condition;
    std::shared_ptr<NBlock> trueBlock;
    std::shared_ptr<NBlock> falseBlock;

    NIfStatement() = default;

    NIfStatement(std::shared_ptr<NExpression> condition, std::shared_ptr<NBlock> trueBlock,
                 std::shared_ptr<NBlock> falseBlock = nullptr) :
            condition(condition),
            trueBlock(trueBlock),
            falseBlock(falseBlock)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NForStatement : public NStatement
{
public:
    std::shared_ptr<NExpression> initial, condition, increment;
    std::shared_ptr<NBlock> block;

    NForStatement() = default;

    NForStatement(std::shared_ptr<NBlock> block, std::shared_ptr<NExpression> initial = nullptr,
                  std::shared_ptr<NExpression> condition = nullptr, std::shared_ptr<NExpression> increment = nullptr) :
            block(block),
            initial(initial),
            condition(condition),
            increment(increment)
    {
        if (condition == nullptr)
        {
            condition = std::make_shared<NInteger>(1);
        }
    }

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

class NLiteral : NExpression
{
public:
    std::string value;

    NLiteral() = default;

    NLiteral(const std::string str) :
            value(str)
    {}

    virtual llvm::Value *codeGen(CodeGenContext &context) override;
};

std::unique_ptr<NExpression> LogError(std::string str);

#endif //SLANG_ASTNODES_H
