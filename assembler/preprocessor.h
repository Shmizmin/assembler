#ifndef preprocessor_h
#define preprocessor_h

#include <stdlib.h>

#if defined __cplusplus
#define EXTERNC extern "C"
#else
#define EXTERNC
EXTERNC char* process(char* source, const char* ogfp);
#undef EXTERNC
#endif

#endif
