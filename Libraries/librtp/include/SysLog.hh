
#ifndef _SYSLOG_H_
#define _SYSLOG_H_

#include <alloca.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef __APPLE__
#  include <regex.h>
#else
#  include <pcre.h>
#endif

#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>

#include "Logger.h"

///////////////////////////////////////////////////////////////////////

namespace
{

class _SyslogRegEx
{
protected:

    _SyslogRegEx(const char* regex)
    {
#ifdef __APPLE__
        int errcode =  regcomp(&_regex, regex, REG_EXTENDED | REG_ENHANCED);
        if (errcode != 0)
        {
            char errbuf[128];
            regerror(errcode, &_regex, errbuf, sizeof(errbuf));
            LOGGER_FATAL("%s: %s", regex, errbuf);
            abort();
        }
#else
        const char* err;
        int offset;
        _re = pcre_compile(regex, 0, &err, &offset, NULL);
        if (_re == NULL)
        {
            LOGGER_FATAL("%s: %s @ %d", regex, err, offset);
            abort();
        }

        _extra = pcre_study(_re, PCRE_STUDY_JIT_COMPILE, &err);
        if (_extra == NULL)
            LOGGER_WARN("%s: %s", regex, err);
#endif
    }

    virtual ~_SyslogRegEx()
    {
#ifdef __APPLE__
        regfree(&_regex);
#else
        pcre_free_study(_extra);
        pcre_free(_re);
#endif
    }

    int exec(const char* buffer, size_t len,
             int* ovector, int ovecsize)
    {
#ifdef __APPLE__
        size_t nmatch = (ovecsize + 1) / 2;
        regmatch_t* match = (regmatch_t*)alloca(nmatch);
        int errcode = regexec(&_regex, buffer, nmatch, match, 0);
        if (errcode == REG_NOMATCH)
            return 0;
        if (errcode != 0)
        {
            char errbuf[128];
            (void) regerror(errcode, &_regex, errbuf, sizeof(errbuf));
            LOGGER_ERROR("%s: %s", buffer, errbuf);
            return -1;
        }

        for (int i = 0; i < nmatch; ++i)
        {
            ovector[i*2] = match[i].rm_so;
            ovector[i*2+1] = match[i].rm_eo;
        }

        return nmatch;
#else
#  ifndef NDEBUG
        int capturecount;
        if (pcre_fullinfo(_re, _extra, PCRE_INFO_CAPTURECOUNT, &capturecount) < 0)
            LOGGER_WARN("pcre_fullinfo(PCRE_INFO_CAPTURECOUNT)");
        else
            LOGGER_ASSERT2((1 + capturecount) * 2 * 3/2 <= ovecsize, capturecount, ovecsize);
#  endif
        int m = pcre_exec(_re,
                          _extra,
                          buffer, len,
                          0,
                          0,
                          ovector,
                          ovecsize);
        if (m == PCRE_ERROR_NOMATCH)
            return 0;
        if (m < 0)
        {
            LOGGER_ERROR("%s: %d", buffer, m);
            return -1;
        }
        return m;
#endif
    }

private:

#ifdef __APPLE__
    regex_t _regex;
#else
    pcre* _re;
    pcre_extra* _extra;
#endif
};

};

///////////////////////////////////////////////////////////////////////
//
// SyslogSocket
//
///////////////////////////////////////////////////////////////////////

class SyslogSocket
    : private _SyslogRegEx
{
public:

    SyslogSocket()
        : _SyslogRegEx("^<([0-9]{1,3})>" // 1-PRI
                       "((?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (?:[0-9][0-9]| [0-9]) [0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}) "  // 2-TIMESTAMP
                       "((?:[a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])(?:\\.(?:[a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9]))*) " // 3-HOSTNAME
                       "(.*)$") // 4-MSG
        , _fd(-1)
    {}

    virtual ~SyslogSocket()
    {
        (void) close();
    }

    operator int () const
    {
        return _fd;
    }

    int open(const char* path)
    {
        int n = close();
        if (n != 0)
            return n;

        _fd = socket(AF_LOCAL, SOCK_DGRAM, 0);
        if (_fd == -1)
        {
            LOGGER_PERROR("socket(AF_LOCAL, SOCK_DGRAM, 0)");
            return -1;
        }

        memset(&_addr, 0, sizeof(_addr));
        _addr.sun_family = AF_LOCAL;
        strncpy(_addr.sun_path, path, sizeof(_addr.sun_path) - 1);
        if (bind(_fd, (struct sockaddr*)&_addr, sizeof(_addr)) == -1)
        {
            LOGGER_PERROR("bind(%s)", path);
            (void) ::close(_fd);
            _fd = -1;
            return -1;
        }

        return 0;
    }

    // delete path, if it already exists and is a socket, before calling open()
    int creat(const char* path)
    {
        struct stat buf;
        if (stat(path, &buf) == -1)
        {
            if (errno != ENOENT)
            {
                LOGGER_PERROR("stat(%s) %d", path, errno);
                return -1;
            }
        }
        else if (S_ISSOCK(buf.st_mode))
        {
            if (unlink(path) == -1)
            {
                LOGGER_PERROR("unlink(%s)", path);
                return -1;
            }
        }

        return open(path);
    }

    int close()
    {
        if (_fd == -1)
            return 0;

        if (::close(_fd) == -1)
        {
            LOGGER_PERROR("close");
            return -1;
        }

        if (unlink(_addr.sun_path) == -1)
        {
            LOGGER_PERROR("unlink(%s)", _addr.sun_path);
            return -1;
        }

        _fd = -1;
        return 0;
    }

    ssize_t relay(struct timeval* timeout = NULL)
    {
        if (timeout != NULL)
        {
            fd_set rfds;
            FD_ZERO(&rfds);
            FD_SET(_fd, &rfds);
            switch (::select(_fd+1, &rfds, NULL, NULL, timeout))
            {
            case -1:
                LOGGER_PERROR("select");
                return -1;
            case 0:
                errno = EAGAIN;
                return 0;
            case 1:
                break;
            default:
                UNREACHABLE();
            }
        }

        char buffer[1024];
        const ssize_t n = recv(_fd, buffer, sizeof(buffer), timeout != NULL ? MSG_DONTWAIT : 0);
        if (n == -1)
        {
            if (errno == EAGAIN)
                return 0;
            LOGGER_PERROR("recv");
            return -1;
        }

        if (n >= 1024)
            buffer[1023] = '\0';
        else if (buffer[n] != '\0')
            buffer[n] = '\0';

        onSyslogMessage(buffer, (size_t)n);

        return n;
    }

protected:

    virtual void onSyslogMessage(char* buffer, size_t len)
    {
        static const int capturecount = 4;
        const int ovecsize = (1 + capturecount) * 2 * 3/2;  // capturecount = 4
                                                            // goes in pairs -> * 2
                                                            // top 1/3 reserved for pcre -> * 3/2
        int ovector[ovecsize];

        int n = exec(buffer, len, ovector, ovecsize);
        if (n == -1)
            return;
        if (n == 0)
        {
            LOGGER_WARN("Ignoring syslog datagram: %s", buffer);
            return;
        }
        LOGGER_ASSERT1(n >= 1+capturecount, n);

        const int pri = atoi(&buffer[ovector[1*2]]);
        const int facility = pri & LOG_FACMASK; // don't use LOG_FAC(p) to keep facility comparable to LOG_* macros
        const int priority = LOG_PRI(pri);

        const char* timestamp = &buffer[ovector[2*2]];
        buffer[ovector[2*2+1]] = '\0';

        const char* hostname = &buffer[ovector[3*2]];
        buffer[ovector[3*2+1]] = '\0';

        const char* msg = &buffer[ovector[4*2]];
        LOGGER_ASSERT1(buffer[ovector[4*2+1]] == '\0', buffer[ovector[4*2+1]]);

        onSyslogMessage(facility, priority, timestamp, hostname, msg);
    }

    virtual void onSyslogMessage(int facility,
                                 int priority,
                                 const char* timestamp,
                                 const char* hostname,
                                 const char* msg)
    {
        logger.log(priority, "<%s>%s %s", facilityname(facility), timestamp, msg);
    }

    static const char* facilityname(int facility)
    {
        switch (facility)
        {
        case LOG_KERN:      return "kern";
        case LOG_USER:      return "user";
        case LOG_DAEMON:    return "daemon";
        case LOG_AUTH:      return "auth";
        case LOG_SYSLOG:    return "syslog";
        case LOG_LPR:       return "lpr";
        case LOG_NEWS:      return "news";
        case LOG_UUCP:      return "uucp";
        case LOG_CRON:      return "cron";
        case LOG_AUTHPRIV:  return "authpriv";
        case LOG_FTP:       return "ftp";
        case LOG_LOCAL0:    return "local0";
        case LOG_LOCAL1:    return "local1";
        case LOG_LOCAL2:    return "local2";
        case LOG_LOCAL3:    return "local3";
        case LOG_LOCAL4:    return "local4";
        case LOG_LOCAL5:    return "local5";
        case LOG_LOCAL6:    return "local6";
        case LOG_LOCAL7:    return "local7";
        default:
            {
                static char facilitybuf[8];
                (void) snprintf(facilitybuf, sizeof(facilitybuf), "%d", facility >> 3);
                return facilitybuf;
            }
        }
    }

protected:

    int _fd;
    struct sockaddr_un _addr;
};

///////////////////////////////////////////////////////////////////////
//
// Sysklog
//
///////////////////////////////////////////////////////////////////////

#ifdef __linux__

#  include <sys/klog.h>
#  define SYSLOG_ACTION_READ_ALL 3
#  define SYSLOG_ACTION_SIZE_BUFFER 10

class Sysklog
    : private _SyslogRegEx
{
public:

    Sysklog()
        : _SyslogRegEx("^<([0-9]{1,3})>" // 1-PRI
                       "\\[\\s*(\\d+\\.\\d+)\\] " // 2-TIMESTAMP
                       "(.*)") // 3-MSG
    {}

    ssize_t read_all()
    {
        int klogbufsiz = klogctl(SYSLOG_ACTION_SIZE_BUFFER, NULL, 0);
        if (klogbufsiz == -1)
        {
            LOGGER_PERROR("klogctl(SYSLOG_ACTION_SIZE_BUFFER)");
            return -1;
        }

        char* kbuf = (char*)malloc(klogbufsiz);
        if (! kbuf)
        {
            errno = ENOMEM;
            LOGGER_PERROR("malloc(%d)", klogbufsiz);
            return -1;
        }

        const int n = klogctl(SYSLOG_ACTION_READ_ALL, kbuf, klogbufsiz);
        if (n == -1)
        {
            LOGGER_PERROR("klogctl(SYSLOG_ACTION_READ_ALL)");
            free(kbuf);
            return -1;
        }

        static const int capturecount = 3;
        int ovecsize = (1 + capturecount) * 2 * 3 / 2;
        int* ovector = (int*)alloca(ovecsize * sizeof(int));

        char* buf = kbuf;
        int bufsiz = n;
        while (bufsiz > 0)
        {
            int m = exec(buf, bufsiz,
                         ovector, ovecsize);
            if (m < 0)
                break;

            LOGGER_ASSERT1(m >= 1+capturecount, m);

            const int pri = atoi(&buf[ovector[1*2]]);
            // Note: facility should always be LOG_KERN
            //       but "udevd[174]: starting version 175" comes with a facility of LOG_DAEMON
            const int priority = LOG_PRI(pri);

            const char* timestamp = &buf[ovector[2*2]];
            buf[ovector[2*2+1]] = '\0';

            const char* msg = &buf[ovector[3*2]];
            buf[ovector[3*2+1]] = '\0';

            onSysklogMessage(priority, timestamp, msg);

            bufsiz -= ovector[1] + 1;
            buf += ovector[1] + 1;
        }

        free(kbuf);

        return n;
    }

protected:

    virtual void onSysklogMessage(int priority,
                                  const char* timestamp,
                                  const char* msg)
    {
        logger.log(priority, "<kern>%s %s", timestamp, msg);
    }
};

#endif

#endif
