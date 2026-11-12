#ifndef SYMBOL_INFO_H
#define SYMBOL_INFO_H

#include <bits/stdc++.h>
using namespace std;

class symbol_info
{
private:
    string name;
    string type;

    string id_kind;       
    string data_type;     
    string param_details;
    int param_count;
    string array_size;

    vector<string> param_types;
    vector<string> argument_types;

    bool constant_known;
    double constant_value;
    bool void_function_call;

public:
    symbol_info(string name, string type)
    {
        this->name = name;
        this->type = type;

        id_kind = "";
        data_type = "";
        param_details = "";
        param_count = 0;
        array_size = "";

        constant_known = false;
        constant_value = 0.0;
        void_function_call = false;
    }

    string get_name()
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

    void set_type(string type)
    {
        this->type = type;
    }

    string get_id_kind()
    {
        return id_kind;
    }

    void set_id_kind(string kind)
    {
        id_kind = kind;
    }

    string get_data_type()
    {
        return data_type;
    }

    void set_data_type(string dtype)
    {
        data_type = dtype;
    }

    string get_array_size()
    {
        return array_size;
    }

    void set_array_size(string size)
    {
        array_size = size;
    }

    int get_param_count()
    {
        return param_count;
    }

    void set_param_count(int count)
    {
        param_count = count;
    }

    string get_param_details()
    {
        return param_details;
    }

    void set_param_details(string details)
    {
        param_details = details;
    }

    vector<string> get_param_types()
    {
        return param_types;
    }

    void set_param_types(vector<string> types)
    {
        param_types = types;
    }

    vector<string> get_argument_types()
    {
        return argument_types;
    }

    void set_argument_types(vector<string> types)
    {
        argument_types = types;
    }

    bool has_constant_value()
    {
        return constant_known;
    }

    double get_constant_value()
    {
        return constant_value;
    }

    void set_constant_value(double value)
    {
        constant_known = true;
        constant_value = value;
    }

    void clear_constant_value()
    {
        constant_known = false;
        constant_value = 0.0;
    }

    bool is_void_function_call()
    {
        return void_function_call;
    }

    void set_void_function_call(bool value)
    {
        void_function_call = value;
    }
};

#endif 
