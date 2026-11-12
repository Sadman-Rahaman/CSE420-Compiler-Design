#ifndef SCOPE_TABLE_H
#define SCOPE_TABLE_H

#include "symbol_info.h"

class scope_table
{
private:
    int bucket_count;
    int unique_id;
    scope_table *parent_scope;
    vector<list<symbol_info *>> table;

    int hash_function(string name)
    {
        int sum = 0;
        for (size_t i = 0; i < name.size(); i++)
        {
            sum += name[i];
        }
        return sum % bucket_count;
    }

public:
    scope_table(int bucket_count, int unique_id, scope_table *parent_scope)
    {
        this->bucket_count = bucket_count;
        this->unique_id = unique_id;
        this->parent_scope = parent_scope;
        table.resize(bucket_count);
    }

    scope_table *get_parent_scope()
    {
        return parent_scope;
    }

    int get_unique_id()
    {
        return unique_id;
    }

    symbol_info *lookup_in_scope(symbol_info *symbol)
    {
        int index = hash_function(symbol->get_name());
        for (auto current : table[index])
        {
            if (current->get_name() == symbol->get_name())
                return current;
        }
        return NULL;
    }

    bool insert_in_scope(symbol_info *symbol)
    {
        if (lookup_in_scope(symbol) != NULL)
            return false;

        int index = hash_function(symbol->get_name());
        table[index].push_back(symbol);
        return true;
    }

    bool delete_from_scope(symbol_info *symbol)
    {
        int index = hash_function(symbol->get_name());
        for (auto it = table[index].begin(); it != table[index].end(); it++)
        {
            if ((*it)->get_name() == symbol->get_name())
            {
                table[index].erase(it);
                return true;
            }
        }
        return false;
    }

    void print_scope_table(ofstream &outlog)
    {
        outlog << "ScopeTable # " << unique_id << endl;

        for (int i = 0; i < bucket_count; i++)
        {
            if (table[i].empty())
                continue;

            outlog << i << " --> " << endl;

            for (auto current : table[i])
            {
                outlog << "< " << current->get_name() << " : " << current->get_type() << " >" << endl;

                if (current->get_id_kind() == "Function")
                {
                    outlog << "Function Definition" << endl;
                    outlog << "Return Type: " << current->get_data_type() << endl;
                    outlog << "Number of Parameters: " << current->get_param_count() << endl;
                    outlog << "Parameter Details: " << current->get_param_details() << endl;
                }
                else if (current->get_id_kind() == "Array")
                {
                    outlog << "Array" << endl;
                    outlog << "Type: " << current->get_data_type() << endl;
                    outlog << "Size: " << current->get_array_size() << endl;
                    outlog << endl;
                }
                else
                {
                    outlog << "Variable" << endl;
                    outlog << "Type: " << current->get_data_type() << endl;
                    outlog << endl;
                }
            }
        }

        outlog << endl;
    }

    ~scope_table()
    {
        for (int i = 0; i < bucket_count; i++)
        {
            for (auto current : table[i])
                delete current;
            table[i].clear();
        }
    }
};

#endif 
