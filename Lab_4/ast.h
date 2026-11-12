#ifndef AST_H
#define AST_H

#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <map>

using namespace std;

class ASTNode {
public:
    virtual ~ASTNode() {}
    virtual string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp, int& temp_count, int& label_count) const = 0;
};

// Expression node types

class ExprNode : public ASTNode {
protected:
    string node_type; // Type information (int, float, void, etc.)
public:
    ExprNode(string type) : node_type(type) {}
    virtual string get_type() const { return node_type; }
};

// Variable node (for ID references)

class VarNode : public ExprNode {
private:
    string name;
    ExprNode* index; // For array access, nullptr for simple variables

public:
    VarNode(string name, string type, ExprNode* idx = nullptr)
        : ExprNode(type), name(name), index(idx) {}
    
    ~VarNode() { if(index) delete index; }
    
    bool has_index() const { return index != nullptr; }
    
    string generate_index_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                              int& temp_count, int& label_count) const {
        // Generate code to calculate the array index (as a byte offset) and
        // return the temp holding that offset.
        if (!index) return "";

        // First evaluate the raw (element) index expression, e.g. "i" or "i+1".
        string idx_val = index->generate_code(outcode, symbol_to_temp, temp_count, label_count);

        // Scale by the element size to turn an element-index into a byte
        // offset: int = 4 bytes, float = 8 bytes.
        int elem_size = (node_type == "float") ? 8 : 4;

        string offset_temp = "t" + to_string(temp_count++);
        outcode << offset_temp << " = " << idx_val << " * " << elem_size << endl;
        return offset_temp;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (has_index()) {
            // Array access: compute index, then load a[idx] into a fresh temp
            string idx_temp = generate_index_code(outcode, symbol_to_temp, temp_count, label_count);
            string t = "t" + to_string(temp_count++);
            outcode << t << " = " << name << "[" << idx_temp << "]" << endl;
            return t;
        } else {
            // Simple variable access.
            // Always reserve a temp id first (it may end up "wasted" if we
            // already have a cached temp for this variable's current value).
            string t = "t" + to_string(temp_count++);

            map<string, string>::iterator it = symbol_to_temp.find(name);
            if (it != symbol_to_temp.end()) {
                // Cache hit: reuse the existing temp, no new line emitted.
                return it->second;
            }

            // Cache miss: load the variable into the freshly reserved temp.
            outcode << t << " = " << name << endl;
            symbol_to_temp[name] = t;
            return t;
        }
    }
    
    string get_name() const { return name; }
};

// Constant node

class ConstNode : public ExprNode {
private:
    string value;

public:
    ConstNode(string val, string type) : ExprNode(type), value(val) {}
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Constants are always loaded fresh (never cached).
        string t = "t" + to_string(temp_count++);
        outcode << t << " = " << value << endl;
        return t;
    }
};

// Binary operation node

class BinaryOpNode : public ExprNode {
private:
    string op;
    ExprNode* left;
    ExprNode* right;

public:
    BinaryOpNode(string op, ExprNode* left, ExprNode* right, string result_type)
        : ExprNode(result_type), op(op), left(left), right(right) {}
    
    ~BinaryOpNode() {
        delete left;
        delete right;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string l = left->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string r = right->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string t = "t" + to_string(temp_count++);
        outcode << t << " = " << l << " " << op << " " << r << endl;
        return t;
    }
};

// Unary operation node

class UnaryOpNode : public ExprNode {
private:
    string op;
    ExprNode* expr;

public:
    UnaryOpNode(string op, ExprNode* expr, string result_type)
        : ExprNode(result_type), op(op), expr(expr) {}
    
    ~UnaryOpNode() { delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string e = expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        string t = "t" + to_string(temp_count++);
        outcode << t << " = " << op << e << endl;
        return t;
    }
};

// Assignment node

class AssignNode : public ExprNode {
private:
    VarNode* lhs;
    ExprNode* rhs;

public:
    AssignNode(VarNode* lhs, ExprNode* rhs, string result_type)
        : ExprNode(result_type), lhs(lhs), rhs(rhs) {}
    
    ~AssignNode() {
        delete lhs;
        delete rhs;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string rhs_temp = rhs->generate_code(outcode, symbol_to_temp, temp_count, label_count);

        if (lhs->has_index()) {
            string idx_temp = lhs->generate_index_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << lhs->get_name() << "[" << idx_temp << "] = " << rhs_temp << endl;
            // Array element writes are not cached (avoid aliasing issues).
        } else {
            outcode << lhs->get_name() << " = " << rhs_temp << endl;
            // Cache the new value so an immediately-following read of the
            // same variable can reuse it without reloading.
            symbol_to_temp[lhs->get_name()] = rhs_temp;
        }

        return rhs_temp;
    }
};

// Statement node types

class StmtNode : public ASTNode {
public:
    virtual string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                                int& temp_count, int& label_count) const = 0;
};

// Expression statement node

class ExprStmtNode : public StmtNode {
private:
    ExprNode* expr;

public:
    ExprStmtNode(ExprNode* e) : expr(e) {}
    ~ExprStmtNode() { if(expr) delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (expr) {
            return expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        return "";
    }
};

// Block (compound statement) node

class BlockNode : public StmtNode {
private:
    vector<StmtNode*> statements;

public:
    ~BlockNode() {
        for (auto stmt : statements) {
            delete stmt;
        }
    }
    
    void add_statement(StmtNode* stmt) {
        if (stmt) statements.push_back(stmt);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        for (size_t i = 0; i < statements.size(); i++) {
            if (statements[i]) {
                statements[i]->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            }
        }
        return "";
    }
};

// If statement node

class IfNode : public StmtNode {
private:
    ExprNode* condition;
    StmtNode* then_block;
    StmtNode* else_block; // nullptr if no else part

public:
    IfNode(ExprNode* cond, StmtNode* then_stmt, StmtNode* else_stmt = nullptr)
        : condition(cond), then_block(then_stmt), else_block(else_stmt) {}
    
    ~IfNode() {
        delete condition;
        delete then_block;
        if (else_block) delete else_block;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        string cond_temp = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);

        int L_true = label_count++;
        int L_false = label_count++;
        int L_end = label_count++;

        outcode << "if " << cond_temp << " goto L" << L_true << endl;
        outcode << "goto L" << L_false << endl;

        outcode << "L" << L_true << ":" << endl;
        if (then_block) {
            then_block->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        outcode << "goto L" << L_end << endl;

        outcode << "L" << L_false << ":" << endl;
        if (else_block) {
            else_block->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }

        outcode << "L" << L_end << ":" << endl;

        return "";
    }
};

// While statement node

class WhileNode : public StmtNode {
private:
    ExprNode* condition;
    StmtNode* body;

public:
    WhileNode(ExprNode* cond, StmtNode* body_stmt)
        : condition(cond), body(body_stmt) {}
    
    ~WhileNode() {
        delete condition;
        delete body;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        int L_cond = label_count++;
        int L_body = label_count++;
        int L_end = label_count++;

        outcode << "L" << L_cond << ":" << endl;
        string cond_temp = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        outcode << "if " << cond_temp << " goto L" << L_body << endl;
        outcode << "goto L" << L_end << endl;

        outcode << "L" << L_body << ":" << endl;
        if (body) {
            body->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        outcode << "goto L" << L_cond << endl;

        outcode << "L" << L_end << ":" << endl;

        return "";
    }
};

// For statement node

class ForNode : public StmtNode {
private:
    ExprNode* init;
    ExprNode* condition;
    ExprNode* update;
    StmtNode* body;

public:
    ForNode(ExprNode* init_expr, ExprNode* cond_expr, ExprNode* update_expr, StmtNode* body_stmt)
        : init(init_expr), condition(cond_expr), update(update_expr), body(body_stmt) {}
    
    ~ForNode() {
        if (init) delete init;
        if (condition) delete condition;
        if (update) delete update;
        delete body;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (init) {
            init->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }

        // The loop condition is (re-)entered via a backward jump, so any
        // values cached while generating the init code cannot safely be
        // assumed to still hold; start the condition with a clean cache.
        symbol_to_temp.clear();

        int L_cond = label_count++;
        int L_body = label_count++;
        int L_end = label_count++;

        outcode << "L" << L_cond << ":" << endl;
        string cond_temp = "";
        if (condition) {
            cond_temp = condition->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        outcode << "if " << cond_temp << " goto L" << L_body << endl;
        outcode << "goto L" << L_end << endl;

        outcode << "L" << L_body << ":" << endl;
        if (body) {
            body->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        if (update) {
            update->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }
        outcode << "goto L" << L_cond << endl;

        outcode << "L" << L_end << ":" << endl;

        return "";
    }
};

// Return statement node

class ReturnNode : public StmtNode {
private:
    ExprNode* expr;

public:
    ReturnNode(ExprNode* e) : expr(e) {}
    ~ReturnNode() { if (expr) delete expr; }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        if (expr) {
            string t = expr->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << "return " << t << endl;
        } else {
            outcode << "return" << endl;
        }
        return "";
    }
};

// Declaration node

class DeclNode : public StmtNode {
private:
    string type;
    vector<pair<string, int>> vars; // Variable name and array size (0 for regular vars)

public:
    DeclNode(string t) : type(t) {}
    
    void add_var(string name, int array_size = 0) {
        vars.push_back(make_pair(name, array_size));
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        for (size_t i = 0; i < vars.size(); i++) {
            if (vars[i].second > 0) {
                outcode << "// Declaration: " << type << " " << vars[i].first
                        << "[" << vars[i].second << "]" << endl;
            } else {
                outcode << "// Declaration: " << type << " " << vars[i].first << endl;
            }
        }
        return "";
    }
    
    string get_type() const { return type; }
    const vector<pair<string, int>>& get_vars() const { return vars; }
};

// Function declaration node

class FuncDeclNode : public ASTNode {
private:
    string return_type;
    string name;
    vector<pair<string, string>> params; // Parameter type and name
    BlockNode* body;

public:
    FuncDeclNode(string ret_type, string n) : return_type(ret_type), name(n), body(nullptr) {}
    ~FuncDeclNode() { if (body) delete body; }
    
    void add_param(string type, string name) {
        params.push_back(make_pair(type, name));
    }
    
    void set_body(BlockNode* b) {
        body = b;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Each function starts with a completely fresh variable-temp cache.
        symbol_to_temp.clear();

        outcode << "// Function: " << return_type << " " << name << "(";
        for (size_t i = 0; i < params.size(); i++) {
            outcode << params[i].first << " " << params[i].second;
            if (i != params.size() - 1) outcode << ", ";
        }
        outcode << ")" << endl;

        if (body) {
            body->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }

        outcode << endl;

        return "";
    }
};

// Helper class for function arguments

class ArgumentsNode : public ASTNode {
private:
    vector<ExprNode*> args;

public:
    ~ArgumentsNode() {
        // Don't delete args here - they'll be transferred to FuncCallNode
    }
    
    void add_argument(ExprNode* arg) {
        if (arg) args.push_back(arg);
    }
    
    ExprNode* get_argument(int index) const {
        if (index >= 0 && index < args.size()) {
            return args[index];
        }
        return nullptr;
    }
    
    size_t size() const {
        return args.size();
    }
    
    const vector<ExprNode*>& get_arguments() const {
        return args;
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // This node doesn't generate code directly
        return "";
    }
};

// Function call node

class FuncCallNode : public ExprNode {
private:
    string func_name;
    vector<ExprNode*> arguments;

public:
    FuncCallNode(string name, string result_type)
        : ExprNode(result_type), func_name(name) {}
    
    ~FuncCallNode() {
        for (auto arg : arguments) {
            delete arg;
        }
    }
    
    void add_argument(ExprNode* arg) {
        if (arg) arguments.push_back(arg);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        // Arguments are evaluated in an isolated cache context: a called
        // function might change values, so we don't want to permanently
        // trust/pollute the caller's cache with the argument loads, and we
        // don't want stale argument values reused from before the call.
        map<string, string> saved_cache = symbol_to_temp;
        symbol_to_temp.clear();

        for (size_t i = 0; i < arguments.size(); i++) {
            string arg_temp = arguments[i]->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            outcode << "param " << arg_temp << endl;
        }

        symbol_to_temp = saved_cache;

        string t = "t" + to_string(temp_count++);
        outcode << t << " = call " << func_name << ", " << arguments.size() << endl;
        return t;
    }
};

// Program node (root of AST)

class ProgramNode : public ASTNode {
private:
    vector<ASTNode*> units;

public:
    ~ProgramNode() {
        for (auto unit : units) {
            delete unit;
        }
    }
    
    void add_unit(ASTNode* unit) {
        if (unit) units.push_back(unit);
    }
    
    string generate_code(ofstream& outcode, map<string, string>& symbol_to_temp,
                        int& temp_count, int& label_count) const override {
        for (size_t i = 0; i < units.size(); i++) {
            if (units[i]) {
                units[i]->generate_code(outcode, symbol_to_temp, temp_count, label_count);
            }
        }
        return "";
    }
};

#endif // AST_H
