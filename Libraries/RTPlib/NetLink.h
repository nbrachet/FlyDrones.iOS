
#ifndef _NET_LINK_H_
#define _NET_LINK_H_

#include <arpa/inet.h>

#include <string.h>
#include <unistd.h>

#ifdef __linux__
#  include <linux/netlink.h>
#  include <linux/rtnetlink.h>
#elif defined(__APPLE__)
#  include <TargetConditionals.h>

#  if !TARGET_OS_IPHONE
#    include <net/route.h>
#  endif
#endif

#include "Net.h"
#include "Logger.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             NetLink                               //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class NetLink
    : public Socket
{
public:

#ifdef __linux__

    NetLink()
        : Socket(socket(AF_NETLINK, SOCK_RAW, NETLINK_ROUTE))
    {
        if (_sockfd == -1)
            LOGGER_PERROR("socket(AF_NETLINK, SOCK_RAW, NETLINK_ROUTE)");
    }

    in_addr_t get_if_addr(const struct sockaddr_in& target)
    {
        in_addr_t addr;
        if (getroute(target,
                     RTA_PREFSRC,
                     &addr, sizeof(addr)) <= 0)
        {
            char t[INET_ADDRSTRLEN];
            if (inet_ntop(target.sin_family, &target.sin_addr, t, sizeof(t)) != NULL)
                LOGGER_ERROR("get_if_addr failed");
            else
                LOGGER_ERROR("get_if_addr(%s) failed", t);
            return INADDR_NONE;
        }
        if (LOGGER_IS_DEBUG())
        {
            char t[INET_ADDRSTRLEN];
            char d[INET_ADDRSTRLEN];
            if (inet_ntop(target.sin_family, &target.sin_addr, t, sizeof(t)) != NULL
                && inet_ntop(target.sin_family, &addr, d, sizeof(d)) != NULL)
            {
                LOGGER_DEBUG("get_if_addr(%s) = %s", t, d);
            }
        }
        return addr;
    }

private:

    ssize_t getroute(const struct sockaddr_in& target,
                     unsigned short rta_type,
                     void* data,
                     unsigned short datalen);

#elif defined(__APPLE__) && !defined(TARGET_OS_IPHONE)

    NetLink()
        : Socket(socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC))
    {
        if (_sockfd == -1)
            LOGGER_PERROR("socket(PF_ROUTE, SOCK_RAW_AF_UNSPEC)");
        else
            errno = 0;
    }

    in_addr_t get_if_addr(const struct sockaddr_in& target);

private:

    static size_t roundup(size_t x, size_t y)
    {
        return ((x + y - 1) / y) * y;
    }

#else

    NetLink()
    {}

    in_addr_t get_if_addr(const struct sockaddr_in& target)
    {
        return INADDR_NONE;
    }

#endif

private:

    static const uint32_t pid;
    static uint32_t seq;
};

#endif
