
#ifndef _SCTP_H_
#define _SCTP_H_

#include "Net.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                               SCTP                                //
//                                                                   //
///////////////////////////////////////////////////////////////////////

#ifdef IPPROTO_SCTP

class SCTPSeqPacket
    : public INet
{
public:

    static int resolve_sockaddr_in(struct sockaddr_in* addr,
                                   const char* host,
                                   unsigned port)
    {
        return INet::resolve_sockaddr_in(addr, host, port, SOCK_SEQPACKET, IPPROTO_SCTP);
    }

    SCTPSeqPacket()
        : INet(SOCK_SEQPACKET, IPPROTO_SCTP)
    {}

    SCTPSeqPacket(const struct sockaddr_in* dest)
        : INet(SOCK_SEQPACKET, IPPROTO_SCTP)
        , _dest(dest)
    {}

    virtual ssize_t send(const void* buffer, size_t buflen,
                         int flags,
                         struct timeval* timeout = NULL,
                         const struct sockaddr_in* dest = NULL)
    {
        struct iovec iovec;
        iovec.iov_base = const_cast<void*>(buffer);
        iovec.iov_len = buflen;
        return sendv(&iovec, 1, flags, timeout, dest);
    }

    virtual ssize_t sendv(struct iovec* iov, unsigned iovcnt,
                          int flags,
                          struct timeval* timeout = NULL,
                          const struct sockaddr_in* dest = NULL)
    {
        struct msghdr msg;
        memset(&msg, 0, sizeof(msg));
        msg.msg_name = dest ? (void*)dest : (void*)_dest.addr();
        msg.msg_namelen = sizeof(struct sockaddr_in);
        msg.msg_iov = const_cast<struct iovec*>(iov);
        msg.msg_iovlen = iovcnt;

        if (timeout)
        {
            switch (wait_for_output(timeout))
            {
            case -1:
            case 0:     return -1;
            case 1:     break;
            default:    UNREACHABLE();
            }
        }

        const ssize_t n = ::sendmsg(_sockfd, &msg, flags | (timeout ? MSG_DONTWAIT : 0));
        if (n == -1)
            LOGGER_PERROR("sendmsg");
        return n;
    }

    virtual ssize_t recv(void* buffer, size_t buflen,
                         int flags,
                         struct timeval* timeout = NULL,
                         struct sockaddr_in* src = NULL)
    {
        struct iovec iov;
        iov.iov_base = buffer;
        iov.iov_len = buflen;
        return recvv(&iov, 1, flags, timeout, src);
    }

    virtual ssize_t recvv(struct iovec* iov, unsigned iovcnt,
                          int flags,
                          struct timeval* timeout = NULL,
                          struct sockaddr_in* src = NULL)
    {
        struct msghdr msg;
        memset(&msg, 0, sizeof(msg));
        if (src)
        {
            msg.msg_name = src;
            msg.msg_namelen = sizeof(struct sockaddr_in);
        }
        msg.msg_iov = iov;
        msg.msg_iovlen = iovcnt;

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

            const ssize_t n = ::recvmsg(_sockfd, &msg, flags | (timeout ? MSG_DONTWAIT : 0));
            if (n == -1)
            {
#ifndef NDEBUG
                // running inside the debugger causes EINTR
                if (errno == EINTR)
                    continue;
#endif
                if (errno == EWOULDBLOCK)
                {
                    if (BITMASK_ISSET(flags, MSG_DONTWAIT))
                        return -1;
                    if (! timeout || (timeout->tv_sec > 0 || timeout->tv_usec > 0))
                        continue;
                }
                LOGGER_PERROR("recvmsg");
                return -1;
            }

            if (BITMASK_ISSET(msg.msg_flags, MSG_TRUNC) && ! BITMASK_ISSET(flags, MSG_TRUNC))
            {
                LOGGER_WARN("Received msg is truncated");
                continue;
            }

            return n;
        }
        UNREACHABLE();
    }

    virtual ssize_t /*Socket::*/ write(const void* buffer, size_t buflen,
                                       struct timeval* timeout = NULL)
    {
        return send(buffer, buflen, 0, timeout);
    }

    virtual ssize_t /*Socket::*/ writev(struct iovec* iov, unsigned iovcnt,
                                        struct timeval* timeout = NULL)
    {
        return sendv(iov, iovcnt, 0, timeout);
    }

    virtual ssize_t /*Socket::*/ read(void* buffer, size_t buflen,
                                      struct timeval* timeout = NULL)
    {
        return recv(buffer, buflen, 0, timeout);
    }

    virtual ssize_t /*Socket::*/ readv(struct iovec* iov, unsigned iovcnt,
                                       struct timeval* timeout = NULL)
    {
        return recvv(iov, iovcnt, 0, timeout);
    }

private:

    SockAddr _dest;
};

#endif

#endif
