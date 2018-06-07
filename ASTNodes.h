#ifndef ASTNODES_H
#define ASTNODES_H

#include <iostream>
#include <vector>
#include <llvm/IR/Value.h>

class GenCodeContext;

class AST_Expression;

class AST_Statement;

class AST_VariableDeclaration;

typedef std::vector<std::shared_ptr<AST_Expression>> AST_ExpressionList;
typedef std::vector<std::shared_ptr<AST_Statement>> AST_StatementList;
typedef std::vector<std::shared_ptr<AST_VariableDeclaration>> AST_VariableList;

class AST_Node
{
public:
    AST_Node() = default;

    virtual ~AST_Node() = default;

    virtual llvm::Value *generateCode(GenCodeContext &context)
    { return static_cast<llvm::Value *>(nullptr); }
};

class AST_Expression : public AST_Node
{
public:
    AST_Expression() = default;
};

class AST_Statement : public AST_Node
{
public:
    AST_Statement() = default;
};

class AST_Double : public AST_Expression
{
public:
    double value;

    AST_Double() = default;

    explicit AST_Double(double value) : value(value)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_Integer : public AST_Expression
{
public:
    uint64_t value;

    AST_Integer() = default;

    explicit AST_Integer(uint64_t value) : value(value)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;

    operator AST_Double() const
    {
        return AST_Double(value);
    }
};

class AST_Identifier : public AST_Expression
{
public:
    std::string name;
    bool isType = false;

    AST_Identifier() = default;

    explicit AST_Identifier(std::string &name) : name(name)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_MethodCall : public AST_Expression
{
public:
    const std::shared_ptr<AST_Identifier> id;
    std::shared_ptr<AST_ExpressionList> arguments = std::make_shared<AST_ExpressionList>();

    AST_MethodCall() = default;

    explicit AST_MethodCall(const std::shared_ptr<AST_Identifier> id) : id(id)
    {}

    AST_MethodCall(const std::shared_ptr<AST_Identifier> id, std::shared_ptr<AST_ExpressionList> arguments) :
            id(id),
            arguments(arguments)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_BinaryOperator : public AST_Expression
{
public:
    int op;
    std::shared_ptr<AST_Expression> lhs;
    std::shared_ptr<AST_Expression> rhs;

    AST_BinaryOperator() = default;

    AST_BinaryOperator(std::shared_ptr<AST_Expression> lhs, int op, std::shared_ptr<AST_Expression> rhs) :
            lhs(lhs),
            op(op),
            rhs(rhs)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_Assignment : public AST_Expression
{
public:
    std::shared_ptr<AST_Identifier> lhs;
    std::shared_ptr<AST_Expression> rhs;

    AST_Assignment() = default;

    AST_Assignment(std::shared_ptr<AST_Identifier> lhs, std::shared_ptr<AST_Expression> rhs) :
            lhs(lhs),
            rhs(rhs)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_Block : public AST_Expression
{
public:
    std::shared_ptr<AST_StatementList> statements = std::make_shared<AST_StatementList>();

    AST_Block() = default;

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_ExpressionStatement : public AST_Statement
{
public:
    std::shared_ptr<AST_Expression> expression;

    AST_ExpressionStatement() = default;

    AST_ExpressionStatement(std::shared_ptr<AST_Expression> expression)
            : expression(expression)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_VariableDeclaration : public AST_Statement
{
public:
    const std::shared_ptr<AST_Identifier> type;
    std::shared_ptr<AST_Identifier> id;
    std::shared_ptr<AST_Expression> assignmentExpr = nullptr;

    AST_VariableDeclaration() = default;

    AST_VariableDeclaration(const std::shared_ptr<AST_Identifier> type, std::shared_ptr<AST_Identifier> id,
                         std::shared_ptr<AST_Expression> assignmentExpr = nullptr) :
            type(type),
            id(id),
            assignmentExpr(assignmentExpr)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_FunctionDeclaration : public AST_Statement
{
public:
    std::shared_ptr<AST_Identifier> type;
    std::shared_ptr<AST_Identifier> id;
    std::shared_ptr<AST_VariableList> arguments = std::make_shared<AST_VariableList>();
    std::shared_ptr<AST_Block> block;

    AST_FunctionDeclaration() = default;

    AST_FunctionDeclaration(std::shared_ptr<AST_Identifier> type, std::shared_ptr<AST_Identifier> id,
                         std::shared_ptr<AST_VariableList> arguments, std::shared_ptr<AST_Block> block) :
            type(type),
            id(id),
            arguments(arguments),
            block(block)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_ReturnStatement : public AST_Statement
{
public:
    std::shared_ptr<AST_Expression> expression;

    AST_ReturnStatement() = default;

    explicit AST_ReturnStatement(std::shared_ptr<AST_Expression> expression) : expression(expression)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_IfStatement : public AST_Statement
{
public:
    std::shared_ptr<AST_Expression> condition;
    std::shared_ptr<AST_Block> trueBlock;
    std::shared_ptr<AST_Block> falseBlock;

    AST_IfStatement() = default;

    AST_IfStatement(std::shared_ptr<AST_Expression> condition, std::shared_ptr<AST_Block> trueBlock,
                 std::shared_ptr<AST_Block> falseBlock = nullptr) :
            condition(condition),
            trueBlock(trueBlock),
            falseBlock(falseBlock)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_ForStatement : public AST_Statement
{
public:
    std::shared_ptr<AST_Expression> initial, condition, increment;
    std::shared_ptr<AST_Block> block;

    AST_ForStatement() = default;

    AST_ForStatement(std::shared_ptr<AST_Block> block, std::shared_ptr<AST_Expression> initial = nullptr,
                  std::shared_ptr<AST_Expression> condition = nullptr, std::shared_ptr<AST_Expression> increment = nullptr) :
            block(block),
            initial(initial),
            condition(condition),
            increment(increment)
    {
        if (condition == nullptr)
        {
            condition = std::make_shared<AST_Integer>(1);
        }
    }

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

class AST_Literal : AST_Expression
{
public:
    std::string value;

    AST_Literal() = default;

    AST_Literal(const std::string str) :
            value(str)
    {}

    virtual llvm::Value *generateCode(GenCodeContext &context) override;
};

std::unique_ptr<AST_Expression> LogError(std::string str);

#endif //ASTNODES_H
