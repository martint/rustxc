#include <string>
extern "C" int rustxc_cpp(const char *text) { return std::string(text).size(); }
