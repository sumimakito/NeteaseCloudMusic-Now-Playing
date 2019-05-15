#ifndef NCMNP_NCMNP_UTILS_H
#define NCMNP_NCMNP_UTILS_H

#include <stdio.h>

#ifdef NCMNP_LOGGING_COLORFUL
#define FATAL(fmt, args...) printf("\e[91mfatal: " fmt "\e[0m\n", ##args); exit(EXIT_FAILURE)
#define WARN(fmt, args...)  printf("\e[93mwarning: " fmt "\e[0m\n", ##args)
#define INFO(fmt, args...)  printf("\e[96minfo: " fmt "\e[0m\n", ##args)
#else
#ifdef NCMNP_LOGGING_NORMAL
#define FATAL(fmt, args...) printf("fatal: " fmt, ##args); exit(EXIT_FAILURE)
#define WARN(fmt, args...)  printf("warning: " fmt, ##args)
#define INFO(fmt, args...)  printf("info: " fmt, ##args)
#else
#define FATAL(fmt, args...) printf("fatal: " fmt, ##args); exit(EXIT_FAILURE)
#define WARN(fmt, args...)  printf("warning: " fmt, ##args)
#define INFO(fmt, args...)
#endif
#endif

#endif
