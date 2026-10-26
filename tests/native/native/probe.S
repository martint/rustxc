#ifdef __APPLE__
#define NAME _rustxc_asm
#else
#define NAME rustxc_asm
#endif
.text
.globl NAME
NAME:
#if defined(__aarch64__)
    mov w0, #42
    ret
#elif defined(__x86_64__)
    mov $42, %eax
    ret
#elif defined(__powerpc64__)
    li 3, 42
    blr
#else
#error Unsupported smoke architecture
#endif
