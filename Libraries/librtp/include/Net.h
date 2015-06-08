
#ifndef _INET_H_
#define _INET_H_

/* C99 requires that stdint.h only exposes UINT16_MAX if this is defined: */
#ifndef __STDC_LIMIT_MACROS
#  define __STDC_LIMIT_MACROS
#endif

#ifndef _BSD_SOURCE
#  define _BSD_SOURCE
#endif

#include <alloca.h>
#include <errno.h>
#include <ifaddrs.h>
#include <limits.h>
#include <netdb.h>
#include <signal.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <arpa/inet.h>

#include <net/ethernet.h>
#include <net/if.h>

#include <netinet/in.h>
#include <netinet/ip.h>

#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>

#ifdef __linux__
#  include <endian.h>

#  include <asm/byteorder.h>
#  include <asm/types.h>

#  include <linux/errqueue.h>
#  include <linux/net_tstamp.h>
#  include <linux/pkt_sched.h>
#  include <linux/sockios.h>

    struct scm_timestamping {
        struct timespec systime;
        struct timespec hwtimetrans;
        struct timespec hwtimeraw;
    };

// it's just too hard to include <linux/if.h>!
#  define IFF_LOWER_UP    0x10000         /* driver signals L1 up         */

#elif defined(__APPLE__)
#  include <libkern/OSByteOrder.h>

#  include <machine/endian.h>

#  include <mach/clock.h>
#  include <mach/mach.h>
#  include <mach/mach_time.h>

#  include <sys/sysctl.h>
#  undef isset
#  undef roundup

#  define HAVE_SOCKADDR_SA_LEN

#  define ETH_DATA_LEN  1500
#  define MSG_MORE      0x8000
#  define MSG_NOSIGNAL  0x4000

#  define TC_PRIO_BESTEFFORT        0
#  define TC_PRIO_FILLER            1
#  define TC_PRIO_BULK              2
#  define TC_PRIO_INTERACTIVE_BULK  4
#  define TC_PRIO_INTERACTIVE       6
#  define TC_PRIO_CONTROL           7

#  define ICMP_DEST_UNREACH     ICMP_UNREACH
#  define ICMP_PORT_UNREACH     ICMP_UNREACH_PORT
#  define ICMP_TIME_EXCEEDED    ICMP_TIMXCEED
#endif

#ifdef EAI_ADDRFAMILY
#  define HAVE_GETADDRINFO 1
#  define HAVE_GETNAMEINFO 1
#elif defined(HOST_NOT_FOUND)
#  define HAVE_GETHOSTBYNAME 1
#  define HAVE_GETHOSTBYADDR 1
#  define HAVE_GETSERVBYPORT 1
#endif

#define calloca(n, T) reinterpret_cast<T*>(memset(alloca((n) * sizeof(T)), 0, (n) * sizeof(T)))
#define memdupa(src, n, T) reinterpret_cast<T*>(memcpy(alloca((n) * sizeof(T)), src, (n) * sizeof(T)))

#define BITMASK_ISSET(x, m)     (((x) & (m)))
#define BITMASK_ARESET(x, m)    (((x) & (m)) == (m))
#define BITMASK_ANYSET(x, m)    (((x) & (m)) != 0)

#define BITMASK_SET(x, m)       ((x) |= (m))
#define BITMASK_CLEAR(x, m)     ((x) &= (~(m)))
#define BITMASK_MASK(x, m)      ((x) &= (m))
#define BITMASK_FLIP(x, m)      ((x) ^= (m))

#include "Thread.h"
#include "TimeOperators.h"

///////////////////////////////////////////////////////////////////////

#ifndef htonll
static inline uint64_t htonll(uint64_t hostlonglong)
{
#  ifdef __linux__
    return htobe64(hostlonglong);
#  elif defined(__APPLE__)
    return OSSwapHostToBigInt64(hostlonglong);
#  else
#    error "platform not supported"
#  endif
}
#endif

#ifndef ntohll
static inline uint64_t ntohll(uint64_t netlonglong)
{
#  ifdef __linux__
    return be64toh(netlonglong);
#  elif defined(__APPLE__)
    return OSSwapBigToHostInt64(netlonglong);
#  else
#    error "platform not supported"
#  endif
}
#endif

///////////////////////////////////////////////////////////////////////

#ifdef LOGGER_OSTREAM

inline std::ostream&
operator<<(std::ostream& out, const struct in_addr& addr)
{
    if (! out)
        return out;
    char s[INET_ADDRSTRLEN];
    if (inet_ntop(AF_INET, &addr, s, sizeof(s)) != NULL)
        out << s;
    return out;
}

inline std::ostream&
operator<<(std::ostream& out, const struct sockaddr_in& addr)
{
    return out << addr.sin_addr << ':' << ntohs(addr.sin_port);
}

#endif // LOGGER_OSTREAM

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                              SOCKET                               //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class Socket
{
public:

    ///////////////////////////////////////////////////////////////////

    class FDSet
    {
    public:

        FDSet()
        {
            FD_ZERO(&_set);
            _nfds = 0;
        }

        operator fd_set* ()
        {
            return &_set;
        }

        int nfds() const
        {
            return _nfds;
        }

        void set(const Socket& fd)
        {
            set(fd._sockfd);
        }

        void set(int fd)
        {
            if (fd == -1)
                return;
            LOGGER_ASSERT1(0 <= fd && fd < FD_SETSIZE, fd);
            FD_SET(fd, &_set);
            if (fd >= _nfds)
                _nfds = fd + 1;
        }

        int isset(const Socket& fd) const
        {
            return isset(fd._sockfd);
        }

        int isset(int fd) const
        {
            return fd != -1 && FD_ISSET(fd, &_set);
        }

        void clr(const Socket& fd)
        {
            clr(fd._sockfd);
        }

        void clr(int fd)
        {
            if (fd != -1)
                FD_CLR(fd, &_set);
        }

    private:

        fd_set _set;
        int _nfds;
    };

    static int select(FDSet* readfds,
                      FDSet* writefds,
                      struct timeval* timeout = NULL);

    static int select(FDSet* readfds,
                      FDSet* writefds,
                      const struct timeval* timeout)
    {
        if (! timeout)
            return select(readfds, writefds);

        struct timeval timeo = *timeout;
        return select(readfds, writefds, &timeo);
    }

    ///////////////////////////////////////////////////////////////////

protected:

    Socket()
        : _sockfd(-1)
    {}

    Socket(int sockfd)
        : _sockfd(sockfd)
    {}

public:

    virtual ~Socket()
    {
        if (_sockfd > STDERR_FILENO)
            (void) ::close(_sockfd);
    }

    operator bool () const
    {
        return _sockfd != -1;
    }

    bool fd_cloexec() const
    {
        return f_getfl(FD_CLOEXEC);
    }

    int fd_cloxec(bool set)
    {
        return f_setfl(FD_CLOEXEC, set);
    }

    bool o_nonblock() const
    {
        return f_getfl(O_NONBLOCK);
    }

    int o_nonblock(bool set)
    {
        return f_setfl(O_NONBLOCK, set);
    }

    int wait_for_input(struct timeval* timeout = NULL)
    {
        FDSet readfds;
        readfds.set(*this);
        return select(&readfds, NULL, timeout);
    }

    int wait_for_input(const struct timeval* timeout)
    {
        FDSet readfds;
        readfds.set(*this);
        return select(&readfds, NULL, timeout);
    }

    int wait_for_output(struct timeval* timeout = NULL)
    {
        FDSet writefds;
        writefds.set(*this);
        return select(NULL, &writefds, timeout);
    }

    virtual int close()
    {
        if (_sockfd == -1)
            return 0;

        if (_sockfd > STDERR_FILENO)
        {
            if (shutdown(_sockfd, SHUT_RDWR) == -1)
            {
                if (errno != ENOTCONN)
                    LOGGER_PWARN("shutdown(SHUT_RDWR)");
            }

            if (::close(_sockfd) == -1)
            {
                LOGGER_PERROR("close");
                return -1;
            }
        }

        _sockfd = -1;
        return 0;
    }

#if 0
    // should be the interface

    virtual ssize_t read(void* buffer, size_t len,
                         struct timeval* timeout = NULL)
    {
        struct iovec iov;
        iov.iov_base = buffer;
        iov.iov_len = len;
        return read(&iov, 1, timeout);
    }
    virtual ssize_t read(const struct iovec* iov, unsigned iovcnt,
                         struct timeval* timeout = NULL)
    {
        for (;;)
        {
            if (timeout)
            {
                switch (wait_for_input(timeout))
                {
                case -1:    return -1;
                case 0:     return -1;
                case 1:     break;
                default:    UNREACHABLE();
                }
            }

            ssize_t n = ::readv(_sockfd, iov, iovcnt);
            if (n == -1)
            {
#ifndef NDEBUG
                // running inside the debugger causes EINTR
                if (errno == EINTR)
                    continue;
#endif
                if (errno == EWOULDBLOCK)
                    continue;
                LOGGER_ERROR("read: %s", strerror(errno));
                return -1;
            }
            if (n == 0)
            {
                if (timeout && (timeout->tv_sec > 0 || timeout->tv_usec > 0))
                    continue;
            }

            return n;
        }
        UNREACHABLE();
    }

    virtual ssize_t write(const void* buffer, size_t len)
    {
        struct iovec iovec;
        iovec.iov_base = const_cast<void*>(buffer);
        iovec.iov_len = len;
        return write(&iovec, 1);
    }
    virtual ssize_t write(const struct iovec* iov, unsigned iovcnt)
    {
        ssize_t n = ::writev(_sockfd, iov, iovcnt);
        if (n == -1)
            LOGGER_ERROR("write: %s", strerror(errno));
        return n;
    }

#endif

protected:

    bool f_getfl(int flag) const
    {
        int flags = fcntl(_sockfd, F_GETFL);
        if (flags == -1)
        {
            LOGGER_PERROR("fcntl(F_GETLF)");
            return false;
        }
        return (flags & flag) != 0;
    }

    int f_setfl(int flag, bool set)
    {
        int flags = fcntl(_sockfd, F_GETFL);
        if (flags == -1)
        {
            LOGGER_PERROR("fcntl(F_GETFL)");
            return -1;
        }

        if ((flags & flag) != (set ? flag : 0))
        {
            flags ^= flag;
            if (fcntl(_sockfd, F_SETFL, flags) == -1)
            {
                LOGGER_PERROR("fcntl(F_SETFL)");
                return -1;
            }
        }

        return 0;
    }

private:

    Socket(const Socket&); // not implemented
    Socket& operator=(const Socket& rhs); // not implemented

protected:

    int _sockfd;
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                               INet                                //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class INet
    : public Socket
{
public:

    ///////////////////////////////////////////////////////////////////
    // INet::Addr
    ///////////////////////////////////////////////////////////////////

    // wrapper for struct in_addr
    class Addr
    {
    public:

        static Addr aton(const char* cp)
        {
            struct in_addr addr;
            if (inet_aton(cp, &addr) == 0)
                return Addr();
            return Addr(addr);
        }

    public:

        Addr()
        {
            _addr.s_addr = INADDR_NONE;
            _ascii[0] = '\0';
            _name = NULL;
        }

        Addr(const Addr& rhs)
        {
            memset(this, 0, sizeof(*this));
            this->operator=(&rhs._addr);
        }

        Addr(const struct in_addr& addr)
        {
            memset(this, 0, sizeof(*this));
            this->operator=(&addr);
        }

        Addr(const struct in_addr* addr)
        {
            memset(this, 0, sizeof(*this));
            this->operator=(addr);
        }

        Addr(in_addr_t addr)
        {
            memset(this, 0, sizeof(*this));
            this->operator=(addr);
        }

        Addr& operator=(const struct in_addr& addr)
        {
            return this->operator=(&addr);
        }

        Addr& operator=(const struct in_addr* addr)
        {
            if (addr)
                return this->operator=(addr->s_addr);
            else
                return this->operator=(INADDR_NONE);
        }

        Addr& operator=(in_addr_t addr)
        {
            if (_addr.s_addr != addr)
            {
                _addr.s_addr = addr;
                _ascii[0] = '\0';
                if (_name)
                {
                    free(_name);
                    _name = NULL;
                }
            }
            return *this;
        }

        ~Addr()
        {
            if (_name)
                free(_name);
        }

        operator bool () const
        {
            return _addr.s_addr != INADDR_NONE;
        }

        operator const struct in_addr& () const
        {
            return _addr;
        }

        operator in_addr_t () const
        {
            return _addr.s_addr;
        }

        const char* ascii() const
        {
            if (_ascii[0] == '\0')
            {
                if (inet_ntop(AF_INET, &_addr, _ascii, sizeof(_ascii)) == NULL)
                {
                    LOGGER_PWARN("inet_ntop");
                    _ascii[0] = '\0';
                }
            }
            return _ascii;
        }

        const char* name() const
        {
            if (_name == NULL)
            {
#if defined(HAVE_GETHOSTBYADDR)
                struct hostent* hp = gethostbyaddr(&_addr, sizeof(_addr), AF_INET);
                if (hp == NULL)
                {
                    const char* ascii = this->ascii();
                    LOGGER_ERROR("gethostbyaddr(%s): %s", ascii, hstrerror(h_errno));
                    return ascii;
                }
                if (LOGGER_IS_DEBUG())
                {
                    const char* ascii = this->ascii();
                    for (char** alias = hp->h_aliases; *alias; ++alias)
                        LOGGER_DEBUG("gethostbyaddr(%s): %s %s", ascii, hp->h_name, *alias);
                }
                _name = (char*) realloc(_name, strlen(hp->h_name) + 1);
                if (! _name)
                    return "";
                strcpy(_name, hp->h_name);
#elif defined(HAVE_GETNAMEINFO)
                _name = (char*) realloc(_name, NI_MAXHOST);
                if (! _name)
                    return "";
                struct sockaddr_in sa;
                memset(&sa, 0, sizeof(sa));
#  ifdef HAVE_SOCKADDR_SA_LEN
                sa.sin_len = sizeof(struct sockaddr_in);
#  endif
                sa.sin_family = AF_INET;
                sa.sin_addr = _addr;
                const int errcode = getnameinfo(reinterpret_cast<const sockaddr*>(&sa), sizeof(sa), _name, NI_MAXHOST, NULL, 0, NI_NOFQDN);
                if (errcode != 0)
                {
                    const char* ascii = this->ascii();
                    LOGGER_ERROR("getnameinfo(%s): %s", ascii, gai_strerror(errcode));
                    return ascii;
                }
                _name = (char*) realloc(_name, strlen(_name) + 1);
#else
#  error
#endif
            }
            return _name;
        }

        friend bool operator==(const Addr& lhs, const Addr& rhs)
        {
            return lhs._addr.s_addr == rhs._addr.s_addr;
        }

        friend bool operator==(const Addr& lhs, const struct in_addr& rhs)
        {
            return lhs._addr.s_addr == rhs.s_addr;
        }

        friend bool operator==(const Addr& lhs, in_addr_t rhs)
        {
            return lhs._addr.s_addr == rhs;
        }

        friend bool operator!=(const Addr& lhs, const Addr& rhs)
        {
            return lhs._addr.s_addr != rhs._addr.s_addr;
        }

        friend bool operator!=(const Addr& lhs, const struct in_addr& rhs)
        {
            return lhs._addr.s_addr != rhs.s_addr;
        }

        friend bool operator!=(const Addr& lhs, in_addr_t rhs)
        {
            return lhs._addr.s_addr != rhs;
        }

        bool matches(const Addr& addr) const
        {
            return matches(addr._addr);
        }

        bool matches(const struct in_addr& addr) const
        {
            return matches(addr.s_addr);
        }

        bool matches(in_addr_t addr) const
        {
            return (_addr.s_addr & addr) == addr;
        }

        bool is_multicast() const
        {
            return (ntohl(_addr.s_addr) >> 28) == 0xE;
        }

    private:

        struct in_addr _addr;
        mutable char _ascii[INET_ADDRSTRLEN];
        mutable char* _name;
    };

    ///////////////////////////////////////////////////////////////////
    // INet::SockAddr
    ///////////////////////////////////////////////////////////////////

    // wrapper for struct sockaddr_in
    class SockAddr
    {
    public:

        static SockAddr sockname(int sockfd)
        {
            struct sockaddr_in addr;
            socklen_t socklen = sizeof(addr);
            if (::getsockname(sockfd, (struct sockaddr*)&addr, &socklen) == -1)
            {
                LOGGER_PWARN("getsockname");
                return SockAddr();
            }
            return SockAddr(&addr);
        }

        static SockAddr peername(int sockfd)
        {
            struct sockaddr_in addr;
            socklen_t socklen = sizeof(addr);
            if (::getpeername(sockfd, (struct sockaddr*)&addr, &socklen) == -1)
            {
                LOGGER_PWARN("getpeername");
                return SockAddr();
            }
            return SockAddr(&addr);
        }

    public:

        SockAddr()
        {
            memset(this, 0, sizeof(*this));
            this->operator=(reinterpret_cast<const struct sockaddr_in*>(NULL));
        }

        SockAddr(const SockAddr& rhs)
        {
            memcpy(this, &rhs, sizeof(*this));
            if (_name)
                _name = strdup(_name);
            if (_service)
                _service = strdup(_service);
        }

        ~SockAddr()
        {
            if (_name)
                free(_name);
            if (_service)
                free(_service);
        }

        SockAddr(const struct sockaddr_in& addr)
        {
            memset(this, 0, sizeof(*this));
            this->operator=(&addr);
        }

        SockAddr(const struct sockaddr_in* addr)
        {
            memset(this, 0, sizeof(*this));
            this->operator=(addr);
        }

        explicit SockAddr(const struct in_addr& addr, in_port_t port = 0)
        {
            memset(this, 0, sizeof(*this));

            struct sockaddr_in sa;
            memset(&sa, 0, sizeof(sa));
#ifdef HAVE_SOCKADDR_SA_LEN
            sa.sin_len = sizeof(struct sockaddr_in);
#endif
            sa.sin_family = AF_INET;
            sa.sin_addr.s_addr = addr.s_addr;
            sa.sin_port = htons(port);
            this->operator=(sa);
        }

        SockAddr& operator=(const SockAddr& addr)
        {
            if (this != &addr)
            {
                memcpy(this, &addr, sizeof(*this));
                if (_name)
                    _name = strdup(_name);
                if (_service)
                    _service = strdup(_service);
            }
            return *this;
        }

        SockAddr& operator=(const struct sockaddr_in& addr)
        {
            return operator=(&addr);
        }

        SockAddr& operator=(const struct sockaddr_in* addr)
        {
            if (addr)
            {
                if (memcmp(&_addr, addr, sizeof(_addr)) == 0)
                    return *this;

                memcpy(&_addr, addr, sizeof(_addr));
            }
            else
            {
                memset(&_addr, 0, sizeof(_addr));
#ifdef HAVE_SOCKADDR_SA_LEN
                _addr.sin_len = sizeof(struct sockaddr_in);
#endif
#if AF_UNSPEC != 0
                _addr.sin_family = AF_UNSPEC;
#endif
                _addr.sin_addr.s_addr = INADDR_NONE;
            }
            _s_addr = _addr.sin_addr.s_addr;

            _ascii[0] = '\0';
            if (_name)
            {
                free(_name);
                _name = NULL;
            }
            if (_service)
            {
                free(_service);
                _service = NULL;
            }

            return *this;
        }

        void copy(struct sockaddr_in* addr) const
        {
            memcpy(addr, &_addr, sizeof(_addr));
        }

        operator bool () const
        {
            return _addr.sin_addr.s_addr != INADDR_NONE;
        }

        /*const*/ struct sockaddr* addr() const
        {
            // should return const struct sockaddr*, but the C API uses struct sockaddr*
            return (/*const*/ struct sockaddr*) &_addr;
        }

        socklen_t addrlen() const
        {
            return sizeof(_addr);
        }

        operator const sockaddr_in* () const
        {
            return &_addr;
        }

        operator sockaddr_in* ()
        {
            return &_addr;
        }

        const sockaddr_in& operator* () const
        {
            return _addr;
        }

        sockaddr_in& operator* ()
        {
            return _addr;
        }

        const sockaddr_in* operator-> () const
        {
            return &_addr;
        }

        sockaddr_in* operator-> ()
        {
            return &_addr;
        }

        in_addr_t s_addr() const
        {
            return _addr.sin_addr.s_addr;
        }

        const char* ascii() const
        {
            if (_ascii[0] == '\0' || _s_addr != _addr.sin_addr.s_addr)
            {
                _s_addr = _addr.sin_addr.s_addr;
                if (_addr.sin_family != AF_INET)
                    return _ascii;
                if (inet_ntop(_addr.sin_family, &_addr.sin_addr, _ascii, sizeof(_ascii)) == NULL)
                {
                    LOGGER_PWARN("inet_ntop");
                    _ascii[0] = '\0';
                }
            }
            return _ascii;
        }

        const char* name() const
        {
            if (_name == NULL || _s_addr != _addr.sin_addr.s_addr)
            {
                _s_addr = _addr.sin_addr.s_addr;
#ifdef HAVE_GETNAMEINFO
                _name = (char*) realloc(_name, NI_MAXHOST);
                if (! _name)
                    return "";
                const int errcode = getnameinfo(reinterpret_cast<const sockaddr*>(&_addr), sizeof(_addr), _name, NI_MAXHOST, NULL, 0, NI_NOFQDN);
                if (errcode != 0)
                {
                    const char* ascii = this->ascii();
                    LOGGER_ERROR("getnameinfo(%s): %s", ascii, gai_strerror(errcode));
                    return ascii;
                }
                _name = (char*) realloc(_name, strlen(_name) + 1);
#elif defined(HAVE_GETHOSTBYADDR)
                struct hostent* hp = gethostbyaddr(&_addr.sin_addr, sizeof(_addr.sin_addr), AF_INET);
                if (hp == NULL)
                {
                    const char* ascii = this->ascii();
                    LOGGER_ERROR("gethostbyaddr(%s): %s", ascii, hstrerror(h_errno));
                    return ascii;
                }
                if (LOGGER_IS_DEBUG())
                {
                    const char* ascii = this->ascii();
                    for (char** alias = hp->h_aliases; *alias; ++alias)
                        LOGGER_DEBUG("gethostbyaddr(%s): %s %s", ascii, hp->h_name, *alias);
                }
                _name = (char*) realloc(_name, strlen(hp->h_name) + 1);
                if (! _name)
                    return "";
                strcpy(_name, hp->h_name);
#else
#  error
#endif
            }
            return _name;
        }

        const char* service(int socktype = SOCK_STREAM) const
        {
            if (_service == NULL || _s_addr != _addr.sin_addr.s_addr)
            {
#ifdef HAVE_GETNAMEINFO
                _service = (char*) realloc(_service, NI_MAXSERV);
                if (! _service)
                    return "";
                const int errcode = getnameinfo(reinterpret_cast<const sockaddr*>(&_addr), sizeof(_addr), NULL, 0, _service, NI_MAXSERV, socktype == SOCK_DGRAM ? NI_DGRAM : 0);
                if (errcode != 0)
                {
                    const char* ascii = this->ascii();
                    LOGGER_ERROR("getnameinfo(%s): %s", ascii, gai_strerror(errcode));
                    return ascii;
                }
                _service = (char*) realloc(_service, strlen(_service) + 1);
#elif defined(HAVE_GETSERVBYPORT)
                setservent(0);
                struct servent* s = getservbyport(port(), NULL);
                _service = (char*) realloc(_service, s == NULL ? 1 : strlen(s->s_name) + 1);
                if (! _service)
                    return "";
                strcpy(_service, s == NULL ? "" : s->s_name);
#else
#  error
#endif
            }
            return _service;
        }

        in_port_t port() const
        {
            return ntohs(_addr.sin_port);
        }

        void port(in_port_t port)
        {
            _addr.sin_port = htons(port);
        }

        friend bool operator==(const SockAddr& lhs, const SockAddr& rhs)
        {
            return memcmp(&lhs._addr, &rhs._addr, sizeof(lhs._addr)) == 0;
        }

        friend bool operator!=(const SockAddr& lhs, const SockAddr& rhs)
        {
            return memcmp(&lhs._addr, &rhs._addr, sizeof(lhs._addr)) != 0;
        }

        friend bool operator==(const SockAddr& lhs, const struct sockaddr_in& rhs)
        {
            return memcmp(&lhs._addr, &rhs, sizeof(lhs._addr)) == 0;
        }

        friend bool operator!=(const SockAddr& lhs, const struct sockaddr_in& rhs)
        {
            return memcmp(&lhs._addr, &rhs, sizeof(lhs._addr)) != 0;
        }

        friend bool operator==(const struct sockaddr_in& lhs, const SockAddr& rhs)
        {
            return memcmp(&lhs, &rhs._addr, sizeof(lhs)) == 0;
        }

        friend bool operator!=(const struct sockaddr_in& lhs, const SockAddr& rhs)
        {
            return memcmp(&lhs, &rhs._addr, sizeof(lhs)) != 0;
        }

        bool matches(const SockAddr& rhs) const
        {
            return matches(rhs._addr);
        }

        bool matches(const struct sockaddr_in& rhs) const
        {
            return LIKELY(_addr.sin_family == rhs.sin_family)
                && (_addr.sin_addr.s_addr == rhs.sin_addr.s_addr
                    || _addr.sin_addr.s_addr == INADDR_ANY
                    || rhs.sin_addr.s_addr == INADDR_ANY);
        }

        bool is_multicast() const
        {
            return LIKELY(_addr.sin_family == AF_INET)
                && (ntohl(_addr.sin_addr.s_addr) >> 28) == 0xe;
        }

    private:

        struct sockaddr_in _addr;
        mutable in_addr_t _s_addr; // used to determine if _addr was modified since _ascii or _name was resolved
        mutable char _ascii[INET_ADDRSTRLEN];
        mutable char* _name;
        mutable char* _service;
    };

    static inline int is_multicast(const struct sockaddr_in* addr)
    {
        return (ntohl(addr->sin_addr.s_addr) >> 28) == 0xe;
    }

    static int is_broadcast(const struct sockaddr_in* addr);

    static int is_interface_running(const struct ifaddrs* ifa);

    // FIXME: Should return an Addr (and take an in_addr)
    static SockAddr srcaddr(const struct sockaddr_in& target);

    static uint8_t max_ttl()
    {
#ifdef IPCTL_DEFTTL

        static int max_ttl = 0;
        if (max_ttl == 0)
        {
            int mib[4] = { CTL_NET, PF_INET, IPPROTO_IP, IPCTL_DEFTTL };
            size_t sz = sizeof(max_ttl);
            if (sysctl(mib, 4, &max_ttl, &sz, NULL, 0) == -1)
            {
                LOGGER_PERROR("sysctl(net.inet.ip.ttl)");
                max_ttl = 64;
            }
            max_ttl = 64;
        }
        return max_ttl;

#elif defined(__linux__)
        // TODO: read /proc/sys/net/ipv4/ip_default_ttl
#endif

        return 64;
    }

    ///////////////////////////////////////////////////////////////////
    // INet::Checksum
    ///////////////////////////////////////////////////////////////////

    // http://tools.ietf.org/html/rfc1071
    // http://tools.ietf.org/html/rfc768
    class Checksum
    {
    public:

        static uint16_t ip(const struct ip* ip);

        static uint16_t udp(const struct ip* ip);

        static uint16_t icmp(const struct icmp* icmp, size_t len);

        static uint16_t buffer(const void* buf, size_t len)
        {
            Checksum sum;
            sum.update(buf, len);
            return sum.checksum();
        }

    public:

        Checksum()
            : _sum(0)
        {}

        inline void reset()
        {
            _sum = 0;
        }

        // see http://tools.ietf.org/html/rfc1071
        Checksum& update(const void* buf, size_t count)
        {
            const uint16_t* p = reinterpret_cast<const uint16_t*>(buf);
            while (count > 1)
            {
                _sum += *p++;
                count -= 2;
            }

            /*  Add left-over byte, if any */
            if (count > 0)
                _sum += *(uint8_t*)p << 8;

            return *this;
        }

        template <typename T>
        inline Checksum& update(const T& x)
        {
            return update(&x, sizeof(T));
        }

        uint16_t checksum()
        {
            /*  Fold 32-bit sum to 16 bits */
            while (_sum >> 16)
                _sum = (_sum & 0xFFFF) + (_sum >> 16);

            return ~_sum;
        }

    private:

        uint32_t _sum;
    };

protected:

    /*
     * accept "node:port" as host
     * accept "" as node for loopback addr
     * accept "*" as node for any addr
     * accept "+" as node for broadcast addr
     */
    static int resolve_sockaddr_in(struct sockaddr_in* addr,
                                   const char* host,
                                   unsigned port,
                                   int socktype,
                                   int sockproto);

    static inline int round_down(int x, int n)
    {
        return (x / n) * n;
    }

    static inline int round_up(int x, int n)
    {
        return (x + x - 1) / n;
    }

protected:

    friend class Datagram;

    INet(int socktype, int sockproto)
        : Socket(socket(AF_INET, socktype, sockproto))
        , _mtu(-1)
        , _rcvbuf(-1)
        , _sndbuf(-1)
#ifdef SO_PRIORITY
        , _priority(-1)
#endif
    {
        if (_sockfd == -1)
        {
            LOGGER_PERROR("socket(AF_INET, %d, %d)", socktype, sockproto);
            _name[0] = '\0'; // to be safe
            return;
        }
        errno = 0;

#ifdef SO_NOSIGPIPE
        if (setsockopt(SOL_SOCKET, SO_NOSIGPIPE, 1) == -1)
            LOGGER_PWARN("setsockopt(SO_NOSIGPIPE)");
#endif

        memset(&_addr, 0, sizeof(_addr));
        strncpy(_name, "*", sizeof(IFNAMSIZ));
    }

    INet(int sockfd)
        : Socket(sockfd)
        , _mtu(-1)
        , _rcvbuf(-1)
        , _sndbuf(-1)
#ifdef SO_PRIORITY
        , _priority(-1)
#endif
    {
        LOGGER_ASSERT(_sockfd >= 0);

#ifdef SO_NOSIGPIPE
        if (setsockopt(SOL_SOCKET, SO_NOSIGPIPE, 1) == -1)
            LOGGER_PWARN("setsockopt(SO_NOSIGPIPE)");
#endif

        getsockname();
    }

public:

    const char* name() const
    {
        return _name;
    }

    unsigned port() const
    {
        return ntohs(_addr.sin_port);
    }

    int getsockopt(int level, int optname, int* optval) const
    {
        socklen_t slen = sizeof(int);
        return ::getsockopt(_sockfd, level, optname, optval, &slen);
    }

    template <typename T>
    int getsockopt(int level, int optname, T* optval) const
    {
        socklen_t slen = sizeof(T);
        return ::getsockopt(_sockfd, level, optname, optval, &slen);
    }

    int setsockopt(int level, int optname, int optval)
    {
        const int s = ::setsockopt(_sockfd, level, optname, &optval, sizeof(int));
        if (s != -1)
        {
            if (level == SOL_SOCKET)
            {
                switch (optname)
                {
                case SO_SNDBUF:
                    _sndbuf = optval;
                    LOGGER_DEBUG("SNDBUF = %'d (%.1biB)", _sndbuf, (float)_sndbuf);
                    break;
                case SO_RCVBUF:
                    _rcvbuf = optval;
                    LOGGER_DEBUG("RCVBUF = %'d (%.1biB)", _rcvbuf, (float)_rcvbuf);
                    break;
#ifdef SO_PRIORITY
                case SO_PRIORITY:
                    _priority = optval;
                    switch (_priority)
                    {
                    case TC_PRIO_BESTEFFORT:
                        LOGGER_DEBUG("SO_PRIORITY = TC_PRIO_BESTEFFORT (%d)", _priority);
                        break;
                    case TC_PRIO_FILLER:
                        LOGGER_DEBUG("SO_PRIORITY = TC_PRIO_FILLER (%d)", _priority);
                        break;
                    case TC_PRIO_BULK:
                        LOGGER_DEBUG("SO_PRIORITY = TC_PRIO_BULK (%d)", _priority);
                        break;
                    case TC_PRIO_INTERACTIVE_BULK:
                        LOGGER_DEBUG("SO_PRIORITY = TC_PRIO_INTERACTIVE_BULK (%d)", _priority);
                        break;
                    case TC_PRIO_INTERACTIVE:
                        LOGGER_DEBUG("SO_PRIORITY = TC_PRIO_INTERACTIVE (%d)", _priority);
                        break;
                    case TC_PRIO_CONTROL:
                        LOGGER_DEBUG("SO_PRIORITY = TC_PRIO_CONTROL (%d)", _priority);
                        break;
                    default:
                        LOGGER_DEBUG("SO_PRIORITY = %d", _priority);
                        break;
                    }
                    break;
#endif
                    case SO_KEEPALIVE:
                        LOGGER_DEBUG("SO_KEEPALIVE = %s", optval ? "YES" : "NO");
                        break;
                    case SO_REUSEADDR:
                        LOGGER_DEBUG("SO_REUSEADDR = %s", optval ? "YES" : "NO");
                        break;
#ifdef SO_REUSEPORT
                    case SO_REUSEPORT:
                        LOGGER_DEBUG("SO_REUSEPORT = %s", optval ? "YES" : "NO");
                        break;
#endif
#ifdef SO_BINDTODEVICE
                    case SO_BINDTODEVICE:
                        LOGGER_DEBUG("SO_BINDTODEVICE = %s", (char*)optval);
                        break;
#endif
#ifdef TCP_CONNECTIONTIMEOUT
                    case TCP_CONNECTIONTIMEOUT:
                        LOGGER_DEBUG("TCP_CONNECTIONTIMEOUT = %ds", optval);
                        break;
#endif
                }
            }
            else if (level == IPPROTO_IP)
            {
                switch (optname)
                {
#ifdef IP_MTU
                case IP_MTU:
                    _mtu = optval;
                    LOGGER_DEBUG("MTU = %'d (%.1biB)", _mtu, (float)_mtu);
                    break;
#endif
                case IP_TTL:
                    LOGGER_DEBUG("TTL = %d", optval);
                    break;
                case IP_TOS:
#ifdef IPTOS_TOS
                    switch (IPTOS_TOS(optval))
#else
                    switch (optval)
#endif
                    {
                    case IPTOS_LOWDELAY:
                        LOGGER_DEBUG("IP_TOS = LOWDELAY");
                        break;
                    case IPTOS_THROUGHPUT:
                        LOGGER_DEBUG("IP_TOS = THROUGHPUT");
                        break;
                    case IPTOS_RELIABILITY:
                        LOGGER_DEBUG("IP_TOS = RELIABILITY");
                        break;
                    case IPTOS_MINCOST:
                        LOGGER_DEBUG("IP_TOS = MINCOST");
                        break;
                    default:
                        LOGGER_DEBUG("IP_TOS = %d", optval);
                        break;
                    }
                    break;
#ifdef IP_BOUND_IF
                case IP_BOUND_IF:
                    if (LOGGER_IS_DEBUG())
                    {
                        char ifname[IFNAMSIZ];
                        if (if_indextoname(optval, ifname) == NULL)
                            ifname[0] = '\0';
                        LOGGER_DEBUG("IP_BOUND_IF = %d (%s)", optval, ifname);
                    }
                    break;
#endif
                }
            }
            else if (level == IPPROTO_TCP)
            {
                switch (optname)
                {
#ifdef TCP_KEEPCNT
                case TCP_KEEPCNT:
                    LOGGER_DEBUG("TCP_KEEPCNT = %d", optval);
                    break;
#endif
#ifdef TCP_KEEPIDLE
                case TCP_KEEPIDLE:
                    LOGGER_DEBUG("TCP_KEEPIDLE = %'ds", optval);
                    break;
#endif
#ifdef TCP_KEEPALIVE
                case TCP_KEEPALIVE:
                    LOGGER_DEBUG("TCP_KEEPALIVE = %'ds", optval);
                    break;
#endif
#ifdef TCP_KEEPINTVL
                case TCP_KEEPINTVL:
                    LOGGER_DEBUG("TCP_KEEPINTVL = %'ds", optval);
                    break;
#endif
#ifdef TCP_SYNCNT
                case TCP_SYNCNT:
                    LOGGER_DEBUG("TCP_SYNCNT = %d", optval);
                    break;
#endif
                }
            }
        }
        return s;
    }

    int setsockopt(int level, int optname, struct timeval* tv)
    {
        const int s = ::setsockopt(_sockfd, level, optname, tv, sizeof(struct timeval));
        if (LOGGER_IS_DEBUG() && s != -1)
        {
            const char* name = NULL;
            if (level == SOL_SOCKET)
            {
                switch (optname)
                {
                case SO_RCVTIMEO:   name = "SO_RCVTIMEO"; break;
                case SO_SNDTIMEO:   name = "SO_SNDTIMEO"; break;
                }
            }

            if (name)
            {
#ifdef LOGGER_OSTREAM
                LOGGER_ODEBUG(odbg) << name << " = " << *tv;
#else
                if (tv->tv_sec > 0)
                    if (tv->tv_usec > 0)
                        LOGGER_DEBUG("%s = %'lus%'06ld", name, tv->tv_sec, (long)tv->tv_usec);
                    else
                        LOGGER_DEBUG("%s = %'lus", name, tv->tv_sec);
                else
                    LOGGER_DEBUG("%s = %'ldus", name, (long)tv->tv_usec);
#endif
            }
        }
        return s;
    }

    template <typename T>
    int setsockopt(int level, int optname, T* optval)
    {
        return ::setsockopt(_sockfd, level, optname, optval, sizeof(T));
    }

    int ip_mtu()
    {
        if (_mtu == -1)
        {
#ifdef IP_MTU
            if (getsockopt(IPPROTO_IP, IP_MTU, &_mtu) == -1)
            {
                if (errno != ENOTCONN)
                    LOGGER_PWARN("getsockopt(IP_MTU)");
                else
                    errno = 0;
                (void) gifmtu();
            }
#else
            (void) gifmtu();
#endif

            LOGGER_DEBUG("MTU = %'d (%.1biB)", _mtu, (float) _mtu);
        }
        return _mtu;
    }

    // @see <a href="http://lxr.free-electrons.com/source/net/ipv4/ip_sockglue.c#L249">ip_sockglue.c</a>
    // TOS also sets PRIORITY (on linux):
    // IPTOS_LOWDELAY (0x10)    -> TC_PRIO_BULK (2)
    // IPTOS_THROUGHPUT (0x08)  -> TC_PRIO_BULK (2)
    // IPTOS_RELIABILITY (0x04) -> TC_PRIO_BESTEFFORT (0)
    // IPTOS_MINCOST (0x02)     -> TC_PRIO_BESTEFFORT (0)
    int ip_tos(int tos)
    {
        if (setsockopt(IPPROTO_IP, IP_TOS, tos) == -1)
        {
            LOGGER_PERROR("setsockopt(IP_TOS, %d)", tos);
            return -1;
        }
        return 0;
    }

    int so_rcvbuf()
    {
        if (_rcvbuf == -1)
        {
            if (getsockopt(SOL_SOCKET, SO_RCVBUF, &_rcvbuf) == -1)
            {
                LOGGER_PERROR("getsockopt(SO_RCVBUF)");
                _rcvbuf = _mtu;
            }
            else
            {
#ifdef __linux__
                _rcvbuf /= 2;
#endif
            }
            LOGGER_DEBUG("RCVBUF = %'d (%.1biB)", _rcvbuf, (float)_rcvbuf);
        }
        return _rcvbuf;
    }

    int so_rcvbuf(int rcvbuf)
    {
        if (setsockopt(SOL_SOCKET, SO_RCVBUF, rcvbuf) == -1)
        {
            LOGGER_PERROR("setsockopt(SO_RCVBUF, %d)", rcvbuf);
            return -1;
        }
        return 0;
    }

    int so_sndbuf()
    {
        if (_sndbuf == -1)
        {
            if (getsockopt(SOL_SOCKET, SO_SNDBUF, &_sndbuf) == -1)
            {
                LOGGER_PWARN("getsockopt(SO_SNDBUF)");
                _sndbuf = _mtu;
            }
            else
            {
#ifdef __linux__
                _sndbuf /= 2;
#endif
            }
            LOGGER_DEBUG("SNDBUF = %'d (%.1biB)", _sndbuf, (float)_sndbuf);
        }
        return _sndbuf;
    }

    int so_sndbuf(int sndbuf)
    {
        if (setsockopt(SOL_SOCKET, SO_SNDBUF, sndbuf) == -1)
        {
            LOGGER_PERROR("setsockopt(SO_SNDBUF, %d)", sndbuf);
            return -1;
        }
        return 0;
    }

    int so_rcvtimeo(struct timeval* tv)
    {
        if (setsockopt(SOL_SOCKET, SO_RCVTIMEO, tv) == -1)
        {
            LOGGER_PERROR("setsockopt(SO_RCVTIMEO)");
            return -1;
        }
        return 0;
    }

    int so_sndtimeo(struct timeval* tv)
    {
        if (setsockopt(SOL_SOCKET, SO_SNDTIMEO, tv) == -1)
        {
            LOGGER_PERROR("setsockopt(SO_SNDTIMEO)");
            return -1;
        }
        return 0;
    }

#ifdef SO_PRIORITY
    // @see <a href="http://lxr.free-electrons.com/source/include/uapi/linux/pkt_sched.h#L23">pkt_sched.h</a>
    int so_priority(int priority)
    {
        if (_priority == priority)
            return 0;

        if (setsockopt(SOL_SOCKET, SO_PRIORITY, priority) == -1)
        {
            LOGGER_PERROR("setsockopt(SO_PRIORITY, %d)", priority);
            return -1;
        }
        return 0;
    }
#endif

    int so_keepalive(int set)
    {
        if (setsockopt(SOL_SOCKET, SO_KEEPALIVE, set) == -1)
        {
            LOGGER_PERROR("setsockopt(SO_KEEPALIVE, %d)", set);
            return -1;
        }
        return 0;
    }

    int so_error()
    {
        int err;
        if (getsockopt(SOL_SOCKET, SO_ERROR, &err) == -1)
        {
            LOGGER_PERROR("getsockopt(SO_ERROR)");
            return -1;
        }
        return err;
    }

#ifdef FIONREAD
    int fionread()
    {
        int nread;
        if (ioctl(_sockfd, FIONREAD, &nread) == -1)
        {
            LOGGER_PERROR("ioctl(FIONREAD)");
            return -1;
        }
        return nread;
    }
#endif

#ifdef SIOCINQ
    int siocinq()
    {
        int inq;
        if (ioctl(_sockfd, SIOCINQ, &inq) == -1)
        {
            LOGGER_PERROR("ioctl(SIOCINQ)");
            return -1;
        }

#  ifdef __linux__
        inq /= 2;
#  endif

        return inq;
    }
#endif

#ifdef SIOCOUTQ
    int siocoutq()
    {
        int outq;
        if (ioctl(_sockfd, SIOCOUTQ, &outq) == -1)
        {
            LOGGER_PERROR("ioctl(SIOCOUTQ)");
            return -1;
        }

#  ifdef __linux__
        outq /= 2;
#  endif

        return outq;
    }
#endif

#ifdef SIOCOUTQNSD
    // NOTE: siocoutqnsd() only applies to tty's
    int siocoutqnsd()
    {
        int outqnsd;
        if (ioctl(_sockfd, SIOCOUTQNSD, &outqnsd) == -1)
        {
            LOGGER_PERROR("ioctl(SIOCOUTQNSD)");
            return -1;
        }

#  ifdef __linux__
        outqnsd /= 2;
#  endif

        return outqnsd;
    }
#endif

    int bind(const struct sockaddr_in& addr)
    {
        if (setsockopt(SOL_SOCKET, SO_REUSEADDR, 1) == -1)
            LOGGER_PWARN("setsockopt(SO_REUSEADDR)");

        if (::bind(_sockfd, (struct sockaddr*) &addr, sizeof(addr)) == -1)
        {
            StashErrno stasherrno;
            if (inet_ntop(addr.sin_family, &addr.sin_addr, _name, sizeof(_name)) == NULL)
            {
                LOGGER_PWARN("inet_ntop");
                _name[0] = '\0';
            }
            LOGGER_PERROR("bind(%s:%u)", _name, ntohs(addr.sin_port));
            return -1;
        }

        (void) getsockname();

        if (LOGGER_IS_DEBUG())
            LOGGER_DEBUG("Bound to %s:%u", name(), port());

        if (is_multicast(&addr))
        {
            struct ip_mreq mcast;
            mcast.imr_multiaddr.s_addr = addr.sin_addr.s_addr;
            mcast.imr_interface.s_addr = 0;
            if (setsockopt(IPPROTO_IP, IP_ADD_MEMBERSHIP, &mcast) == -1)
                LOGGER_PWARN("setsockopt(IP_ADD_MEMBERSHIP)");
        }

        return 0;
    }

    int bindtodevice(const char* dev)
    {
#ifdef SO_BINDTODEVICE
        socklen_t len = strlen(dev);
        LOGGER_ASSERT1(len <= IFNAMSIZ, len);
        if (::setsockopt(_sockfd, SOL_SOCKET, SO_BINDTODEVICE, dev, len) == -1)
        {
            LOGGER_PERROR("setsockopt(SO_BINDTODEVICE, %s)", dev);
            return -1;
        }
#elif defined(IP_BOUND_IF)
        int ifindex = if_nametoindex(dev);
        if (ifindex == 0)
            return -1;
        if (setsockopt(IPPROTO_IP, IP_BOUND_IF, ifindex) == -1)
        {
            LOGGER_PERROR("setsockopt(IP_BOUND_IF, %s)", dev);
            return -1;
        }
#else
        errno = ENOTSUP;
        return -1;
#endif

        struct ifreq ifr;
        memset(&ifr, 0, sizeof(ifr));
        strncpy(ifr.ifr_name, dev, sizeof(ifr.ifr_name));
        if (ioctl(_sockfd, SIOCGIFADDR, &ifr) == -1)
        {
            LOGGER_PERROR("ioctl(SIOCGIFADDR)");
            return -1;
        }
        LOGGER_ASSERT1(ifr.ifr_addr.sa_family == AF_INET, ifr.ifr_addr.sa_family);
#ifdef HAVE_SOCKADDR_SA_LEN
        LOGGER_ASSERT1(ifr.ifr_addr.sa_len == sizeof(struct sockaddr_in), ifr.ifr_addr.sa_len);
#endif

        memcpy(&_addr, &ifr.ifr_addr, sizeof(_addr));

        if (inet_ntop(_addr.sin_family, &_addr.sin_addr, _name, sizeof(_name)) == NULL)
        {
            LOGGER_PWARN("inet_ntop");
            _name[0] = '\0';
        }

        LOGGER_DEBUG("Bound to %s (%s)", dev, name());
        return 0;
    }

    const struct sockaddr_in* addr() const
    {
        return &_addr;
    }

#if 0
    int wait_for_input(struct timeval* timeout = NULL)
    {
        for (;;)
        {
            if (Socket::wait_for_input(timeout) == -1)
                return -1;

            // try to detect connection close

            char c;
            switch (::recv(_sockfd, &c, sizeof(c), MSG_PEEK | MSG_DONTWAIT))
            {
            case -1:    if (errno == EWOULDBLOCK && (timeout && (timeout->tv_sec > 0 || timeout->tv_usec > 0)))
                            continue;
                        return -1;
            case 0:     if (timeout && (timeout->tv_sec > 0 || timeout->tv_usec > 0))
                            continue;
                        errno = ECONNRESET; // connection closed by peer
                        return -1;
            case 1:     return 0;
            default:    UNREACHABLE();
            }
        }
    }
#endif

protected:

    int gifmtu()
    {
        _mtu = ETH_DATA_LEN;

        struct ifaddrs* ifa;
        if (getifaddrs(&ifa) == -1)
        {
            LOGGER_PWARN("getifaddrs");
            return -1;
        }

        for (struct ifaddrs* p = ifa; p != NULL; p = p->ifa_next)
        {
            if (p->ifa_addr == NULL)
                continue;
            if (p->ifa_addr->sa_family != AF_INET)
                continue;
            if (! BITMASK_ARESET(p->ifa_flags, IFF_UP | IFF_RUNNING))
                continue;
            if (BITMASK_ISSET(p->ifa_flags, IFF_LOOPBACK))
                continue;

            struct ifreq ifr;
            memset(&ifr, 0, sizeof(ifr));
            strncpy(ifr.ifr_name, p->ifa_name, sizeof(ifr.ifr_name));
            if (ioctl(_sockfd, SIOCGIFMTU, &ifr) != -1 && ifr.ifr_mtu > 0)
            {
                if (ifr.ifr_mtu < _mtu)
                    _mtu = ifr.ifr_mtu;
            }

#ifdef PPP_MTU
            if (BITMASK_ISSET(p->ifa_flags, IFF_POINTOPOINT))
            {
                if (PPP_MTU - 36 < _mtu) // ???
                    _mtu = PPP_MTU - 36;
            }
#endif
        }

        freeifaddrs(ifa);

        return 0;
    }

    int getsockname()
    {
        socklen_t socklen = sizeof(_addr);
        if (::getsockname(_sockfd, (struct sockaddr*)&_addr, &socklen) == -1)
        {
            LOGGER_PWARN("getsockname");
            memset(&_addr, 0, sizeof(_addr));
            return -1;
        }

        if (inet_ntop(_addr.sin_family, &_addr.sin_addr, _name, sizeof(_name)) == NULL)
        {
            LOGGER_PWARN("inet_ntop");
            _name[0] = '\0';
            return -1;
        }

        return 0;
    }

private:

    int _mtu;
    int _rcvbuf;
    int _sndbuf;
#ifdef SO_PRIORITY
    int _priority;
#endif

    struct sockaddr_in _addr;
    char _name[INET_ADDRSTRLEN];
};

#endif
