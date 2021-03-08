#ifndef HH2_LOG_H__
#define HH2_LOG_H__

#include <stdarg.h>

typedef enum {
    HH2_LOG_DEBUG,
    HH2_LOG_INFO,
    HH2_LOG_WARN,
    HH2_LOG_ERROR
}
hh2_LogLevel;

typedef void (*hh2_Logger)(hh2_LogLevel level, char const* format, va_list ap);

void hh2_setlogger(hh2_Logger logger);
void hh2_log(hh2_LogLevel level, char const* format, ...);
void hh2_vlog(hh2_LogLevel level, char const* format, va_list ap);

#endif // HH2_LOG_H__
