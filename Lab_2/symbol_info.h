#include<bits/stdc++.h>
using namespace std;

class symbol_info
{
private:
    string name;
    string type;
    string symbol_kind;
    string data_type;
    int array_size;
    vector<string> parameter_types;
    vector<string> parameter_names;
    vector<string> declaration_names;
    vector<int> declaration_sizes;
    string expression_type;

public:
    symbol_info(string name, string type)
    {
        this->name = name;
        this->type = type;
        this->symbol_kind = "variable";
        this->data_type = "";
        this->array_size = -1;
        this->expression_type = "";
    }
    string get_name()
    {
        return name;
    }
    string getname()
    {
        return name;
    }
    string get_type()
    {
        return type;
    }
    void set_name(string name)
    {
        this->name = name;
    }
    void setname(string name)
    {
        this->name = name;
    }
    void set_type(string type)
    {
        this->type = type;
    }

    void set_symbol_kind(string symbol_kind)
    {
        this->symbol_kind = symbol_kind;
    }

    string get_symbol_kind()
    {
        return symbol_kind;
    }

    void set_data_type(string data_type)
    {
        this->data_type = data_type;
    }

    string get_data_type()
    {
        return data_type;
    }

    void set_array_size(int array_size)
    {
        this->array_size = array_size;
    }

    int get_array_size()
    {
        return array_size;
    }

    void add_parameter(string parameter_type, string parameter_name = "")
    {
        parameter_types.push_back(parameter_type);
        parameter_names.push_back(parameter_name);
    }

    void clear_parameters()
    {
        parameter_types.clear();
        parameter_names.clear();
    }

    int get_parameter_count()
    {
        return (int)parameter_types.size();
    }

    vector<string> get_parameter_types()
    {
        return parameter_types;
    }

    vector<string> get_parameter_names()
    {
        return parameter_names;
    }

    void add_declaration(string declaration_name, int declaration_size = -1)
    {
        declaration_names.push_back(declaration_name);
        declaration_sizes.push_back(declaration_size);
    }

    vector<string> get_declaration_names()
    {
        return declaration_names;
    }

    vector<int> get_declaration_sizes()
    {
        return declaration_sizes;
    }

    void set_expression_type(string expression_type)
    {
        this->expression_type = expression_type;
    }

    string get_expression_type()
    {
        return expression_type;
    }

    ~symbol_info()
    {
        
    }
}
;