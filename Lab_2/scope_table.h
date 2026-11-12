#include "symbol_info.h"

class scope_table
{
private:
    int bucket_count;
    int unique_id;
    scope_table *parent_scope = NULL;
    vector<list<symbol_info *>> table;

    int hash_function(string name)
    {
        // write your hash function here
        int hash_val = 0;
        for (int i = 0; i < (int)name.length(); i++)
        {
            hash_val = hash_val + (int)name[i];
        }
        return hash_val % bucket_count;
    }

public:
    scope_table();
    scope_table(int bucket_count, int unique_id, scope_table *parent_scope);
    scope_table *get_parent_scope();
    int get_unique_id();
    symbol_info *lookup_in_scope(symbol_info* symbol);
    bool insert_in_scope(symbol_info* symbol);
    bool delete_from_scope(symbol_info* symbol);
    void print_scope_table(ofstream& outlog);
    ~scope_table();

    // you can add more methods if you need
};

// complete the methods of scope_table class
scope_table::scope_table()
{
    bucket_count = 1;
    unique_id = 0;
    parent_scope = NULL;
    table.assign(bucket_count, list<symbol_info *>());
}

scope_table::scope_table(int bucket_count, int unique_id, scope_table *parent_scope)
{
    this->bucket_count = bucket_count > 0 ? bucket_count : 1;
    this->unique_id = unique_id;
    this->parent_scope = parent_scope;
    table.assign(this->bucket_count, list<symbol_info *>());
}

scope_table *scope_table::get_parent_scope()
{
    return parent_scope;
}

int scope_table::get_unique_id()
{
    return unique_id;
}

symbol_info *scope_table::lookup_in_scope(symbol_info* symbol)
{
    if (symbol == NULL || bucket_count <= 0)
    {
        return NULL;
    }

    int bucket_no = hash_function(symbol->get_name());
    for (auto it = table[bucket_no].begin(); it != table[bucket_no].end(); ++it)
    {
        if ((*it)->get_name() == symbol->get_name())
        {
            return *it;
        }
    }
    return NULL;
}

bool scope_table::insert_in_scope(symbol_info* symbol)
{
    if (symbol == NULL || bucket_count <= 0)
    {
        return false;
    }

    int bucket_no = hash_function(symbol->get_name());
    for (auto it = table[bucket_no].begin(); it != table[bucket_no].end(); ++it)
    {
        if ((*it)->get_name() == symbol->get_name())
        {
            return false;
        }
    }

    table[bucket_no].push_back(symbol);
    return true;
}

bool scope_table::delete_from_scope(symbol_info* symbol)
{
    if (symbol == NULL || bucket_count <= 0)
    {
        return false;
    }

    int bucket_no = hash_function(symbol->get_name());
    for (auto it = table[bucket_no].begin(); it != table[bucket_no].end(); ++it)
    {
        if ((*it)->get_name() == symbol->get_name())
        {
            delete *it;
            table[bucket_no].erase(it);
            return true;
        }
    }
    return false;
}

void scope_table::print_scope_table(ofstream& outlog)
{
    outlog << "ScopeTable # "+ to_string(unique_id) << endl;

    //iterate through the current scope table and print the symbols and all relevant information
    for (int i = 0; i < bucket_count; i++)
    {
        if (table[i].empty())
        {
            continue;
        }
        outlog << i << " --> " << endl;
        for (auto it = table[i].begin(); it != table[i].end(); it++)
        {
            symbol_info *symbol = *it;
            outlog << "< " << symbol->get_name() << " : " << symbol->get_type() << " >" << endl;

            if (symbol->get_symbol_kind() == "variable")
            {
                outlog << "Variable" << endl;
                outlog << "Type: " << symbol->get_data_type() << endl;
            }
            else if (symbol->get_symbol_kind() == "array")
            {
                outlog << "Array" << endl;
                outlog << "Type: " << symbol->get_data_type() << endl;
                outlog << "Size: " << symbol->get_array_size() << endl;
            }
            else if (symbol->get_symbol_kind() == "function_definition")
            {
                outlog << "Function Definition" << endl;
                outlog << "Return Type: " << symbol->get_data_type() << endl;
                outlog << "Number of Parameters: " << symbol->get_parameter_count() << endl;

                vector<string> parameter_types = symbol->get_parameter_types();
                vector<string> parameter_names = symbol->get_parameter_names();
                outlog << "Parameter Details: ";
                for (int j = 0; j < (int)parameter_types.size(); j++)
                {
                    if (j > 0)
                    {
                        outlog << ", ";
                    }
                    outlog << parameter_types[j];
                    if (parameter_names[j] != "")
                    {
                        outlog << " " << parameter_names[j];
                    }
                }
                outlog << endl;
            }
        }
        outlog << endl;
    }
}

scope_table::~scope_table()
{
    for (int i = 0; i < bucket_count; i++)
    {
        for (auto it = table[i].begin(); it != table[i].end(); ++it)
        {
            delete *it;
        }
        table[i].clear();
    }
    table.clear();
}