#include "preprocessor.h"

#include <cstdio>
#include <cstdlib>

#include <sstream>
#include <fstream>
#include <filesystem>


#include <regex>
#include <string>
#include <vector>

namespace
{
    std::vector<std::string> split(std::string text, char delim)
    {
        std::string line;
        std::vector<std::string> vec;
        std::stringstream ss(text);
        while(std::getline(ss, line, delim))
        {
            vec.push_back(line);
        }
        return vec;
    }
    
    void replace(std::string& str, const std::string& from, const std::string& to)
    {
        if(from.empty()) return;
        size_t start_pos = 0;
        while((start_pos = str.find(from, start_pos)) != std::string::npos)
        {
            str.replace(start_pos, from.length(), to);
            start_pos += to.length();
        }
    }
    
    struct Macro
    {
        std::string name;
        std::vector<std::string> args;
        std::string code;
    };
}


extern "C"
{
	char* process(char* source, const char* ogfp)
	{
		std::string src = source;
		std::regex incl(R"((\.include \"(.*)\"\s*((;.*$)?|$)))");
        std::regex mcro(R"((\.macro ([a-z][a-zA-Z0-0_]*) = \((([a-zA-Z])(, [a-zA-Z])*)?\)\:\s*\{([^\}]*)\}))");
        std::regex invk(R"((([a-z][a-zA-Z0-9_]*)\(([^\,\)]*\s*(\,[^\,\)]*)*)?\)))");
        //fix the invoke macro, its capturing wayy too much
        
        std::vector<Macro> defined_macros, invoked_macros;
        
		std::smatch matches;
		while (std::regex_search(src, matches, incl))
		{
			std::string filepath = matches[2];
			std::ifstream file(filepath);
			std::size_t size = std::filesystem::file_size(filepath);
			std::string buffer(size, '\0');
			file.read(buffer.data(), size);
		
			if (filepath == ogfp)
			{
				std::fprintf(stderr, "[Error] File include recursion is not supported.\nExiting...\n");
				std::exit(1);
			}
			
            replace(src, matches[1], buffer);
		}
        
        while (std::regex_search(src, matches, mcro))
        {
            std::string name = matches[2];
            std::string arguments = matches[3];
            arguments.erase(std::remove_if(arguments.begin(), arguments.end(), ::isspace), arguments.end());
            std::vector<std::string> args = split(arguments, ',');
            
            std::string code = matches[6];
        
            Macro macro;
            macro.name = name;
            macro.args = args;
            macro.code = code;
            
            for (auto&& def : defined_macros)
            {
                if (def.name == macro.name)
                {
                    std::fprintf(stderr, "[Error] Macro %s is multiply defined.\nExiting...\n", macro.name.c_str());
                    std::exit(1);
                }
            }
            
            defined_macros.emplace_back(macro);
            
            replace(src, matches[1], "");
        }
        
        while (std::regex_search(src, matches, invk))
        {
            std::string name = matches[2];
            std::string arguments = matches[3];
            
            arguments.erase(std::remove_if(arguments.begin(), arguments.end(), ::isspace), arguments.end());
            std::vector<std::string> args = split(arguments, ',');
            
            
            Macro macro;
            macro.name = name;
            macro.args = args;
            macro.code = "";
            invoked_macros.emplace_back(macro);
            
            Macro defined_macro;
            
            
            bool found = false;
            for (auto&& m : defined_macros)
            {
                if (m.name == macro.name)
                {
                    defined_macro = m;
                    found = true;
                    break;
                }
            }
            
            if (!found)
            {
                std::fprintf(stderr, "[Error] Macro %s is undefined.\nExiting...\n", macro.name.c_str());
                std::exit(1);
            }
            
            if (defined_macro.args.size() != args.size())
            {
                std::fprintf(stderr, "[Error] Invokation of macro %s had %lu arguments, but expected %lu.\nExiting...\n", defined_macro.name.c_str(), args.size(), defined_macro.args.size());
                std::exit(1);
            }
            
            if (args.size() != 0)
            {
                std::string copy = defined_macro.code;
                
                for (auto i = 0; i < args.size(); ++i)
                {
                    replace(copy, "[" + defined_macro.args[i] + "]", args[i]);
                }
                
                replace(src, matches[1], copy);
            }
            
            else
            {
                std::string copy = defined_macro.code;
                replace(src, matches[1], copy);
            }
        }
        
        
        std::string_view end = ".end";
        auto pos = src.find(end);
        
        if (pos == std::string::npos)
        {
            std::fprintf(stderr, "[Error] Could not find viable end token\nExiting...\n");
            std::exit(1);
        }
        
        
        src = src.substr(0, pos + end.length());
        
        
		return strdup(src.c_str());
	}

}
