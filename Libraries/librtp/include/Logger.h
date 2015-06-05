
#ifndef _LOGGER_H_
#define _LOGGER_H_

//#define LOGGER_PTHREAD
//#define LOGGER_OSTREAM

// TODO: Add filtering by file and function regexp

#if defined(__GLIBC__) && !defined(_GNU_SOURCE)
#  define _GNU_SOURCE
#endif

#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <locale.h>
#include <math.h>
#include <printf.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <unistd.h>

#ifndef NDEBUG
#  include <execinfo.h>
#  include <cxxabi.h>
#endif

#ifdef LOGGER_PTHREAD
#  include <pthread.h>
#endif

#ifdef LOGGER_OSTREAM
#  include <alloca.h>

#  include <algorithm>
#  include <locale>
#  include <ostream>
#  include <sstream>
#  include <iomanip>
#endif

#ifndef __printflike
#  define __printflike(fmtarg, firstvararg) \
                __attribute__((__format__(__printf__, fmtarg, firstvararg)))
#endif

///////////////////////////////////////////////////////////////////////

namespace {

class StashErrno
{
public:

    StashErrno()
        : _errno(errno)
    {}

    ~StashErrno()
    {
        errno = _errno;
    }

private:

    int _errno;
};

};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                              LOGGER                               //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class Logger
{
public:

    // see RFC-5424
    enum Level
    {
        LEVEL_OFF       = -1,

        LEVEL_FATAL     = 0, // system is unusable
        LEVEL_ALERT     = 1, // action must be taken immediately
        LEVEL_CRITICAL  = 2, // critical condition
        LEVEL_ERROR     = 3, // error condition
        LEVEL_WARN      = 4, // warning condition
        LEVEL_NOTICE    = 5, // normal but significant condition
        LEVEL_INFO      = 6, // informational messages
        LEVEL_DEBUG     = 7, // debug level messages

        LEVEL_ON        = 8
    };

    static const char* level_to_string(int level)
    {
        if (level < LEVEL_FATAL)
            level = LEVEL_FATAL;
        else if (level > LEVEL_DEBUG)
            level = LEVEL_DEBUG;

        switch (level)
        {
        case LEVEL_FATAL:       return "FATAL";
        case LEVEL_ALERT:       return "ALERT";
        case LEVEL_CRITICAL:    return "CRITICAL";
        case LEVEL_ERROR:       return "ERROR";
        case LEVEL_WARN:        return "WARN";
        case LEVEL_NOTICE:      return "NOTICE";
        case LEVEL_INFO:        return "INFO";
        case LEVEL_DEBUG:       return "DEBUG";
        };
        abort(); // will never happen
    }

    class LevelOverride
    {
    public:

        LevelOverride(Logger& logger)
            : _logger(logger)
            , _level(logger.level())
        {}

        LevelOverride(Logger& logger, int level)
            : _logger(logger)
            , _level(logger.level())
        {
            this->level(level);
        }

        ~LevelOverride()
        {
            release();
        }

        operator bool () const
        {
            return _logger.level() < _level;
        }

        void level(int level)
        {
            if (level < _level && _level < LEVEL_DEBUG)
                _logger.level(level);
        }

        void release()
        {
            if (_logger.level() < _level)
                _logger.level(_level);
        }

    private:

        Logger& _logger;
        const int _level;
    };

#ifdef LOGGER_OSTREAM
    class OStream
        : public std::ostream
    {
    public:

        OStream(std::streambuf* buf = NULL)
            : std::ostream(buf)
        {
            if (buf == NULL)
            {
                setstate(ios_base::badbit);
            }
        }

        virtual ~OStream()
        {
            delete rdbuf();
        }

        OStream& imbue(const char* name)
        {
            std::locale mylocale(name);
            (void) std::ostream::imbue(mylocale);
            return *this;
        }
    };

    class Imbue
    {
    public:

        Imbue(const char* name)
            : _name(name)
        {}

        const char* _name;
    };

    friend std::ostream& operator<<(std::ostream& out, const Imbue& rhs)
    {
        std::locale mylocale(rhs._name);
        (void) out.imbue(mylocale);
        return out;
    }
#endif

public:

    int level() const
    {
        return _level;
    }

    void level(int level)
    {
        _level = level;
    }

protected:

    Logger()
        : _level(Logger::LEVEL_OFF)
    {}

private:

    int _level;
};

template <typename Impl>
class LoggerImpl
    : public Logger, public Impl
{
public:

    LoggerImpl()
        : Logger(), Impl()
    {
        setlocale(LC_ALL, "");
    }

    bool is_enabled(int level) const
    {
        return level <= this->level() && Impl::is_enabled();
    }

    void log(int level, const char* fmt, ...) const
        __printflike(3, 4)
    {
        va_list ap;
        va_start(ap, fmt);
        log(level, fmt, ap);
        va_end(ap);
    }

    void log(int level, const char* fmt, va_list args) const
        __printflike(3, 0)
    {
        if (! is_enabled(level))
            return;

        StashErrno stasherrno;
        Impl::log(level, fmt, args);
    }

#define LOGGER_CONVINIENCE(lvl, LVL)            \
    bool is_##lvl##_enabled() const             \
    {                                           \
        return is_enabled(LEVEL_##LVL);         \
    }                                           \
    void lvl(const char* fmt, ...) const        \
        __printflike(2, 3)                      \
    {                                           \
        va_list ap;                             \
        va_start(ap, fmt);                      \
        log(LEVEL_##LVL, fmt, ap);              \
        va_end(ap);                             \
    }                                           \
    void lvl(const char* fmt, va_list ap) const \
        __printflike(2, 0)                      \
    {                                           \
        log(LEVEL_##LVL, fmt, ap);              \
    }

    LOGGER_CONVINIENCE(fatal,       FATAL)
    LOGGER_CONVINIENCE(alert,       ALERT)
    LOGGER_CONVINIENCE(critical,    CRITICAL)
    LOGGER_CONVINIENCE(error,       ERROR)
    LOGGER_CONVINIENCE(warn,        WARN)
    LOGGER_CONVINIENCE(notice,      NOTICE)
    LOGGER_CONVINIENCE(info,        INFO)
    LOGGER_CONVINIENCE(debug,       DEBUG)

#undef LOGGER_CONVINIENCE

    void backtrace(int lvl, unsigned skip = 1) const
    {
#ifndef NDEBUG

        void* buffer[25];
        int n = ::backtrace(buffer, sizeof(buffer)/sizeof(buffer[0]));
        if (n <= (int)skip)
        {
            log(Logger::LEVEL_WARN, "backtrace: %d < %u", n, skip);
            return;
        }

        char** s = ::backtrace_symbols(buffer, n);
        if (s == NULL)
        {
            log(Logger::LEVEL_WARN, "backtrace_symbols: %s", strerror(errno));
            return;
        }

#  ifdef __linux__
        if (n == sizeof(buffer)/sizeof(buffer[0]))
        {
            // there seem to be a problem with backtrace()
            // at least on linux 3.18.3+ w/ glibc-2.13-38+rpi2+deb7u6
            // where the same stack trace gets returned over and over
            for (unsigned i = n - 1; i > skip; --i)
            {
                if (strcmp(s[i], s[i-1]) == 0)
                    s[i][0] = '\0';
            }
        }
#  endif

        int i;
        char* demangled = NULL;
        size_t demangled_len = 0;
        for (i = skip; i < n; ++i)
        {
            int status = -3;

#  ifdef __linux__
            if (s[i][0] == '\0')
                continue;

            // extract mangled function name
            // rtpraspivid(_ZN16UDPBoundedSender13add_interfaceEPK7ifaddrs+0xcc) [0x2ac2c]

            char* oparen = strchr(s[i], '(');
            if (oparen != NULL)
            {
                char* plus = strchr(oparen, '+');
                if (plus != NULL)
                {
                    char* cparen = strchr(plus, ')');
                    if (cparen != NULL)
                    {
                        *plus = '\0';
                        demangled = abi::__cxa_demangle(oparen+1, demangled, &demangled_len, &status);
                        switch (status)
                        {
                        case -3:
                            log(Logger::LEVEL_WARN, "__cxa_demangle(%s)", oparen+1);
                            *plus = '+'; // restore s[i]
                            break;
                        case -1:
                            log(Logger::LEVEL_WARN, "__cxa_demangle(%s): out of mem", oparen+1);
                            *plus = '+'; // restore s[i]
                            break;
                        case -2:
                            // mangled name is not actually mangled.
                            *cparen = '\0';
                            log(lvl, "\tat %s + %s", oparen+1, plus+1);
                            status = 0;
                            break;
                        case 0:
                            *cparen = '\0';
                            log(lvl, "\tat %s + %s", demangled, plus+1);
                            break;
                        default:
                            assert(false); // unreachable
                        }
                    }
                }
            }

#  elif defined(__APPLE__)
            // extract mangled function name
            // 0   rtpserver                           0x0000000100021bd0 _ZNK10LoggerImplI14FileLoggerImplE9backtraceEij + 80

            char* plus = strrchr(s[i], '+');
            if (plus != NULL && (plus - s[i]) > 2)
            {
                *(plus - 1) = '\0';
                char* mangled = strrchr(s[i], ' ');
                if (mangled != NULL)
                {
                    ++mangled;
                    demangled = abi::__cxa_demangle(mangled, demangled, &demangled_len, &status);
                    switch (status)
                    {
                    case -3:
                        log(Logger::LEVEL_WARN, "__cxa_demangle(%s)", mangled);
                        *(plus - 1) = ' '; // restore s[i]
                        break;
                    case -1:
                        log(Logger::LEVEL_WARN, "__cxa_demangle(%s): out of mem", mangled);
                        *(plus - 1) = ' '; // restore s[i]
                        break;
                    case -2:
                        // mangled name is not actually mangled.
                        log(lvl, "\tat %s + %s", mangled, plus+2);
                        status = 0;
                        break;
                    case 0:
                        log(lvl, "\tat %s + %s", demangled, plus+2);
                        break;
                    default:
                        assert(false); // unreachable
                    }
                }
            }
#  endif

            if (status != 0)
            {
                // demangling didn't work... print full (mangled) backtrace
                log(lvl, "\tat %s", s[i]);
            }

#  ifdef __linux__

            if (strncmp(s[i], "/lib/", 5) == 0)
                break;

#  elif defined(__APPLE__)

            size_t exe = strcspn(s[i], " ");
            if (s[i][exe] != '\0')
            {
                exe = strspn(&s[i][exe], " ");
                if (s[i][exe] != '\0')
                {
                    ++exe;
                    const size_t space = strcspn(&s[i][exe], " ");
                    if (s[i][exe+space] != '\0')
                    {
                        s[i][exe+space] = '\0';
                        char* dot = strstr(&s[i][exe], ".dylib");
                        if (dot != NULL)
                            break;
                    }
                }
            }
#  endif
        }

        if (i == sizeof(buffer)/sizeof(buffer[0]))
            log(lvl, "\t...");

        if (demangled != NULL)
            free(demangled);

        free(s);

#endif
    }

#ifdef LOGGER_OSTREAM

public:

    std::streambuf* streambuf(int level) const
    {
        return is_enabled(level) ? new LoggerStreamBuf(level, this) : NULL;
    }

    std::streambuf* streambufwithbacktrace(int level, unsigned skip) const
    {
        return is_enabled(level) ? new LoggerWithBacktraceStreamBuf(level, this, skip) : NULL;
    }

private:

#  if 0
    class LoggerStreamBuf
        : public std::streambuf
    {
    public:

        LoggerStreamBuf(int level, const LoggerImpl* impl)
            : _level(level)
            , _impl(impl)
        {
            setp(_buffer, _buffer + (BUFFER_SIZE - 2));
        }

        virtual ~LoggerStreamBuf()
        {
            sync();
        }

    protected:

        virtual int overflow(int c = EOF)
        {
            if (c != EOF)
            {
                *pptr() = c;    // insert character into the buffer
                pbump(1);
            }
            return c;
        }

        virtual int sync()
        {
            int num =  pptr() - pbase();

            if (num > 0)
            {
                *pptr() = '\0';
                _impl->log(_level, "%s", pbase());

                pbump(-num);
            }

            return num;
        }

    private:

        static const unsigned BUFFER_SIZE = 256;
        char _buffer[BUFFER_SIZE];

        const int _level;
        const LoggerImpl* _impl;
    };
#  else
    class LoggerStreamBuf
        : public std::stringbuf
    {
    public:

        LoggerStreamBuf(int level, const LoggerImpl* impl)
            : std::stringbuf(std::ios_base::out)
            , _level(level)
            , _impl(impl)
        {}

        virtual ~LoggerStreamBuf()
        {
            sync();
        }

    protected:

        virtual int sync()
        {
            if (pptr() > pbase())
            {
                std::string s = str();
                // TODO: deal with \n anywhere in the string
                if (*(s.rbegin()) == '\n')
                    s.resize(s.size() - 1);
                _impl->log(_level, "%s", s.c_str());
                str(""); // reset string
            }
            return 0;
        }

    protected:

        const int _level;
        const LoggerImpl* _impl;
    };

    class LoggerWithBacktraceStreamBuf
        : public LoggerStreamBuf
    {
    public:

        LoggerWithBacktraceStreamBuf(int level,
                                     const LoggerImpl* impl,
                                     unsigned skip = 1)
            : LoggerStreamBuf(level, impl)
            , _skip(skip)
        {}

    protected:

        virtual int sync()
        {
            if (std::stringbuf::pptr() > std::stringbuf::pbase())
            {
                LoggerStreamBuf::sync();
                LoggerStreamBuf::_impl->backtrace(LoggerStreamBuf::_level, _skip);
            }
            return 0;
        }

    private:

        const unsigned _skip;
    };
#  endif

    class NullStreamBuf
        : public std::streambuf
    {
    public:

        NullStreamBuf()
        {}

    protected:

        virtual int overflow(int c = EOF)
        {
            return traits_type::not_eof(c); // success
        }
    };

#endif
};

///////////////////////////////////////////////////////////////////////
//
// FileLoggerImpl -- directs Logger oputput to a file
//

class FileLoggerImpl
{
public:

    FileLoggerImpl()
        : _stream(NULL)
    {
#ifdef __APPLE__
        _printf_domain = new_printf_domain();
        register_printf_domain_function(_printf_domain, 'B', printf_size, printf_size_info, NULL);
        register_printf_domain_function(_printf_domain, 'b', printf_size, printf_size_info, NULL);
#else
        register_printf_function('B', printf_size, printf_size_info); // %B -> k, m, g. Powers of 1000
        register_printf_function('b', printf_size, printf_size_info); // %b -> K, M, G. Powers of 1024
#endif
    }

    ~FileLoggerImpl()
    {
#ifdef __APPLE__
        free_printf_domain(_printf_domain);
#endif
    }

    void stream(FILE* stream);

    bool is_enabled() const
    {
        return _stream != NULL && ! ferror(_stream);
    }

    void log(int level, const char* fmt, va_list args) const;

private:

#ifdef __APPLE__

    static int back_to_format(char* buffer, size_t bufsiz,
                              const struct printf_info* info);

    static int printf_size(FILE* stream,
                           const struct printf_info* info,
                           const void* const* args);

    static int printf_size_info(const struct printf_info* /*info*/,
                                size_t n,
                                int* argtypes);

#endif

protected:

#ifdef __APPLE__
    printf_domain_t _printf_domain;
#endif

private:

    FILE* _stream;
    bool _has_colors;
};

///////////////////////////////////////////////////////////////////////
//
// SysLogLoggerImpl -- directs Logger output to SysLog
//

class SyslogLoggerImpl
{
public:

    SyslogLoggerImpl()
    {}

    ~SyslogLoggerImpl()
    {
        closelog();
    }

    void open(const char* ident,
              int logopt = LOG_CONS | LOG_NDELAY | LOG_PERROR,
              int facility = LOG_USER)
    {
        openlog(ident, logopt, facility);
    }

    bool is_enabled() const
    {
        return true;
    }

    void log(int level, const char* fmt, va_list args) const
    {
        // FIXME: vsyslog doesn't handle %b or %B
        //        but it does %m
        vsyslog(level, fmt, args);
    }
};

///////////////////////////////////////////////////////////////////////
//
// ASLLoggerImpl -- directs Logger output to the Apple System Log facility
//

#ifdef __APPLE__

#  include <asl.h>
#  include <TargetConditionals.h>

class ASLLoggerImpl
{
public:

    ASLLoggerImpl()
        : _asl(NULL)
    {}

    ~ASLLoggerImpl()
    {
        if (_asl)
            asl_close(_asl);
    }

    bool open(const char* ident,
              const char* facility,
              uint32_t opts = ASL_OPT_NO_DELAY)
    {
        _asl = asl_open(ident, facility, opts);
        return _asl != NULL;
    }

    int add_log_file(int descriptor)
    {
        return asl_add_log_file(_asl, descriptor);
    }

    int add_output_file(int descriptor,
                        const char* msg_fmt,
                        const char* time_fmt,
                        int filter,
                        int text_encoding)
    {
        return asl_add_output_file(_asl, descriptor, msg_fmt, time_fmt, filter, text_encoding);
    }

    bool is_enabled() const
    {
        return true;
    }

    void log(int level, const char* fmt, va_list args) const
    {
        // FIXME: vsyslog doesn't handle %b or %B
        //        but it does %m
        asl_vlog(_asl, NULL, level, fmt, args);
    }

private:

    aslclient _asl;
};

#  if TARGET_OS_IPHONE
#    define LOGGER_IMPL ASLLoggerImpl
#  endif
#endif

///////////////////////////////////////////////////////////////////////
//
// logger
//

#ifndef LOGGER_IMPL
#  define LOGGER_IMPL FileLoggerImpl
#endif

extern LoggerImpl<LOGGER_IMPL> logger;

///////////////////////////////////////////////////////////////////////
//
// LOGGER_FATAL
// LOGGER_ALERT
// LOGGER_CRITICAL
// LOGGER_ERROR     -- convinience logging methods
// LOGGER_WARN
// LOGGER_NOTICE
// LOGGER_INFO
// LOGGER_DEBUG
//
// LOGGER_IS_* -- check if logging is enabled for a level
//
// Examples:
//  - LOGGER_DEBUG("Hello Debug World!")
//  - if (LOGGER_IS_DEBUG())
//        LOGGER_DEBUG("%s %s %s!", "Hello", "Debug", "World")

#define __SHORT_FILE__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)

// LOGGER_FATAL, LOGGER_ALERT, LOGGER_CRITICAL, LOGGER_ERROR
// - prepend "__FILE__:__LINE__: "
// - append stack trace

#define LOGGER_CONVINIENCE(lvl, LVL)                        \
    static inline bool LOGGER_IS_##LVL()                    \
    {                                                       \
        return logger.is_enabled(Logger::LEVEL_##LVL);      \
    }                                                       \
    static inline void __LOGGER_##LVL(const char* fmt, ...) \
        __printflike(1, 2);                                 \
    static inline void __LOGGER_##LVL(const char* fmt, ...) \
    {                                                       \
        va_list ap;                                         \
        va_start(ap, fmt);                                  \
        logger.lvl(fmt, ap);                                \
        va_end(ap);                                         \
                                                            \
        logger.backtrace(Logger::LEVEL_##LVL, 2);           \
    }

LOGGER_CONVINIENCE(fatal,     FATAL)
LOGGER_CONVINIENCE(alert,     ALERT)
LOGGER_CONVINIENCE(critical,  CRITICAL)
LOGGER_CONVINIENCE(error,     ERROR)

#undef LOGGER_CONVINIENCE

#define LOGGER_FATAL(fmt, ...)          __LOGGER_FATAL(     "%s:%d: " fmt, __SHORT_FILE__, __LINE__, ## __VA_ARGS__)
#define LOGGER_ALERT(fmt, ...)          __LOGGER_ALERT(     "%s:%d: " fmt, __SHORT_FILE__, __LINE__, ## __VA_ARGS__)
#define LOGGER_CRITICAL(fmt, ...)       __LOGGER_CRITICAL(  "%s:%d: " fmt, __SHORT_FILE__, __LINE__, ## __VA_ARGS__)
#define LOGGER_ERROR(fmt, ...)          __LOGGER_ERROR(     "%s:%d: " fmt, __SHORT_FILE__, __LINE__, ## __VA_ARGS__)

// LOGGER_WARN
// - prepend "__FILE__:__LINE__: "
// - no stack trace

#define LOGGER_CONVINIENCE(lvl, LVL)                        \
    static inline bool LOGGER_IS_##LVL()                    \
    {                                                       \
        return logger.is_enabled(Logger::LEVEL_##LVL);      \
    }                                                       \
    static inline void __LOGGER_##LVL(const char* fmt, ...) \
        __printflike(1, 2);                                 \
    static inline void __LOGGER_##LVL(const char* fmt, ...) \
    {                                                       \
        va_list ap;                                         \
        va_start(ap, fmt);                                  \
        logger.lvl(fmt, ap);                                \
        va_end(ap);                                         \
    }

LOGGER_CONVINIENCE(warn,      WARN)

#undef LOGGER_CONVINIENCE

#define LOGGER_WARN(fmt, ...)           __LOGGER_WARN(      "%s:%d: " fmt, __SHORT_FILE__, __LINE__, ## __VA_ARGS__)

// LOGGER_NOTICE, LOGGER_INFO, LOGGER_DEBUG
// - no "__FILE__:__LINE__: "
// - no stack trace

#define LOGGER_CONVINIENCE(lvl, LVL)                        \
    static inline bool LOGGER_IS_##LVL()                    \
    {                                                       \
        return logger.is_enabled(Logger::LEVEL_##LVL);      \
    }                                                       \
    static inline void LOGGER_##LVL(const char* fmt, ...)   \
        __printflike(1, 2);                                 \
    static inline void LOGGER_##LVL(const char* fmt, ...)   \
    {                                                       \
        va_list ap;                                         \
        va_start(ap, fmt);                                  \
        logger.lvl(fmt, ap);                                \
        va_end(ap);                                         \
    }

LOGGER_CONVINIENCE(notice,    NOTICE)
LOGGER_CONVINIENCE(info,      INFO)
LOGGER_CONVINIENCE(debug,     DEBUG)

#undef LOGGER_CONVINIENCE

///////////////////////////////////////////////////////////////////////
//
// LOGGER_P* -- prepend ": <strerror>"
//

#define LOGGER_PFATAL(fmt, ...)         LOGGER_FATAL(       fmt ": %s", ## __VA_ARGS__, strerror(errno))
#define LOGGER_PALERT(fmt, ...)         LOGGER_ALTER(       fmt ": %s", ## __VA_ARGS__, strerror(errno))
#define LOGGER_PCRITICAL(fmt, ...)      LOGGER_CRITICAL(    fmt ": %s", ## __VA_ARGS__, strerror(errno))
#define LOGGER_PERROR(fmt, ...)         LOGGER_ERROR(       fmt ": %s", ## __VA_ARGS__, strerror(errno))
#define LOGGER_PWARN(fmt, ...)          LOGGER_WARN(        fmt ": %s", ## __VA_ARGS__, strerror(errno))
#define LOGGER_PNOTICE(fmt, ...)        LOGGER_NOTICE(      fmt ": %s", ## __VA_ARGS__, strerror(errno))
#define LOGGER_PINFO(fmt, ...)          LOGGER_INFO(        fmt ": %s", ## __VA_ARGS__, strerror(errno))
#define LOGGER_PDEBUG(fmt, ...)         LOGGER_DEBUG(       fmt ": %s", ## __VA_ARGS__, strerror(errno))

///////////////////////////////////////////////////////////////////////
//
// LOGGER_O* -- stream interface
//
// Example:
//  - LOGGER_ODEBUG(cdbg) << "Hello Debug" << " World!" << std::flush;

#ifdef LOGGER_OSTREAM
#    define LOGGER_OFATAL(x)            Logger::OStream x(logger.streambufwithbacktrace(Logger::LEVEL_FATAL, 4));       x.imbue("C") << __SHORT_FILE__ << ':' << __LINE__ << ": " << Logger::Imbue("")
#    define LOGGER_OALERT(x)            Logger::OStream x(logger.streambufwithbacktrace(Logger::LEVEL_ALERT, 4));       x.imbue("C") << __SHORT_FILE__ << ':' << __LINE__ << ": " << Logger::Imbue("")
#    define LOGGER_OCRITICAL(x)         Logger::OStream x(logger.streambufwithbacktrace(Logger::LEVEL_CRITICAL, 4));    x.imbue("C") << __SHORT_FILE__ << ':' << __LINE__ << ": " << Logger::Imbue("")
#    define LOGGER_OERROR(x)            Logger::OStream x(logger.streambufwithbacktrace(Logger::LEVEL_ERROR, 4));       x.imbue("C") << __SHORT_FILE__ << ':' << __LINE__ << ": " << Logger::Imbue("")

#    define LOGGER_OWARN(x)             Logger::OStream x(logger.streambuf(Logger::LEVEL_WARN));                        x.imbue("C") << __SHORT_FILE__ << ':' << __LINE__ << ": " << Logger::Imbue("")

#    define LOGGER_ONOTICE(x)           Logger::OStream x(logger.streambuf(Logger::LEVEL_NOTICE));                      x.imbue("")
#    define LOGGER_OINFO(x)             Logger::OStream x(logger.streambuf(Logger::LEVEL_INFO));                        x.imbue("")
#    define LOGGER_ODEBUG(x)            Logger::OStream x(logger.streambuf(Logger::LEVEL_DEBUG));                       x.imbue("")
#endif

///////////////////////////////////////////////////////////////////////
//
// LIKELY
// UNLIKELY
//

// see include/linux/compiler.h in the Linux kernel
#if !defined(likely) && !defined(unlikely)
#  if !defined(__GNUC__) || (__GNUC__ == 2 && __GNUC_MINOR__ < 96)
#    define __builtin_expect(x, expected_value) (x)
#  endif

#  define LIKELY(x)     __builtin_expect((x), 1)
#  define UNLIKELY(x)   __builtin_expect((x), 0)
#endif

///////////////////////////////////////////////////////////////////////
//
// LOGGER_ASSERT -- ASSERT()'s output to LOGGER
// LOGGER_ASSERT<n> -- append <n> variable(s)
//
// Example:
//  - LOGGER_ASSERT2(n < bufsiz, n, bufsiz);

#if !defined(NDEBUG) && defined(LOGGER_OSTREAM)

#  ifndef __ASSERT_FUNCTION
#    define __ASSERT_FUNCTION __func__
#  endif

#  define LOGGER_ASSERT(x)              while (UNLIKELY(! (x)))         \
                                        {                               \
                                            LOGGER_OFATAL(cfatal)       \
                                                << __ASSERT_FUNCTION    \
                                                << ": Assertion `"      \
                                                << __STRING(x)          \
                                                << "` failed."          \
                                                << std::flush;          \
                                            abort();                    \
                                        }

#  define LOGGER_ASSERT1(x, a)          while (UNLIKELY(! (x)))         \
                                        {                               \
                                            LOGGER_OFATAL(cfatal)       \
                                                << __ASSERT_FUNCTION    \
                                                << ": Assertion `"      \
                                                << __STRING(x)          \
                                                << "` failed.\n"        \
                                                << __STRING(a)          \
                                                << '='                  \
                                                << a                    \
                                                << '.'                  \
                                                << std::flush;          \
                                            abort();                    \
                                        }

#  define LOGGER_ASSERT2(x, a, b)       while (UNLIKELY(! (x)))         \
                                        {                               \
                                            LOGGER_OFATAL(cfatal)       \
                                                << __ASSERT_FUNCTION    \
                                                << ": Assertion `"      \
                                                << __STRING(x)          \
                                                << "` failed.\n"        \
                                                << __STRING(a)          \
                                                << '='                  \
                                                << a                    \
                                                << ". "                 \
                                                << __STRING(b)          \
                                                << '='                  \
                                                << b                    \
                                                << '.'                  \
                                                << std::flush;          \
                                            abort();                    \
                                        }

#  define LOGGER_ASSERT3(x, a, b, c)    while (UNLIKELY(! (x)))         \
                                        {                               \
                                            LOGGER_OFATAL(cfatal)       \
                                                << __ASSERT_FUNCTION    \
                                                << ": Assertion `"      \
                                                << __STRING(x)          \
                                                << "` failed.\n"        \
                                                << __STRING(a)          \
                                                << '='                  \
                                                << a                    \
                                                << ". "                 \
                                                << __STRING(b)          \
                                                << '='                  \
                                                << b                    \
                                                << ". "                 \
                                                << __STRING(c)          \
                                                << '='                  \
                                                << c                    \
                                                << '.'                  \
                                                << std::flush;          \
                                            abort();                    \
                                        }

#  define LOGGER_ASSERT4(x, a, b, c, d) while (UNLIKELY(! (x)))         \
                                        {                               \
                                            LOGGER_OFATAL(cfatal)       \
                                                << __ASSERT_FUNCTION    \
                                                << ": Assertion `"      \
                                                << __STRING(x)          \
                                                << "` failed.\n"        \
                                                << __STRING(a)          \
                                                << '='                  \
                                                << a                    \
                                                << ". "                 \
                                                << __STRING(b)          \
                                                << '='                  \
                                                << b                    \
                                                << ". "                 \
                                                << __STRING(c)          \
                                                << '='                  \
                                                << c                    \
                                                << ". "                 \
                                                << __STRING(d)          \
                                                << '='                  \
                                                << d                    \
                                                << '.'                  \
                                                << std::flush;          \
                                            abort();                    \
                                        }

#  define LOGGER_ASSERT5(x, a, b, c, d, e)  while (UNLIKELY(! (x)))         \
                                            {                               \
                                                LOGGER_OFATAL(cfatal)       \
                                                    << __ASSERT_FUNCTION    \
                                                    << ": Assertion `"      \
                                                    << __STRING(x)          \
                                                    << "` failed.\n"        \
                                                    << __STRING(a)          \
                                                    << '='                  \
                                                    << a                    \
                                                    << ". "                 \
                                                    << __STRING(b)          \
                                                    << '='                  \
                                                    << b                    \
                                                    << ". "                 \
                                                    << __STRING(c)          \
                                                    << '='                  \
                                                    << c                    \
                                                    << ". "                 \
                                                    << __STRING(d)          \
                                                    << '='                  \
                                                    << d                    \
                                                    << ". "                 \
                                                    << __STRING(e)          \
                                                    << '='                  \
                                                    << e                    \
                                                    << '.'                  \
                                                    << std::flush;          \
                                                abort();                    \
                                            }

#else

#  define LOGGER_ASSERT(x)                  assert(x)
#  define LOGGER_ASSERT1(x, a)              assert(x)
#  define LOGGER_ASSERT2(x, a, b)           assert(x)
#  define LOGGER_ASSERT3(x, a, b, c)        assert(x)
#  define LOGGER_ASSERT4(x, a, b, c, d)     assert(x)
#  define LOGGER_ASSERT5(x, a, b, c, d, e)  assert(x)

#endif

///////////////////////////////////////////////////////////////////////
//
// UNREACHABLE
//

#if !defined(__GNUC__) || (__GNUC__ < 4) || (__GNC__ == 4 && __GNUC_MINOR < 5)
#   define __builtin_unreachable()
# endif

#if !defined(NDEBUG) && defined(LOGGER_OSTREAM)
#  define UNREACHABLE()     LOGGER_FATAL("%s: Unreachable!", __ASSERT_FUNCTION), __builtin_unreachable()
#else
#  define UNREACHABLE()     assert(!"Unreachable!"), __builtin_unreachable()
#endif

///////////////////////////////////////////////////////////////////////
//
// MagnitudeBinary -- prints number followed by 'K, 'M', 'G', ... (powers of 1024)
// MagnitudeDecimal -- prints number followed by 'k', 'm', 'g', ... (powers of 1000)
//
// Examples:
//  1- LOGGER_ODEBUG(cdbg) << MagnitudeBinary(osent) << "iB" << std::flush;
//     prints "100KiB"
//  2- LOGGER_ODEBUG(cdbg) << MagnitudeDecimal(osent) << "B" << std::flush;
//     prints "102KB"

#ifdef LOGGER_OSTREAM

template <unsigned DIVISOR>
class MagnitudeTmpl
{
public:

    explicit MagnitudeTmpl(float x)
        : _x(x)
    {}

    friend std::ostream& operator<<(std::ostream& out, const MagnitudeTmpl& m)
    {
        const char* tag = UNITS;
        float x = m._x;
        while (x >= DIVISOR && tag[1] != '\0')
        {
            x /= DIVISOR;
            ++tag;
        }

        out << x;
        if (*tag)
            out << *tag;

        return out;
    }

private:

    static const char UNITS[];

    float _x;
};

typedef MagnitudeTmpl<1024> MagnitudeBinary;
template <>
/*static*/ const char MagnitudeTmpl<1024>::UNITS[] = "\0KMGTPEZY";

typedef MagnitudeTmpl<1000> MagnitudeDecimal;
template <>
/*static*/ const char MagnitudeTmpl<1000>::UNITS[] = "\0kmgtpezy";

#endif // LOGGER_OSTREAM

///////////////////////////////////////////////////////////////////////
//
// PrintFormat -- printf style formatting for C++ streams
// PrintF -- printf style printing for C++ streams
//
// Examples:
//  1- LOGGER_ODEBUG(cdbg) << PrintFormat("%.1f") << osent << "iB" << std::flush;
//     prints "102400.0"
//  2- LOGGER_ODEBUG(cdbg) << PrintF("%.1f", osent) << std::flush;
//     prints "102400.0"

#ifdef LOGGER_OSTREAM

// see http://www.boost.org/doc/libs/1_57_0/libs/format/doc/format.html
class PrintFormat
{
public:

    PrintFormat(const char* fmt)
        : _fmt(fmt)
    {}

    friend std::ostream& operator<<(std::ostream& out, const PrintFormat& fmt)
    {
        const char* f = fmt._fmt;
        f++; // skip over %

        // flag

#if 0
        // FIXME: reset the locale
        switch (*f)
        {
        case '\'':
            out.imbue(std::locale(""));
            ++f;
            break;
        default:
            out.imbue(std::locale("C"));
            break;
        }
#endif

        switch (*f)
        {
        case '0':
            out << std::setfill('0') << std::internal;
            ++f;
            break;
        case '-':
            out << std::left;
            ++f;
            break;
        case '+':
            out << std::showpos;
            ++f;
            break;
        case '#':
            out << std::showbase << std::showpoint;
            ++f;
            break;
        }

        // width

        unsigned width;
        if (sscanf(f, "%u", &width) == 1)
            out << std::setw(width);

        // precision

        const char* dot = strchr(f, '.');
        if (dot)
        {
            f = dot + 1;
            unsigned precision;
            if (sscanf(f, "%u", &precision) == 1)
                out << std::setprecision(precision);
        }

        // type

        f = &f[strlen(f) - 1];
        switch (*f)
        {
        case 'X':
            out << std::uppercase;
            // FALLTHROUGH
        case 'x':
            out << std::hex;
            break;
        case 'o':
            out << std::oct;
            break;
        case 'E':
            out << std::uppercase;
            // FALLTHROUGH
        case 'e':
            out << std::scientific;
            break;
        case 'f':
            out << std::fixed;
            break;
        case 'G':
            out << std::uppercase;
            // FALLTHROUGH
        case 'g':
            out.unsetf(std::ios_base::floatfield);
            break;
        case 'd':
        case 'i':
        case 'u':
            out << std::dec;
            break;
        case 's':
            // TODO:
            break;
        }

        return out;
    }

private:

    const char* _fmt;
};

class PrintF
{
public:

    PrintF(const char* fmt, ...)
        __printflike(2, 3)
    {
        va_list ap;
        va_start(ap, fmt);
        vasprintf(&_s, fmt, ap);
        va_end(ap);
    }

    ~PrintF()
    {
        free(_s);
    }

    friend std::ostream& operator<<(std::ostream& out, const PrintF& pf)
    {
        return out << pf._s;
    }

private:

    char* _s;
};

#endif // LOGGER_OSTREAM

///////////////////////////////////////////////////////////////////////
//
// num_put
//
// std::num_put doesn't add grouping separator for the padding
// ie. out.imbue(std::locale(""));
//     out << setfill('0') << setw(6) << 123;
// prints "000123"
//
// whereas out.imbue(std::locale(""));
//         out.width(6);
//         num_put<char>().put(out, out, '0', 123);
// prints "000,123"

#ifdef LOGGER_OSTREAM

template<typename CharT, typename OutputIterator = std::ostreambuf_iterator<CharT> >
class num_put
    : public std::num_put<CharT, OutputIterator>
{
public:

    typedef typename std::num_put<CharT, OutputIterator>::char_type char_type;
    typedef typename std::num_put<CharT, OutputIterator>::iter_type iter_type;

    explicit num_put(size_t refs = 0)
        : std::num_put<CharT, OutputIterator>(refs)
    {}

protected:

    virtual iter_type do_put(iter_type out, std::ios_base& str, char_type fill, long val) const
    {
        return do_put(out, str, fill, "%ld", val);
    }

    virtual iter_type do_put(iter_type out, std::ios_base& str, char_type fill, unsigned long val) const
    {
        return do_put(out, str, fill, "%lu", val);
    }

    // TODO:
    //virtual iter_type do_put(iter_type out, ios_base& str, char_type fill, double val) const;
    //virtual iter_type do_put(iter_type out, ios_base& str, char_type fill, long double val) const;

private:

    template <typename T>
    iter_type do_put(iter_type out, std::ios_base& str, char_type fill, const char* fmt, T val) const
    {
        if (fill != (char_type)'0')
        {
            // this only makes sense if the fill char is 0
            return std::num_put<CharT, OutputIterator>::do_put(out, str, fill, val);
        }

        const unsigned width = str.width();

        const std::string grouping = std::use_facet< std::numpunct<CharT> >(str.getloc()).grouping();
        unsigned group1 = 0;
        unsigned group2 = 0;
        if (grouping.empty())
        {
            // no grouping
            group1 = group2 = 0;
        }
        else
        {
            group1 = grouping[0];
            group2 = group1;
            if (grouping.length() >= 1)
                group2 = grouping[1];
        }
        if (group1 == 0 || group1 >= width)
        {
            // no grouping
            // might as well use base clase
            return std::num_put<CharT, OutputIterator>::do_put(out, str, fill, val);
        }

        int m; // length of the output (with separator)
        m = width + sizeof(CharT); // 6 char + right most separator
        if (width - group1 > group2)
            m += (width - group1) / group2 * sizeof(CharT);

        size_t len = 5 * sizeof(T) * sizeof(CharT);
        if (len <= width)
            len = width + 1;
        CharT* tmp = reinterpret_cast<CharT*>(alloca(len));
        const int n = snprintf(tmp, len, fmt, val);
        LOGGER_ASSERT1((size_t)n <= len, n);

        if ((unsigned)n < width)
        {
            // pad with fill
            std::copy_backward(&tmp[0], &tmp[n+1], &tmp[width+1]);
            std::fill(&tmp[0], &tmp[width-n], fill);
        }

        const CharT sep = std::use_facet< std::numpunct<CharT> >(str.getloc()).thousands_sep();
        for (unsigned i = 0; i < width; ++i)
        {
            if (i > 0)
            {
                const unsigned j = width - i;
                if (j > group1 && (j - group1) % group2 == 0)
                    out = sep; // write sep to out
                else if (j == group1)
                    out = sep;
            }
            out = tmp[i];
        }

        str.width(0); // reset width like std::num_put

        return out;
    }
};

#endif // LOGGER_OSTREAM

#endif
