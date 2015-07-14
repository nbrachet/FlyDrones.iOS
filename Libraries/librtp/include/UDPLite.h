
#ifndef _UDP_LITE_H_
#define _UDP_LITE_H_

#include "UDP.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             UDPLite                               //
//                                                                   //
///////////////////////////////////////////////////////////////////////

#ifdef IPPROTO_UDPLITE

class UDPLiteSender
    : public DatagramSender
{
public:

    UDPLiteSender(const struct sockaddr_in* dest)
        : Datagram(IPPROTO_UDPLITE)
        , DatagramSender(IPPROTO_UDPLITE, dest)
    {}
};

class UDPLiteReceiver
    : public DatagramReceiver
{
public:

    UDPLiteReceiver()
        : Datagram(IPPROTO_UDPLITE)
        , DatagramReceiver(IPPROTO_UDPLITE)
    {}
};

class UDPLite
    : public UDPLiteSender, public UDPLiteReceiver
{
public:

    static int resolve_sockaddr_in(struct sockaddr_in* addr,
                                   const char* host,
                                   unsigned port)
    {
        return INet::resolve_sockaddr_in(addr, host, port, SOCK_DGRAM, IPPROTO_UDPLITE);
    }

    UDPLite(const struct sockaddr_in* dest)
        : Datagram(IPPROTO_UDPLITE)
        , UDPLiteSender(dest)
        , UDPLiteReceiver()
    {}

    int cscov(uint16_t cscov)
    {
#if defined(UDPLITE_SEND_CSCOV) && defined(UDPLITE_RECV_CSCOV)
        if (cscov != 0 && cscov < sizeof(struct udphdr))
            cscov = sizeof(struct udphdr);

        int ccscov;
        if (getsockopt(IPPROTO_UDPLITE, UDPLITE_SEND_CSCOV, &ccscov) == -1)
            return -1;

        int icscov = cscov;
        if (setsockopt(IPPROTO_UDPLITE, UDPLITE_SEND_CSCOV, icscov) == -1)
            return -1;
        if (setsockopt(IPPROTO_UDPLITE, UDPLITE_RECV_CSCOV, icscov) == -1)
        {
            int save_errno = errno;
            (void) setsockopt(IPPROTO_UDPLITE, UDPLITE_SEND_CSCOV, ccscov);
            errno = save_errno;
            return -1;
        }

        LOGGER_DEBUG("CSCOV = %'hu", cscov);
#endif

        return 0;
    }
};

#endif

#endif
