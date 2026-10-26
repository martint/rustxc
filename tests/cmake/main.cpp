extern "C" int rustxc_c();
extern "C" int rustxc_cpp(const char *text);
int main() { return rustxc_c() == 8 && rustxc_cpp("rustxc") == 6 ? 0 : 1; }
