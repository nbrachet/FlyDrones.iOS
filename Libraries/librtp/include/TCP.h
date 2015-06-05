
#ifndef _TCP_H_
#define _TCP_H_

#include <netinet/tcp.h>

#include "Net.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                                TCP                                //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class TCP
    : public INet
{
public:

    static int resolve_sockaddr_in(struct sockaddr_in* addr,
                                   const char* host,
                                   unsigned port)
    {
        return INet::resolve_sockaddr_in(addr, host, port, SOCK_STREAM, IPPROTO_TCP);
    }

    static int resolve_sockaddr_in(SockAddr& sockaddr,
                                   const char* host,
                                   unsigned port)
    {
        struct sockaddr_in addr;
        int n = resolve_sockaddr_in(&addr, host, port);
        if (n == -1)
            return -1;
        sockaddr = addr;
        return 0;
    }

    int tcp_nodelay(bool set)
    {
        if (setsockopt(IPPROTO_TCP, TCP_NODELAY, set) == -1)
        {
            LOGGER_PERROR("setsockopt(TCP_NODELAY, %d)", set);
            return -1;
        }
        LOGGER_DEBUG("TCP_NODELAY = %d", set);
        return 0;
    }

#ifdef __linux__
    struct tcp_info info() const
    {
        struct tcp_info tcpi;
        memset(&tcpi, 0, sizeof(tcpi));
        if (getsockopt(IPPROTO_TCP, TCP_INFO, &tcpi) == -1)
            LOGGER_PWARN("getsockopt(TCP_INFO)");
        return tcpi;
    }

    ssize_t tcp_congestion(char* buffer, size_t len) const
    {
        socklen_t slen = len;
        if (::getsockopt(_sockfd, IPPROTO_TCP, TCP_CONGESTION, buffer, &slen) == -1)
        {
            LOGGER_PERROR("getsockopt(TCP_CONGESTION)");
            return -1;
        }
        return slen;
    }
#endif

protected:

    TCP()
        : INet(SOCK_STREAM, IPPROTO_TCP)
    {}

    TCP(int sockfd)
        : INet(sockfd)
    {}
};

    ///////////////////////////////////////////////////////////////////

#if defined(__linux__) && defined(LOGGER_OSTREAM)
std::ostream& operator<<(std::ostream& out, const struct tcp_info& tcpi)
{
    if (! out)
        return out;

                                                                        /* https://code.google.com/p/ndt/wiki/TCP_INFOvsWeb100Web10g */
    return out << "ca_state=" << (unsigned)tcpi.tcpi_ca_state           /* Congestion control state */
               << " retransmists=" << (unsigned)tcpi.tcpi_retransmits   /* Number of unrecovered [RTO] timeouts */
               << " probes=" << (unsigned)tcpi.tcpi_probes              /* Unanswered 0 window probes */
               << " backoff=" << (unsigned)tcpi.tcpi_backoff
               << " snd.wscale=" << (unsigned)tcpi.tcpi_snd_wscale      /* Window scaling received from sender */
               << " rcv.wscale=" << (unsigned)tcpi.tcpi_rcv_wscale      /* Window scaling to send to receiver */
               << " rto=" << tcpi.tcpi_rto                              /* Retransmit timeout */
               << " ato=" << tcpi.tcpi_ato                              /* Predicted tick of soft clock */
               << " snd.mss=" << tcpi.tcpi_snd_mss                      /* Cached effective mss, not including SACKS */
               << " rcv.mss=" << tcpi.tcpi_rcv_mss                      /* MSS used for delayed ACK decisions */
               << " unacked=" << tcpi.tcpi_unacked                      /* Packets which are "in flight" */
               << " sacked=" << tcpi.tcpi_sacked                        /* SACK'd packets */
               << " lost=" << tcpi.tcpi_lost                            /* Lost packets */
               << " retrans=" << tcpi.tcpi_retrans                      /* Retransmitted packets out */
               << " fackets=" << tcpi.tcpi_fackets                      /* FACK'd packets */
               << " last.data.sent=" << tcpi.tcpi_last_data_sent        /* now – lsndtime (lsndtime → timestamp of last sent data packet (for restart window)) */
//               << " last.ack.sent=" << tcpi.tcpi_last_ack_sent          /* Not remembered, sorry.  */
               << " last.data.recv=" << tcpi.tcpi_last_data_recv        /* now – isck_ack.lrcvtime (isck_ack ->Delayed ACK control data; lrcvtime → timestamp of last received data packet) */
               << " last.ack.recv=" << tcpi.tcpi_last_ack_recv          /* now - rcv_tstamp  (rcv_tstamp → timestamp of last received ACK (for keepalives)) */
               << " pmtu=" << tcpi.tcpi_pmtu                            /* Last pmtu seen by socket (Path Maximum Transmission Unit) */
               << " rcv.ssthresh=" << tcpi.tcpi_rcv_ssthresh            /* slow start size threshold for receiving (Current window clamp) */
               << " rtt=" << tcpi.tcpi_rtt                              /* Smoothed Round Trip Time (SRTT) */
               << " rttvar=" << tcpi.tcpi_rttvar                        /* Medium deviation */
               << " snd.ssthresh=" << tcpi.tcpi_snd_ssthresh            /* Slow start size threshold for sending */
               << " snd.cwnd=" << tcpi.tcpi_snd_cwnd                    /* Sending congestion window */
               << " advmss=" << tcpi.tcpi_advmss                        /* Advertised Maximum Segment Size (MSS) */
               << " reordering=" << tcpi.tcpi_reordering                /* Indicates the amount of reordering. Packet reordering metric */
               << " rcv.rtt=" << tcpi.tcpi_rcv_rtt                      /* Receiver side RTT estimation */
               << " rcv.rcv_space=" << tcpi.tcpi_rcv_space              /* Receiver queue space */
               << " total.retrans=" << tcpi.tcpi_total_retrans;         /* Total retransmits for entire connection */
}
#endif

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                          TCPConnection                            //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class TCPConnection
    : public TCP
{
protected:

    friend class TCPServer;

    TCPConnection(int sockfd,
                  const struct sockaddr_in* peeraddr)
        : TCP(sockfd)
    {
        this->peeraddr(peeraddr);
    }

public:

    TCPConnection()
    {
        peeraddr(NULL);
    }

    int close()
    {
        if (_sockfd == -1)
            return 0;

        if (TCP::close() == -1)
            return -1;
        LOGGER_DEBUG("Disconnection from %s:%u", peername(), peerport());
        return 0;
    }

    int connect(const struct sockaddr_in* peeraddr)
    {
        this->peeraddr(peeraddr);
        if (::connect(_sockfd, (struct sockaddr*)peeraddr, sizeof(*peeraddr)) == -1)
        {
            LOGGER_PERROR("connect(%s:%u)", peername(), peerport());
            this->peeraddr(NULL);
            return -1;
        }
        LOGGER_DEBUG("Connected to %s:%u", peername(), peerport());
        return 0;
    }

    int connect_async(const struct sockaddr_in* peeraddr)
    {
        this->peeraddr(peeraddr);
        if (::connect(_sockfd, (struct sockaddr*)peeraddr, sizeof(*peeraddr)) == -1)
        {
            if (LIKELY(errno != EINPROGRESS) && LIKELY(errno != EALREADY))
            {
                LOGGER_PERROR("connect(%s:%u)", peername(), peerport());
                this->peeraddr(NULL);
                return -1;
            }
        }
        LOGGER_DEBUG("Connecting to %s:%u", peername(), peerport());
        return 0;
    }

    int connect_async_complete(struct timeval* timeout = NULL)
    {
        if (! timeout || timeout->tv_sec > 0 || timeout->tv_usec > 0)
        {
            switch (wait_for_output(timeout))
            {
            case -1:
            case 0:     return -1;
            case 1:     break;
            default:    UNREACHABLE();
            }
        }

        int err = so_error();
        if (err != 0)
        {
            if (          err == ECONNREFUSED
                ||        err == ENETUNREACH
                ||        err == EHOSTUNREACH
                || LIKELY(err == ETIMEDOUT))
            {
                LOGGER_DEBUG("connect(%s:%u): %s", peername(), peerport(), strerror(err));
            }
            else
            {
                errno = err;
                LOGGER_PERROR("connect(%s:%u)", peername(), peerport());
                this->peeraddr(NULL);
            }
        }
        else
        {
#ifndef NDEBUG
            struct sockaddr_in sockaddr;
            socklen_t socklen = sizeof(sockaddr);
            if (::getpeername(_sockfd, (struct sockaddr*)&sockaddr, &socklen) == -1)
                LOGGER_PWARN("getpeername");
            else
                LOGGER_ASSERT(memcmp(&_peeraddr, &sockaddr, sizeof(_peeraddr)) == 0);
#endif

            LOGGER_DEBUG("Connected to %s:%u", peername(), peerport());
        }
        return err;
    }

    bool connected()
    {
        struct timeval notimeout = { 0, 0 };
        if (wait_for_output(&notimeout) != 1)
            return false;

        int err = so_error();
        if (err == -1)
            return false;

        errno = err;
        return err == 0;
    }

    const sockaddr_in* peeraddr() const
    {
        return _peeraddr.sin_family == AF_UNSPEC ? NULL : &_peeraddr;
    }

    const char* peername() const
    {
        return _peer;
    }

    unsigned peerport() const
    {
        return ntohs(_peeraddr.sin_port);
    }

    bool eof()
    {
        if (_sockfd == -1)
            return true;

        StashErrno stasherrno;

        int c;
        return recv(&c, 1, MSG_DONTWAIT | MSG_PEEK) == 0;
    }

    ssize_t recv(void* buffer, size_t buflen,
                 int flags,
                 struct timeval* timeout = NULL)
    {
        ssize_t n;
        for (;;)
        {
            if (timeout)
            {
                switch (wait_for_input(timeout))
                {
                case -1:
                case 0:     return -1;
                case 1:     break;
                default:    UNREACHABLE();
                }
            }

            n = ::recv(_sockfd, buffer, buflen - 1, flags | (timeout ? MSG_DONTWAIT : 0));
            if (n == -1)
            {
#ifndef NDEBUG
                // running inside the debugger causes EINTR
                if (errno == EINTR)
                    continue;
#endif
                if (errno == EAGAIN)
                {
                    if (BITMASK_ISSET(flags, MSG_DONTWAIT))
                        return -1;
                    if (! timeout || (timeout->tv_sec > 0 || timeout->tv_usec > 0))
                        continue;
                }

                LOGGER_PERROR("recv");
                return -1;
            }

            break;
        }

        LOGGER_DEBUG("recv: %'zd bytes", n);

        return n;
    }

    ssize_t recv(void** buffer, size_t buflen,
                 int flags,
                 struct timeval* timeout = NULL)
    {
        if (buflen == 0 || buflen > (size_t)so_rcvbuf())
            buflen = so_rcvbuf();

        *buffer = malloc(buflen);
        if (! *buffer)
            return -1;

        ssize_t read = recv(*buffer, buflen, flags, timeout);
        if (read <= 0)
        {
            free(*buffer); *buffer = NULL;
            return read;
        }

        *buffer = realloc(*buffer, read + 1);

        return read;
    }

    ssize_t recv_until(void** buffer, size_t buflen,
                       int flags,
                       const char* match, size_t matchlen)
    {
        if (buflen == 0 || buflen > (size_t)so_rcvbuf())
            buflen = so_rcvbuf();
        if (buflen <= matchlen)
            buflen = matchlen + 1;

        *buffer = realloc(*buffer, buflen);
        if (! *buffer)
            return -1;

        char* buf = (char*)*buffer;
        size_t read = 0;
        bool matched = false;
        while (read < buflen - 1)
        {
            ssize_t n = recv(buf + read, buflen - read, flags);
            if (n <= 0)
            {
                free(*buffer); *buffer = NULL;
                return n;
            }

            read += n;

            if (read > matchlen)
            {
                matched = true;
                for (size_t i = 0; i < matchlen; ++i)
                {
                    if (match[i] != buf[read - matchlen + i])
                    {
                        matched = false;
                        break;
                    }
                }
                if (matched)
                    break;
            }
        }

        if (! matched)
        {
            free(*buffer); *buffer = NULL;
            errno = EMSGSIZE;
            return -1;
        }

        *buffer = realloc(*buffer, read + 1);

        return read;
    }

    ssize_t read(void* buffer, size_t len,
                 struct timeval* timeout = NULL)
    {
        return recv(buffer, len, 0, timeout);
    }

    ssize_t write(const void* buf, size_t len)
    {
        return send(0, buf, len);
    }

    ssize_t send(int flags, const void* buf, size_t len)
    {
#if 0
fprintf(stderr, "> %*s", len, buf);
#endif

        const ssize_t n = ::send(_sockfd, buf, len, flags | MSG_NOSIGNAL);
        if (n == -1)
        {
            LOGGER_PERROR("send");

#if defined(__linux__) && defined(LOGGER_OSTREAM)
            if (LOGGER_IS_INFO())
            {
                LOGGER_OINFO(cinfo) << info();
            }
#endif
#ifdef SIOCOUTQ
            if (LOGGER_IS_INFO())
            {
                const int outq = siocoutq();
                if (outq > 0)
                    LOGGER_INFO("SIOCOUTQ = %'i B", outq);
            }
#endif
        }
        return n;
    }

    ssize_t sendv(int flags, const char* fmt, ...)
        __attribute__((__format__(__printf__, 3, 4)))
    {
        va_list ap;
        va_start(ap, fmt);
        ssize_t s = sendva(flags, fmt, ap);
        va_end(ap);
        return s;
    }

    ssize_t sendva(int flags, const char* fmt, va_list ap)
        __attribute__((__format__(__printf__, 3, 0)))
    {
        char* buf;
        int n = vasprintf(&buf, fmt, ap);
        if (n == -1)
        {
            LOGGER_PERROR("vasprintf(%s)", fmt);
            return -1;
        }

        ssize_t sent = send(flags, buf, n);
        free(buf);
        return sent;
    }

private:

    void peeraddr(const struct sockaddr_in* peeraddr)
    {
        if (peeraddr != NULL)
        {
            memcpy(&_peeraddr, peeraddr, sizeof(_peeraddr));

#ifndef NDEBUG
            LOGGER_ASSERT(_sockfd != -1);
            struct sockaddr_in sockaddr;
            socklen_t socklen = sizeof(sockaddr);
            if (::getpeername(_sockfd, (struct sockaddr*)&sockaddr, &socklen) == -1)
            {
                if (errno != ENOTCONN) // in case of async connect
                    LOGGER_PWARN("getpeername");
            }
            else
            {
                LOGGER_ASSERT(memcmp(&_peeraddr, &sockaddr, sizeof(_peeraddr)) == 0);
            }
#endif
        }
        else if (_sockfd != -1)
        {
            socklen_t socklen = sizeof(_peeraddr);
            if (::getpeername(_sockfd, (struct sockaddr*)&_peeraddr, &socklen) == -1)
            {
                if (errno != ENOTCONN)
                    LOGGER_PWARN("getpeername");
                memset(&_peeraddr, 0, sizeof(_peeraddr));
            }
        }
        else
        {
            memset(&_peeraddr, 0, sizeof(_peeraddr));
        }

        if (_peeraddr.sin_family == AF_INET)
        {
            if (inet_ntop(_peeraddr.sin_family, &_peeraddr.sin_addr, _peer, sizeof(_peer)) == NULL)
            {
                LOGGER_PWARN("inet_ntop");
                _peer[0] = '\0';
            }
        }
        else
        {
            _peer[0] = '\0';
        }
    }

private:

    sockaddr_in _peeraddr;
    char _peer[INET_ADDRSTRLEN];
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                            TCPServer                              //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class TCPServer
    : public TCP
{
public:

    TCPServer()
        : TCP()
    {}

    int listen(int backlog)
    {
        if (::listen(_sockfd, backlog) == -1)
        {
            LOGGER_PERROR("listen(%d)", backlog);
            return -1;
        }

        LOGGER_DEBUG("Listening on %s:%u", name(), port());
        return 0;
    }

    TCPConnection* accept()
    {
        struct sockaddr_in clntaddr;
        socklen_t socklen = sizeof(clntaddr);
        int fd = ::accept(_sockfd, (struct sockaddr*) &clntaddr, &socklen);
        if (fd == -1)
        {
            LOGGER_PERROR("accept");
            return NULL;
        }
        LOGGER_ASSERT1(socklen == sizeof(clntaddr), socklen);

        TCPConnection* client = newConnection(fd, &clntaddr);

        LOGGER_DEBUG("Connection from %s:%u to %s:%u",
                     client->peername(), client->peerport(),
                     client->name(), client->port());

        return client;
    }

protected:

    virtual TCPConnection* newConnection(int sockfd, const struct sockaddr_in* peeraddr) const
    {
        return new TCPConnection(sockfd, peeraddr);
    }
};

#endif
