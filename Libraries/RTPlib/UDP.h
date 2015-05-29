
#ifndef _UDP_H_
#define _UDP_H_

#ifdef __APPLE__
#  include <TargetConditionals.h>
#endif

/* C99 requires that stdint.h only exposes UINT16_MAX if this is defined: */
#ifndef __STDC_LIMIT_MACROS
#  define __STDC_LIMIT_MACROS
#endif
#include <stdint.h>

#if !TARGET_OS_IPHONE
#  include <netinet/udp.h>
#else
#  include <sys/types.h>          /* u_short */

/*
 * Udp protocol header.
 * Per RFC 768, September, 1981.
 */
struct udphdr {
        u_short uh_sport;               /* source port */
        u_short uh_dport;               /* destination port */
        u_short uh_ulen;                /* udp length */
        u_short uh_sum;                 /* udp checksum */
};
#endif

#include "Net.h"
#include "Thread.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             DATAGRAM                              //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class Datagram
    : public INet
{
protected:

    Datagram(int sockproto)
        : INet(SOCK_DGRAM, sockproto)
    {}

    // make it easier to UDP
    Datagram()
        : INet(SOCK_DGRAM, IPPROTO_UDP)
    {}

public:

    static int ping(struct sockaddr_in* from,
                    uint8_t* hops,
                    long* timeus,
                    const struct sockaddr_in& target,
                    const struct timeval* timeout = NULL,
                    const char* interface = NULL,
                    size_t nbytes = 56,
                    uint8_t ttl = max_ttl())
    {
        int n = traceroute(from, hops, timeus, 1, target, timeout, interface, nbytes, ttl);
        if (n == 1 && timeus[0] == 0)
            return 0;
        return n;
    }

    static int traceroute(struct sockaddr_in* from,
                          uint8_t* hops,
                          long* timeus,
                          uint8_t len,
                          const struct sockaddr_in& target,
                          const struct timeval* timeout = NULL,
                          const char* interface = NULL,
                          size_t nbytes = 56,
                          uint8_t minttl = 1);

private:

    static const unsigned short TRACEROUTE_PORT = 32768 + 666;
};

    ///////////////////////////////////////////////////////////////////
    // DatagramSender
    ///////////////////////////////////////////////////////////////////

class DatagramSender
    : public virtual Datagram
{
protected:

    DatagramSender(int sockproto, const struct sockaddr_in* dest)
        : Datagram(sockproto)
    {
        destaddr(dest);
        sndbufsiz(so_sndbuf());
    }

public:

    const char* destname() const
    {
        return _destname;
    }

    unsigned destport() const
    {
        return ntohs(_dest.sin_port);
    }

    bool broadcasting() const
    {
        return is_broadcast(&_dest) == 1;
    }

    virtual size_t sndbufsiz() const
    {
        return _sndbufsiz;
    }

    virtual void sndbufsiz(int bufsiz)
    {
        if (bufsiz > so_sndbuf())
            bufsiz = so_sndbuf();

        if (bufsiz > IP_MAXPACKET)
            bufsiz = IP_MAXPACKET;
        else if (bufsiz <= 0)
            bufsiz = ip_mtu();

        if ((unsigned)bufsiz <= ip_mtu() - sizeof(struct ip))
            _sndbufsiz = bufsiz - sizeof(struct udphdr);
        else
            _sndbufsiz = round_down(bufsiz, ip_mtu() - sizeof(struct ip)) - sizeof(struct udphdr);

        LOGGER_DEBUG("SNDBUFSIZ = %'zd (%.1biB)", _sndbufsiz, (float) _sndbufsiz);
    }

    virtual ssize_t send(const void* buf, size_t len, int flags,
                         const struct sockaddr_in* dest = NULL)
    {
        struct iovec iovec;
        iovec.iov_base = const_cast<void*>(buf);
        iovec.iov_len = len;
        return sendv(&iovec, 1, flags, dest);
    }

    virtual ssize_t sendv(struct iovec* iov, unsigned iovlen, int flags,
                          const struct sockaddr_in* dest = NULL);

    const struct sockaddr_in* destaddr() const
    {
        return _dest.sin_family == AF_UNSPEC ? NULL : &_dest;
    }

    void destaddr(const struct sockaddr_in* dest)
    {
        if (dest)
        {
            memcpy(&_dest, dest, sizeof(_dest));

            if (inet_ntop(_dest.sin_family, &_dest.sin_addr, _destname, sizeof(_destname)) == NULL)
            {
                LOGGER_PWARN("inet_ntop");
                _destname[0] = '\0';
            }
            LOGGER_DEBUG("destaddr = %s:%u", destname(), destport());

            if (broadcasting())
            {
                if (setsockopt(SOL_SOCKET, SO_BROADCAST, 1) == -1)
                    LOGGER_PWARN("setsockopt(SO_BROADAST)");
            }
        }
        else
        {
            LOGGER_DEBUG("destaddr = NULL");
            memset(&_dest, 0, sizeof(_dest));
            _destname[0] = '\0';
        }
    }

protected:

    bool matches_dest(const struct sockaddr_in* peer) const
    {
        return _dest.sin_addr.s_addr == htonl(INADDR_ANY)
            || _dest.sin_addr.s_addr == peer->sin_addr.s_addr;
    }

protected:

    friend class UDPBounded;

    ///////////////////////////////////////////////////////////////////
    // DatagramSender::Packetizer
    ///////////////////////////////////////////////////////////////////

    class Packetizer
    {
    public:

        Packetizer(struct iovec* iov, unsigned iovcnt,
                   size_t bufsiz)
            : _iov_in(iov)
            , _iovcnt_in(iovcnt)
            , _bufsiz(bufsiz)
        {
            _remaining_siz = 0;
            _iovcnt_in_effective = 0;
            for (unsigned i = 0; i < iovcnt; ++i)
            {
                if (iov[i].iov_len > 0)
                {
                    _remaining_siz += iov[i].iov_len;
                    ++_iovcnt_in_effective;
                }
            }
        }

        size_t size() const
        {
            return _remaining_siz;
        }

        unsigned iovsiz() const
        {
            return _iovcnt_in_effective;
        }

        void* base()
        {
            while (_iovcnt_in > 0 && _iov_in->iov_len == 0)
                advance();
            return _iovcnt_in == 0 ? NULL : _iov_in->iov_base;
        }

        void* skip(size_t len);

        unsigned next(struct iovec* iov_out, unsigned iovsiz_out);

    private:

        void advance()
        {
            if (_iov_in->iov_len > 0)
            {
                // FIXME: not quite right...
                --_iovcnt_in_effective;
            }
            ++_iov_in;
            --_iovcnt_in;
        }

    private:

        struct iovec* _iov_in;
        unsigned _iovcnt_in;
        unsigned _iovcnt_in_effective; // _iovcnt_in - empty slots
        size_t _remaining_siz;
        const size_t _bufsiz;
    };

private:

    size_t _sndbufsiz;

    // TODO: Replace with SockAddr
    struct sockaddr_in _dest;
    char _destname[INET_ADDRSTRLEN];
};

    ///////////////////////////////////////////////////////////////////
    // DatagramReceiver
    ///////////////////////////////////////////////////////////////////

class DatagramReceiver
    : public virtual Datagram
{
protected:

    DatagramReceiver(int sockproto)
        : Datagram(sockproto)
    {}

public:

    virtual size_t rcvbufsiz()
    {
        int bufsiz = so_rcvbuf();
        if (bufsiz <= 0)
            bufsiz = IP_MAXPACKET;
        if (bufsiz <= (int)(sizeof(struct ip) + sizeof(struct udphdr)))
            return 0;
        bufsiz -= round_up(bufsiz, ip_mtu()) * sizeof(struct ip) + sizeof(struct udphdr);
        return bufsiz;
    }

    virtual void rcvbufsiz(int bufsiz)
    {
        const int mtu = ip_mtu();
        bufsiz += sizeof(struct udphdr);
        bufsiz += round_up(bufsiz, mtu) * sizeof(struct ip);
        bufsiz = round_up(bufsiz, mtu) * mtu;

        if (bufsiz > IP_MAXPACKET)
            bufsiz = IP_MAXPACKET;
        if (bufsiz <= ip_mtu())
            bufsiz = ip_mtu();

        if (so_rcvbuf(bufsiz) != -1)
        {
            if (LOGGER_IS_DEBUG())
            {
                const size_t rcvbufsiz = this->rcvbufsiz();
                LOGGER_DEBUG("RCVBUFSIZ = %'zd (%.1biB)", rcvbufsiz, (float) rcvbufsiz);
            }
        }
    }

    virtual ssize_t recv(void* buffer, size_t len,
                         int flags,
                         struct timeval* timeout = NULL,
                         struct sockaddr_in* src = NULL)
    {
        struct iovec iov;
        iov.iov_base = buffer;
        iov.iov_len = len;
        return recvv(&iov, 1, flags, timeout, src);
    }

    virtual ssize_t recvv(struct iovec* iov, unsigned iovcnt,
                          int flags,
                          struct timeval* timeout = NULL,
                          struct sockaddr_in* src = NULL);

    virtual ssize_t peek(void* buffer, size_t len, int flags,
                         struct timeval* timeout = NULL,
                         struct sockaddr_in* src = NULL)
    {
        BITMASK_SET(flags, MSG_PEEK);
        return recv(buffer, len, flags, timeout, src);
    }
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                                UDP                                //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class UDPSender
    : public DatagramSender
{
public:

    UDPSender(const struct sockaddr_in* dest)
        : Datagram(IPPROTO_UDP)
        , DatagramSender(IPPROTO_UDP, dest)
    {}
};

class UDPReceiver
    : public DatagramReceiver
{
public:

    UDPReceiver()
        : Datagram(IPPROTO_UDP)
        , DatagramReceiver(IPPROTO_UDP)
    {}
};

class UDP
    : public UDPSender, public UDPReceiver
{
public:

    static int resolve_sockaddr_in(struct sockaddr_in* addr,
                                   const char* host,
                                   unsigned port)
    {
        return INet::resolve_sockaddr_in(addr, host, port, SOCK_DGRAM, IPPROTO_UDP);
    }

    UDP(const struct sockaddr_in* dest)
        : Datagram(IPPROTO_UDP)
        , UDPSender(dest)
        , UDPReceiver()
    {}
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                            UDPBounded                             //
//                                                                   //
///////////////////////////////////////////////////////////////////////

#include <memory>
#include <iterator>
#include <list>

class UDPBounded
{
public:

    UDPBounded(const struct sockaddr_in* dest)
        : _dest(dest)
        , _current(_sockets.end())
        , _monitor(5, this)
    {
#if 0
        if (refresh_sockets() != -1)
            sndbufsiz(so_sndbuf());

        _current = _sockets.begin();
#endif

        _monitor.start();
    }

    virtual ~UDPBounded()
    {
        (void) _monitor.cancel();
        (void) _monitor.join(); // TODO: timeout!

        UpgradableRWLock::ReaderWriterGuard wrguard(_lock, true);

        sockets_clear(wrguard);
    }

    operator bool () const
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        for (std::list<UDP*>::const_iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            if (! (*it))
                return false;
        }
        return ! _sockets.empty();
    }

    int close()
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        for (std::list<UDP*>::iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            if ((*it)->close() == -1)
                return -1;
        }
        return 0;
    }

    int so_sndbuf()
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        int min = INT_MAX;
        for (std::list<UDP*>::iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            int sndbuf = (*it)->so_sndbuf();
            if (sndbuf < min)
                min = sndbuf;
        }
        return min == INT_MAX ? 0 : min;
    }

    int so_sndbuf(int sndbuf)
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        for (std::list<UDP*>::iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            if ((*it)->so_sndbuf(sndbuf) == -1)
                return -1;
        }
        return 0;
    }

    int so_sndtimeo(struct timeval* tv)
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        for (std::list<UDP*>::iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            if ((*it)->so_sndtimeo(tv) == -1)
                return -1;
        }
        return 0;
    }

#ifdef SO_PRIORITY
    int so_priority(int priority)
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        for (std::list<UDP*>::iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            if ((*it)->so_priority(priority) == -1)
                return -1;
        }
        return 0;
    }
#endif

    int so_error()
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        if (_current == _sockets.end())
            return 0;
        return (*_current)->so_error();
    }

    size_t sndbufsiz() const
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        size_t min = SIZE_MAX;
        for (std::list<UDP*>::const_iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            const size_t bufsiz = (*it)->sndbufsiz();
            if (bufsiz < min)
                min = bufsiz;
        }
        return min == SIZE_MAX ? 0 : min;
    }

    void sndbufsiz(int bufsiz)
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        for (std::list<UDP*>::iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            (*it)->sndbufsiz(bufsiz);
        }
    }

#ifdef SIOCOUTQ
    int siocoutq()
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        int max = 0;
        for (std::list<UDP*>::iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            int outq = (*it)->siocoutq();
            if (outq > max)
                max = outq;
        }
        return max;
    }
#endif

#ifdef SIOCOUTQNSD
    int siocoutqnsd()
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        int max = 0;
        for (std::list<UDP*>::iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            int outqnsd = (*it)->siocoutqnsd();
            if (outqnsd > max)
                max = outqnsd;
        }
        return max;
    }
#endif

    int ip_mtu()
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        int min = INT_MAX;
        for (std::list<UDP*>::const_iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            const int mtu = (*it)->ip_mtu();
            if (mtu < min)
                min = mtu;
        }
        return min == INT_MAX ? 0 : min;
    }

    int ip_tos(int tos)
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        for (std::list<UDP*>::iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            if ((*it)->ip_tos(tos) == -1)
                return -1;
        }
        return 0;
    }

    unsigned sockets() const
    {
        UpgradableRWLock::ReaderWriterGuard rwguard(_lock);

        return sockets_locked(rwguard);
    }

    const UDP* current() const
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        return _current == _sockets.end() ? NULL : *_current;
    }

    void next()
    {
        UpgradableRWLock::ReaderWriterGuard rwguard(_lock);

        next_locked(rwguard);
    }

    int refresh_sockets();

    // FIXME: _current could be deleted by Monitor
    //        between a call to wait_for_input()
    //        and a call to recv()
    int wait_for_input(struct timeval* timeout = NULL)
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        return (*_current)->wait_for_input(timeout);
    }

    // FIXME: _current could be deleted by Monitor
    //        between a call to wait_for_any_input()
    //        and a call to recv()
    int wait_for_any_input(struct timeval* timeout = NULL)
    {
        UpgradableRWLock::ReaderWriterGuard rwguard(_lock);

        return wait_for_any_input_locked(rwguard, timeout);
    }

    // FIXME: _current could be deleted by Monitor
    //        between a call to wait_for_output()
    //        and a call to send()
    int wait_for_output(struct timeval* timeout = NULL)
    {
        UpgradableRWLock::ReaderGuard rdguard(_lock);

        return (*_current)->wait_for_output(timeout);
    }

    // FIXME: _current could be deleted by Monitor
    //        between a call to wait_for_any_output()
    //        and a call to send()
    int wait_for_any_output(struct timeval* timeout = NULL)
    {
        UpgradableRWLock::ReaderWriterGuard rwguard(_lock);

        return wait_for_any_output_locked(rwguard, timeout);
    }

    ssize_t send(const void* buf, size_t len, int flags,
                 const struct sockaddr_in* dest = NULL)
    {
        struct iovec iovec;
        iovec.iov_base = const_cast<void*>(buf);
        iovec.iov_len = len;
        return sendv(&iovec, 1, flags, dest);
    }

    ssize_t sendv(struct iovec* iov, unsigned iovlen, int flags,
                  const struct sockaddr_in* dest = NULL)
    {
        UpgradableRWLock::ReaderWriterGuard rwguard(_lock);
        return sendv_locked(rwguard, iov, iovlen, flags, dest);
    }

    ssize_t recv(void* buffer, size_t len,
                 int flags,
                 struct timeval* timeout = NULL,
                 struct sockaddr_in* src = NULL)
    {
        struct iovec iov;
        iov.iov_base = buffer;
        iov.iov_len = len;
        return recvv(&iov, 1, flags, timeout, src);
    }

    virtual ssize_t recvv(struct iovec* iov, unsigned iovcnt,
                          int flags,
                          struct timeval* timeout = NULL,
                          struct sockaddr_in* src = NULL);

protected:

    typedef DatagramSender::Packetizer Packetizer;

    unsigned sockets_locked(UpgradableRWLock::ReaderWriterGuard& rwguard) const
    {
        return (unsigned) _sockets.size();
    }

    int wait_for_any_input_locked(UpgradableRWLock::ReaderWriterGuard& rwguard,
                                  struct timeval* timeout = NULL)
    {
        switch (_sockets.size())
        {
        case 0:
            errno = EWOULDBLOCK;
            return 0;
        case 1:
            return (*_current)->wait_for_input(timeout);
        }

        INet::FDSet readfds;
        for (std::list<UDP*>::const_iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            readfds.set(*(*it));
        }

        const int n = INet::select(&readfds, NULL, timeout);
        if (n >= 1)
            next_locked(rwguard, readfds);
        return n;
    }

    int wait_for_any_output_locked(UpgradableRWLock::ReaderWriterGuard& rwguard,
                                   struct timeval* timeout = NULL)
    {
        switch (_sockets.size())
        {
        case 0:
            errno = EWOULDBLOCK;
            return 0;
        case 1:
            return (*_current)->wait_for_output(timeout);
        }

        INet::FDSet writefds;
        for (std::list<UDP*>::const_iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            writefds.set(*(*it));
        }

        const int n = INet::select(NULL, &writefds, timeout);
        if (n >= 1)
            next_locked(rwguard, writefds);
        return n;
    }

    ssize_t sendv_locked(UpgradableRWLock::ReaderWriterGuard& rwguard,
                         struct iovec* iov, unsigned iovlen, int flags,
                         const struct sockaddr_in* dest = NULL);

    void next_locked(UpgradableRWLock::ReaderWriterGuard& rwguard,
                     const INet::FDSet& fds)
    {
        while (! fds.isset(*(*_current)))
            next_locked(rwguard);
    }

    void next_locked(UpgradableRWLock::ReaderWriterGuard& rwguard)
    {
        ++_current;
        if (_current == _sockets.end())
            _current = _sockets.begin();
    }

    void sockets_add(UpgradableRWLock::ReaderWriterGuard& rwguard,
                     UDP* socket)
    {
        UpgradableRWLock::WriterGuard wguard(rwguard);

        _sockets.push_back(socket);

        if (_current == _sockets.end())
            _current = _sockets.begin();

        add_socket(wguard, socket);
    }

    bool sockets_remove(UpgradableRWLock::ReaderWriterGuard& rwguard,
                        const struct ifaddrs* ifa)
    {
        std::list<UDP*>::iterator it = sockets_find(rwguard, ifa);
        if (it == _sockets.end())
            return false;

        (void) sockets_erase(rwguard, it);

        return true;
    }

    std::list<UDP*>::iterator sockets_erase(UpgradableRWLock::ReaderWriterGuard& rwguard,
                                            std::list<UDP*>::iterator it)
    {
        UpgradableRWLock::WriterGuard wguard(rwguard);

        remove_socket(wguard, *it);

        delete (*it);
        if (it != _current)
            return _sockets.erase(it);

        _current = _sockets.erase(it);
        if (_current == _sockets.end())
            _current = _sockets.begin();
        return _current;
    }

    std::list<UDP*>::iterator sockets_find(UpgradableRWLock::ReaderWriterGuard& rwguard,
                                           const struct ifaddrs* ifa)
    {
        const in_addr_t ifa_s_addr = reinterpret_cast<const struct sockaddr_in*>(ifa->ifa_addr)->sin_addr.s_addr;
        return sockets_find(rwguard, ifa_s_addr);
    }

    std::list<UDP*>::iterator sockets_find(UpgradableRWLock::ReaderWriterGuard& rwguard,
                                           in_addr_t addr)
    {
        std::list<UDP*>::iterator it;
        for (it = _sockets.begin(); it != _sockets.end(); ++it)
        {
            if ((*it)->addr()->sin_addr.s_addr == addr)
                break;
        }
        return it;
    }

    virtual void add_socket(UpgradableRWLock::WriterGuard& wguard, const UDP* udp)
    {}

    virtual void remove_socket(UpgradableRWLock::WriterGuard& wguard, const UDP* udp)
    {}

private:

    void sockets_clear(UpgradableRWLock::ReaderWriterGuard& rwguard)
    {
        UpgradableRWLock::WriterGuard wguard(rwguard);

        for (std::list<UDP*>::iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            delete *it;
        }
        _sockets.clear();
        _current = _sockets.begin();
    }

#ifdef LOGGER_OSTREAM
    std::ostream& active_interfaces(std::ostream& out)
    {
        if (! out)
            return out;

        // _lock must be help in read mode

        out << "Active interface(s):";
        for (std::list<UDP*>::const_iterator it = _sockets.begin();
             it != _sockets.end();
             ++it)
        {
            out << ' ' << (*it)->addr()->sin_addr;
            if (it == _current)
                out << '*';
        }

        return out;
    }
#endif

private:

    class Monitor
        : public TimerTask
    {
    public:

        Monitor(unsigned seconds, UDPBounded* that)
            : TimerTask(seconds, seconds)
            , _that(that)
        {}

    protected:

        virtual void execute()
        {
            (void) _that->refresh_sockets();
        }

    private:

        UDPBounded* _that;
    };

protected:

    INet::SockAddr _dest;

    mutable UpgradableRWLock _lock;

    // *** _sockets and _current must be guarded ***

    std::list<UDP*> _sockets;
    std::list<UDP*>::iterator _current;

private:

    Monitor _monitor;
};

#endif
