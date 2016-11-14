
#ifndef _ICMP_H_
#define _ICMP_H_

/* C99 requires that stdint.h only exposes UINT16_MAX if this is defined: */
#ifndef __STDC_LIMIT_MACROS
#  define __STDC_LIMIT_MACROS
#endif

#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/ip_icmp.h>

#ifdef __linux__
#elif defined(__APPLE__)
#  include <mach/clock.h>
#  include <mach/mach.h>
#  include <mach/mach_time.h>

#  define ICMP_DEST_UNREACH     ICMP_UNREACH
#  define ICMP_PORT_UNREACH     ICMP_UNREACH_PORT
#  define ICMP_TIME_EXCEEDED    ICMP_TIMXCEED
#endif

#include "Net.h"
#include "Logger.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                               ICMP                                //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class ICMP
    : public INet
{
public:

    static int resolve_sockaddr_in(struct sockaddr_in* addr,
                                   const char* host)
    {
        return INet::resolve_sockaddr_in(addr, host, 0, SOCK_RAW, IPPROTO_ICMP);
    }

    static const char* icmp_type(const struct icmp* p)
    {
        return icmp_type(p->icmp_type);
    }

    static const char* icmp_type(uint8_t type)
    {
        switch (type)
        {
#define DO(x)   case ICMP_##x: return #x;

#ifdef __linux__

        DO(ECHOREPLY)
        DO(DEST_UNREACH)
        DO(SOURCE_QUENCH)
        DO(REDIRECT)
        DO(ECHO)
        DO(TIME_EXCEEDED)
        DO(PARAMETERPROB)
        DO(TIMESTAMP)
        DO(TIMESTAMPREPLY)
        DO(INFO_REQUEST)
        DO(INFO_REPLY)
        DO(ADDRESS)
        DO(ADDRESSREPLY)

#elif defined(__APPLE__)

        DO(ECHOREPLY)
        DO(UNREACH)
        DO(SOURCEQUENCH)
        DO(REDIRECT)
        DO(ECHO)
        DO(ROUTERADVERT)
        DO(ROUTERSOLICIT)
        DO(TIMXCEED)
        DO(PARAMPROB)
        DO(TSTAMP)
        DO(TSTAMPREPLY)
        DO(IREQ)
        DO(IREQREPLY)
        DO(MASKREQ)
        DO(MASKREPLY)
        DO(TRACEROUTE)
        DO(DATACONVERR)
        DO(MOBILE_REDIRECT)
        DO(IPV6_WHEREAREYOU)
        DO(IPV6_IAMHERE)
        DO(MOBILE_REGREQUEST)
        DO(MOBILE_REGREPLY)
        DO(SKIP)
        DO(PHOTURIS)

#endif

#undef DO
        }
        return "RESERVED";
    }

    static const char* icmp_code(const struct icmp* p)
    {
        return icmp_code(p->icmp_type, p->icmp_code);
    }

    static const char* icmp_code(uint8_t type, uint8_t code)
    {
        switch (type)
        {
#define DO(x)       case ICMP_##x: return #x;

#ifdef __linux__

        case ICMP_DEST_UNREACH:
            switch (code)
            {
            DO(NET_UNREACH)
            DO(HOST_UNREACH)
            DO(PROT_UNREACH)
            DO(PORT_UNREACH)
            DO(FRAG_NEEDED)
            DO(SR_FAILED)
            DO(NET_UNKNOWN)
            DO(HOST_UNKNOWN)
            DO(HOST_ISOLATED)
            DO(NET_ANO)
            DO(HOST_ANO)
            DO(NET_UNR_TOS)
            DO(HOST_UNR_TOS)
            DO(PKT_FILTERED)
            DO(PREC_VIOLATION)
            DO(PREC_CUTOFF)
            }
            break;

        case ICMP_REDIRECT:
            switch (code)
            {
            DO(REDIR_NET)
            DO(REDIR_HOST)
            DO(REDIR_NETTOS)
            DO(REDIR_HOSTTOS)
            }
            break;

        case ICMP_TIME_EXCEEDED:
            switch (code)
            {
            DO(EXC_TTL)
            DO(EXC_FRAGTIME)
            }
            break;

#elif defined(__APPLE__)

        case ICMP_UNREACH:
            switch (code)
            {
            DO(UNREACH_NET)
            DO(UNREACH_HOST)
            DO(UNREACH_PROTOCOL)
            DO(UNREACH_PORT)
            DO(UNREACH_NEEDFRAG)
            DO(UNREACH_SRCFAIL)
            DO(UNREACH_NET_UNKNOWN)
            DO(UNREACH_HOST_UNKNOWN)
            DO(UNREACH_ISOLATED)
            DO(UNREACH_NET_PROHIB)
            DO(UNREACH_HOST_PROHIB)
            DO(UNREACH_TOSNET)
            DO(UNREACH_TOSHOST)
            DO(UNREACH_FILTER_PROHIB)
            DO(UNREACH_HOST_PRECEDENCE)
            DO(UNREACH_PRECEDENCE_CUTOFF)
            }
            break;

        case ICMP_REDIRECT:
            switch (code)
            {
            DO(REDIRECT_NET)
            DO(REDIRECT_HOST)
            DO(REDIRECT_TOSNET)
            DO(REDIRECT_TOSHOST)
            }
            break;

        case ICMP_ROUTERADVERT:
            switch (code)
            {
            DO(ROUTERADVERT_NORMAL)
            DO(ROUTERADVERT_NOROUTE_COMMON)
            }
            break;

        case ICMP_TIMXCEED:
            switch (code)
            {
            DO(TIMXCEED_INTRANS)
            DO(TIMXCEED_REASS)
            }
            break;

        case ICMP_PARAMPROB:
            switch (code)
            {
            DO(PARAMPROB_ERRATPTR)
            DO(PARAMPROB_OPTABSENT)
            DO(PARAMPROB_LENGTH)
            }
            break;

        case ICMP_PHOTURIS:
            switch (code)
            {
            DO(PHOTURIS_UNKNOWN_INDEX)
            DO(PHOTURIS_AUTH_FAILED)
            DO(PHOTURIS_DECRYPT_FAILED)
            }
            break;

#endif

#undef DO
        }
        return "";
    }

    static int timestamp(struct timespec* ts)
    {
#ifdef SO_TIMESTAMP_MONOTONIC
        // see https://developer.apple.com/library/mac/qa/qa1398/_index.html
        static mach_timebase_info_data_t sTimebaseInfo;
        if (sTimebaseInfo.denom == 0)
            (void) mach_timebase_info(&sTimebaseInfo);

        uint64_t ns = mach_absolute_time() * sTimebaseInfo.numer / sTimebaseInfo.denom;
        ts->tv_sec = ns / NANOSEC;
        ts->tv_nsec = ns % NANOSEC;
        return 0;
#else // defined(SO_TIMESTAMPING) || defined(SO_TIMESTAMPNS) || defined(SO_TIMESTAMP)
        if (clock_gettime(CLOCK_REALTIME, ts) == -1)
            LOGGER_PERROR("clock_gettime(CLOCK_REALTIME)");
        return 0;
#endif
    }

public:

    ICMP()
        : INet(SOCK_RAW, IPPROTO_ICMP)
    {
        if (! *this)
            return;

#ifdef SO_TIMESTAMPING
        int on = SOF_TIMESTAMPING_RX_HARDWARE
               | SOF_TIMESTAMPING_RX_SOFTWARE
               | SOF_TIMESTAMPING_SYS_HARDWARE
               | SOF_TIMESTAMPING_SOFTWARE;
        if (setsockopt(SOL_SOCKET, SO_TIMESTAMPING, &on) == -1)
            LOGGER_PWARN("setsockopt(SO_TIMESTAMPING)");

#  if 0
        struct hwtstamp_config hwconfig;
        memset(&hwconfig, 0, sizeof(hwconfig));
        hwconfig.tx_type = HWTSTAMP_TX_OFF;
        hwconfig.rx_filter = HWTSTAMP_FILTER_ALL;

        struct ifreq ifr;
        memset(&ifr, 0, sizeof(ifr));
        strncpy(ifr.ifr_name, argv[3], sizeof(ifr.ifr_name));
        ifr.ifr_data = (caddr_t)&hwconfig;
        if (ioctl(s, SIOCSHWTSTAMP, &ifr) == -1)
            LOGGER_PWARN("ioctl(SIOCSHWTSTAMP)");
#  endif
#elif defined(SO_TIMESTAMP_MONOTONIC)
        if (setsockopt(SOL_SOCKET, SO_TIMESTAMP_MONOTONIC, 1) == -1)
            LOGGER_PWARN("setsockopt(SO_TIMESTAMP_MONOTONIC)");
#elif defined(SO_TIMESTAMPNS)
        if (setsockopt(SOL_SOCKET, SO_TIMESTAMPNS, 1) == -1)
            LOGGER_PWARN("setsockopt(SO_TIMESTAMPNS)");
#elif defined(SO_TIMESTAMP)
        if (setsockopt(SOL_SOCKET, SO_TIMESTAMP, 1) == -1)
            LOGGER_PWARN("setsockopt(SO_TIMESTAMP)");
#endif
    }

    ssize_t send(struct icmp* icmp, size_t nbytes,
                 int flags,
                 const struct sockaddr_in* target)
    {
        LOGGER_ASSERT1(sizeof(struct icmp) <= nbytes && nbytes < IP_MAXPACKET - sizeof(struct ip), nbytes);

        const ssize_t n = ::sendto(_sockfd,
                                   icmp, nbytes,
                                   flags,
                                   (struct sockaddr*)target, sizeof(*target));
        if (n == -1)
        {
            LOGGER_PERROR("sendto");
            return -1;
        }
        if ((size_t)n != nbytes)
            LOGGER_WARN("sendto: %'zd != %'zd", n, nbytes);

        return n + sizeof(struct ip);
    }

    ssize_t recv(struct icmp* icmp, size_t nbytes,
                 int flags,
                 struct timespec* ts,
                 struct sockaddr_in* peer)
    {
        SockAddr from;

        struct msghdr msg;
        memset(&msg, 0, sizeof(msg));
        msg.msg_name = from.addr();
        msg.msg_namelen = from.addrlen();
        msg.msg_iov = reinterpret_cast<struct iovec*>(alloca(sizeof(struct iovec) * 2));
        msg.msg_iovlen = 2;
        msg.msg_iov[0].iov_base = alloca(sizeof(struct ip));
        msg.msg_iov[0].iov_len = sizeof(struct ip);
        msg.msg_iov[1].iov_base = icmp;
        msg.msg_iov[1].iov_len = nbytes;
#ifdef SO_TIMESTAMPING
        msg.msg_controllen = CMSG_SPACE(sizeof(struct scm_timestamping));
#elif defined(SO_TIMESTAMP_MONOTONIC)
        msg.msg_controllen = CMSG_SPACE(sizeof(uint64_t));
#elif defined(SO_TIMESTAMPNS)
        msg.msg_controllen = CMSG_SPACE(sizeof(struct timespec));
#elif defined(SO_TIMESTAMP)
        msg.msg_controllen = CMSG_SPACE(sizeof(struct timeval));
#endif
        msg.msg_control = reinterpret_cast<caddr_t>(alloca(msg.msg_controllen));

        ssize_t n = ::recvmsg(_sockfd, &msg, flags);
        if (n == -1)
        {
            LOGGER_PERROR("recvmsg");
            return -1;
        }

        if ((size_t)n < sizeof(struct ip) + ICMP_MINLEN)
        {
            LOGGER_WARN("recvmsg: message too short: %zd < %zu", n, sizeof(struct ip) + ICMP_MINLEN);
            return 0;
        }
        if (BITMASK_ISSET(msg.msg_flags, MSG_CTRUNC))
            LOGGER_WARN("recvmsg: MSG_CTRUNC");

        const struct ip* ip = reinterpret_cast<const struct ip*>(msg.msg_iov[0].iov_base);
        if (ip->ip_v != IPVERSION)
        {
            LOGGER_WARN("Ignore IP message: ip_v (%d) != %d", ip->ip_v, IPVERSION);
            return 0;
        }
#ifndef NDEBUG
        if (ip->ip_sum != 0)
        {
            const uint16_t cksum = Checksum::ip(ip);
            if (cksum != 0)
            {
                LOGGER_WARN("Ignore IP message: checksum mismatch");
                return 0;
            }
        }
#endif
        if (ip->ip_p != IPPROTO_ICMP)
        {
            LOGGER_WARN("Ignore IP message: not ICMP (%d)", ip->ip_p);
            return 0;
        }
        if (BITMASK_ISSET(ip->ip_off, IP_MF) && (ip->ip_off & IP_OFFMASK) != 0)
        {
            LOGGER_DEBUG("Ignore ICMP message: fragment");
            return 0;
        }

#ifndef __APPLE__
        const uint16_t ip_len = ntohs(ip->ip_len);
#else
        const uint16_t ip_len = ip->ip_len // __APPLE__ already byte-swaps ip_len
                              + (ip->ip_hl << 2); // and removes ip_hl
#endif
        if (n < ip_len)
            LOGGER_DEBUG("ICMP message truncated: %zu+%zd/%zu < ip_len (%zu+%zu)", sizeof(struct ip), n - sizeof(struct ip), nbytes, sizeof(struct ip), ip_len - sizeof(struct ip));
        else if (n > ip_len)
            LOGGER_WARN("%zd > ip_len (%hu)", n, ip_len);

        size_t ip_hl = ip->ip_hl << 2;
        if (ip_hl < sizeof(struct ip))
        {
            LOGGER_WARN("Ignore ICMP message: IP header too small: %zd", ip_hl);
            return 0;
        }
        if ((size_t)n < ip_hl + ICMP_MINLEN)
        {
            LOGGER_WARN("Ignore ICMP message: too short %zd < %zu+%u", n, ip_hl, ICMP_MINLEN);
            return 0;
        }

        if (ip_hl > sizeof(struct ip))
        {
            // IP options have been received in msg.msg_iov[1] aka icmp
            // remove them
            void* p = reinterpret_cast<uint8_t*>(msg.msg_iov[1].iov_base) + ip_hl;
            memmove(icmp, p, n - ip_hl + sizeof(struct ip));
            n -= ip_hl - sizeof(struct ip);
            ip_hl = sizeof(struct ip);
        }

#ifndef NDEBUG
        if (ip_len == n && icmp->icmp_cksum != 0)
        {
            const uint16_t cksum = Checksum::icmp(icmp, n - ip_hl);
            if (cksum != 0)
            {
                LOGGER_WARN("Ignore ICMP message: checksum mismatch");
                return 0;
            }
        }
#endif

        if (LOGGER_IS_DEBUG())
        {
            const char* type = icmp_type(icmp);
            const char* code = icmp_code(icmp);
            LOGGER_DEBUG("ICMP [%s%s%s]: %'zd/%'hu bytes from %s", type, code[0] == '\0' ? "" : " ", code, n, ip_len, from.ascii());
        }

        LOGGER_ASSERT2(from.s_addr() == ip->ip_src.s_addr, from.ascii(), Addr(ip->ip_src).ascii());

        const uint8_t type = icmp->icmp_type;
        if (type == ICMP_TIME_EXCEEDED || type == ICMP_DEST_UNREACH)
        {
            const struct ip* sub_ip = reinterpret_cast<const struct ip*>(&icmp->icmp_ip);
            const size_t sub_n = n - (reinterpret_cast<const uint8_t*>(sub_ip) - reinterpret_cast<const uint8_t*>(ip));
            if (sub_n < sizeof(struct ip) + 8)
            {
                LOGGER_WARN("Ignore ICMP message: sub-message too short: %zu < %zu", sub_n, sizeof(struct ip) + 8);
                return 0;
            }

            const unsigned sub_ip_hl = sub_ip->ip_hl << 2;
            if (sub_ip_hl > (size_t)sub_n - 8)
            {
                LOGGER_WARN("Ignore ICMP message: sub-IP header too large: %zd", sub_ip_hl);
                return 0;
            }
        }

        if (ts)
        {
            ts->tv_sec = 0;
            ts->tv_nsec = 0;

#ifdef SO_TIMESTAMPING
            for (struct cmsghdr* cmsg = CMSG_FIRSTHDR(&msg);
                 cmsg != NULL;
                 cmsg = CMSG_NXTHDR(&msg, cmsg))
            {
                if (   cmsg->cmsg_level == SOL_SOCKET
                    && cmsg->cmsg_type == SCM_TIMESTAMPING
                    && cmsg->cmsg_len >= CMSG_LEN(sizeof(struct scm_timestamping)))
                {
                    struct scm_timestamping t;
                    memcpy(&t, CMSG_DATA(cmsg), sizeof(struct scm_timestamping));

                    if (t.ts[0].tv_sec > 0 || t.ts[0].tv_nsec > 0) // systime
                    {
                        *ts = t.ts[0];
                        break;
                    }
                    else if (t.ts[2].tv_sec > 0 || t.ts[2].tv_nsec > 0) // hwtimeraw
                    {
                        *ts = t.ts[2];
                        break;
                    }
                    else if (t.ts[1].tv_sec > 0 || t.ts[1].tv_nsec > 0) // hwtimetrans
                    {
                        *ts = t.ts[1];
                        break;
                    }
                }
            }
#elif defined(SO_TIMESTAMP_MONOTONIC)
            for (struct cmsghdr* cmsg = CMSG_FIRSTHDR(&msg);
                 cmsg != NULL;
                 cmsg = CMSG_NXTHDR(&msg, cmsg))
            {
                if (   cmsg->cmsg_level == SOL_SOCKET
                    && cmsg->cmsg_type == SCM_TIMESTAMP_MONOTONIC
                    && cmsg->cmsg_len >= CMSG_LEN(sizeof(uint64_t)))
                {
                    uint64_t t;
                    memcpy(&t, CMSG_DATA(cmsg), sizeof(uint64_t));
                    ts->tv_sec = t / NANOSEC;
                    ts->tv_nsec = t % NANOSEC;
                    break;
                }
            }
#elif defined(SO_TIMESTAMPNS)
            for (struct cmsghdr* cmsg = CMSG_FIRSTHDR(&msg);
                 cmsg != NULL;
                 cmsg = CMSG_NXTHDR(&msg, cmsg))
            {
                if (   cmsg->cmsg_level == SOL_SOCKET
                    && cmsg->cmsg_type == SCM_TIMESTAMPNS
                    && cmsg->cmsg_len >= CMSG_LEN(sizeof(struct timespec)))
                {
                    memcpy(ts, CMSG_DATA(cmsg), sizeof(struct timespec));
                    break;
                }
            }
#elif defined(SO_TIMESTAMP)
            for (struct cmsghdr* cmsg = CMSG_FIRSTHDR(&msg);
                 cmsg != NULL;
                 cmsg = CMSG_NXTHDR(&msg, cmsg))
            {
                if (   cmsg->cmsg_level == SOL_SOCKET
                    && cmsg->cmsg_type == SCM_TIMESTAMP
                    && cmsg->cmsg_len >= CMSG_LEN(sizeof(struct timeval)))
                {
                    struct timeval t;
                    memcpy(&t, CMSG_DATA(cmsg), sizeof(struct timeval));
                    ts->tv_sec = t->tv_sec;
                    ts->tv_nsec = t->tv_usec * 1000;
                    break;
                }
            }
#endif
        }

        if (peer)
            from.copy(peer);

        return n - sizeof(struct ip);
    }

    ssize_t icmp_reply(struct icmp* icmp, size_t bufsiz,
                       int flags,
                       struct timespec* ts,
                       struct sockaddr_in* peer,
                       const struct timeval* waittime = NULL)
    {
        LOGGER_ASSERT1(icmp->icmp_type == ICMP_ECHO, icmp_type(icmp));
        const uint16_t id0 = icmp->icmp_id;
        const uint16_t seq0 = icmp->icmp_seq;

        struct timeval timeout;
        if (waittime)
            timeout = *waittime;
        for (;;)
        {
            const int w = wait_for_input(waittime ? &timeout : NULL);
            if (w <= 0)
                return -1;

            const ssize_t n = recv(icmp, bufsiz, flags | MSG_DONTWAIT, ts, peer);
            if (n == -1)
            {
                if (errno == EWOULDBLOCK)
                    continue;
                return -1;
            }
            if (n == 0)
                continue;

            const uint8_t type = icmp->icmp_type;
            if (type == ICMP_TIME_EXCEEDED || type == ICMP_DEST_UNREACH)
            {
                const struct ip* sub_ip = reinterpret_cast<const struct ip*>(&icmp->icmp_ip);

                if (sub_ip->ip_p != IPPROTO_ICMP)
                {
                    LOGGER_DEBUG("Ignore ICMP message: outgoing packet wasn't ICMP but %hhu", sub_ip->ip_p);
                    return 0;
                }

                const unsigned sub_ip_hl = sub_ip->ip_hl << 2;
                const struct icmp* sub_icmp = reinterpret_cast<const struct icmp*>(reinterpret_cast<const uint8_t*>(sub_ip) + sub_ip_hl);
                if (sub_icmp->icmp_type != ICMP_ECHO)
                {
                    LOGGER_WARN("Ignore ICMP message: not ECHO (%s)", icmp_type(sub_icmp));
                    continue;
                }
                if (sub_icmp->icmp_id != id0)
                {
                    LOGGER_WARN("Ignore ICMP message: not my ident");
                    return 0;
                }
                if (sub_icmp->icmp_seq != seq0)
                {
                    LOGGER_WARN("Ignore ICMP message: not my sequence (%hu != %hu)", seq0, sub_icmp->icmp_seq);
                    continue;
                }
            }
            else if (type == ICMP_ECHOREPLY)
            {
                if (icmp->icmp_id != id0)
                {
                    LOGGER_WARN("Ignore ICMP message: not my ident");
                    return 0;
                }
                if (icmp->icmp_seq != seq0)
                {
                    LOGGER_WARN("Ignore ICMP message: not my sequence (%hu != %hu)", seq0, icmp->icmp_seq);
                    continue;
                }
            }
            else
            {
                LOGGER_WARN("Ignore ICMP message: not ECHOREPLY (%s)", icmp_type(icmp));
                continue;
            }

            return n;
        }
        UNREACHABLE();
        return 0;
    }

    /**
     * @return -1 on error.
     *         <code>len</code> on success. In that case <code>from</code>
     *                                      and <code>timeus</code>
     *                                      will contain (resp.)
     *                                      the host that responded
     *                                      and the rtt of the message.
     *                                      If rtt is < 0, the host responded
     *                                      that <code>target</code>
     *                                      is either unreachable,
     *                                      or the TTL exceeded.
     *                                      If rtt is = 0, no response
     *                                      was received.
     */
    int ping(struct sockaddr_in* from,
             long* timeus,
             uint8_t len,
             const struct sockaddr_in* target,
             const struct timeval* waittime = NULL,
             size_t nbytes = 56)
    {
        LOGGER_ASSERT1(len > 0, len);
        LOGGER_ASSERT1(ICMP_MINLEN <= nbytes && nbytes < IP_MAXPACKET - sizeof(struct ip), nbytes);

        memset(from, 0, sizeof(struct sockaddr_in) * len);
        memset(timeus, 0, sizeof(long) * len);

        // we need a buffer large enough to accomodate the ICMP ECHOREPLY
        // message which must contain the entirety of the ECHO request
        const size_t bufsiz = sizeof(struct icmp) // ECHOREPLY
                            + sizeof(struct ip) + nbytes; // ECHO request
        LOGGER_ASSERT1(bufsiz < IP_MAXPACKET, bufsiz);
        struct icmp* icmp = reinterpret_cast<struct icmp*>(alloca(bufsiz));

        const SockAddr to(target);
        const uint16_t seq0 = rand() % (uint16_t)(0xFFFF - len - 1);
        const uint16_t id = getpid();
        for (uint8_t i = 0; i < len; ++i)
        {
            // ICMP ECHO

            memset(icmp, 0, ICMP_MINLEN);
            icmp->icmp_type = ICMP_ECHO;
            icmp->icmp_id = id;
            icmp->icmp_seq = seq0 + i;
            icmp->icmp_cksum = Checksum::icmp(icmp, nbytes);

            struct timespec t0;
            if (timestamp(&t0) == -1)
                return -1;

            if (send(icmp, nbytes, MSG_NOSIGNAL, target) == -1)
                return -1;

            // ICMP REPLY

            struct timespec t1;
            const ssize_t n = icmp_reply(icmp, bufsiz, 0, &t1, &from[i], waittime);
            if (n == -1)
            {
                if (errno == EWOULDBLOCK)
                {
                    LOGGER_DEBUG("PING/ICMP %-3d %-16s *", i, to.ascii());
                    // timeus[i] = 0;
                    continue;
                }
                return -1;
            }
            LOGGER_ASSERT1(n > 0, n);

            timeus[i] = elapsedus(t1, t0);
            const uint8_t type = icmp->icmp_type;
            if (type == ICMP_TIME_EXCEEDED || type == ICMP_DEST_UNREACH)
                timeus[i] = - timeus[i];

            if (LOGGER_IS_DEBUG())
            {
                SockAddr f(from[i]);
                if (type == ICMP_TIME_EXCEEDED)
                    LOGGER_DEBUG("PING/ICMP %-3d %-16s %.3fms ...", i, f.ascii(), timeus[i] / -1000.0);
                else if (type == ICMP_DEST_UNREACH)
                    LOGGER_DEBUG("PING/ICMP %-3d %-16s %.3fms !", i, f.ascii(), timeus[i] / -1000.0);
                else
                    LOGGER_DEBUG("PING/ICMP %-3d %-16s %.3fms", i, f.ascii(), timeus[i] / 1000.0);
            }
        }

        return len;
    }

    /**
     * @return -1 on error.
     *         number of entries in <code>from</code> and <code>timeus</code>
     *         on success.
     * @see ping()
     */
    int traceroute(struct sockaddr_in* from,
                   long* timeus,
                   uint8_t len,
                   const struct sockaddr_in* target,
                   const struct timeval* waittime = NULL,
                   size_t nbytes = 56,
                   uint8_t minttl = 1)
    {
        LOGGER_ASSERT1(len > 0, len);
        LOGGER_ASSERT1(ICMP_MINLEN <= nbytes && nbytes < IP_MAXPACKET - sizeof(struct ip), nbytes);
        LOGGER_ASSERT1(minttl > 0, minttl);

        memset(from, 0, sizeof(struct sockaddr_in) * len);
        memset(timeus, 0, sizeof(long) * len);

        // we need a buffer large enough to accomodate the ICMP ECHOREPLY
        // message which must contain the entirety of the ECHO request
        const size_t bufsiz = sizeof(struct icmp) // ECHOREPLY
                            + sizeof(struct ip) + nbytes; // ECHO request
        LOGGER_ASSERT1(bufsiz < IP_MAXPACKET, bufsiz);
        struct icmp* icmp = reinterpret_cast<struct icmp*>(alloca(bufsiz));

        const SockAddr to(target);
        bool trust_fromaddr = false;
        const uint16_t seq0 = rand() % (uint16_t)(0xFFFF - len - 1);
        const uint16_t id = getpid();
        for (uint8_t i = 0; i < len; ++i)
        {
            // ICMP ECHO

            int ttl = minttl + i;
            if (ttl > max_ttl())
                ttl = max_ttl();
            if (setsockopt(IPPROTO_IP, IP_TTL, ttl) == -1)
                return -1;

            memset(icmp, 0, ICMP_MINLEN);
            icmp->icmp_type = ICMP_ECHO;
            icmp->icmp_id = id;
            icmp->icmp_seq = seq0 + i;
            icmp->icmp_cksum = Checksum::icmp(icmp, nbytes);

            struct timespec t0;
            if (timestamp(&t0) == -1)
                return -1;

            if (send(icmp, nbytes, MSG_NOSIGNAL, target) == -1)
                return -1;

            // ICMP REPLY

            for (;;)
            {
                struct timespec t1;
                const ssize_t n = icmp_reply(icmp, bufsiz, 0, &t1, &from[i], waittime);
                if (n == -1)
                {
                    if (errno == EWOULDBLOCK)
                    {
                        LOGGER_DEBUG("TRACEROUTE/ICMP: %-3d %-16s *", ttl, to.ascii());
                        // timeus[i] = 0;
                        break;
                    }
                    return -1;
                }
                if (n == 0)
                {
                    icmp->icmp_type = ICMP_ECHO;
                    icmp->icmp_id = id;
                    icmp->icmp_seq = seq0 + i;
                    continue;
                }

                timeus[i] = elapsedus(t1, t0);
                const uint8_t type = icmp->icmp_type;
                if (type == ICMP_DEST_UNREACH)
                    timeus[i] = - timeus[i];

                if (LOGGER_IS_DEBUG())
                {
                    SockAddr f(from[i]);
                    if (type == ICMP_TIME_EXCEEDED)
                        LOGGER_DEBUG("TRACEROUTE/ICMP %-3d %-16s %.3fms", ttl, f.ascii(), timeus[i] / 1000.0);
                    else if (type == ICMP_DEST_UNREACH)
                        LOGGER_DEBUG("TRACEROUTE/ICMP %-3d %-16s %.3fms !", ttl, f.ascii(), timeus[i] / -1000.0);
                    else
                        LOGGER_DEBUG("TRACEROUTE/ICMP %-3d %-16s %.3fms", ttl, f.ascii(), timeus[i] / 1000.0);
                }

                if (type == ICMP_ECHOREPLY || type == ICMP_DEST_UNREACH)
                    return i + 1;

                if (! trust_fromaddr)
                {
                    // in case the network is hiding the real source of the message
                    trust_fromaddr = (from[i].sin_addr.s_addr != target->sin_addr.s_addr);
                }
                if (trust_fromaddr && from[i].sin_addr.s_addr == target->sin_addr.s_addr)
                    return i + 1;

                break;
            }
        }

        return len;
    }

    int traceroute2(struct sockaddr_in* from,
                   int* timeus,
                   uint8_t len,
                   const struct sockaddr_in& target,
                   const struct timeval* waittime = NULL,
                   size_t nbytes = 56,
                   uint8_t minttl = 1,
                   uint8_t incrttl = 1,
                   const struct timeval* interval = NULL)
    {
        static const uint16_t pid = getpid();

        LOGGER_ASSERT1(len > 0, len);
        LOGGER_ASSERT1(sizeof(struct ip) + sizeof(struct icmp) <= nbytes && nbytes < IP_MAXPACKET, nbytes);
        LOGGER_ASSERT1(minttl > 0, minttl);

        if (setsockopt(IPPROTO_IP, IP_TTL, minttl) == -1)
            return -1;

        memset(from, 0, sizeof(struct sockaddr_in) * len);
        memset(timeus, 0, sizeof(int) * len);

        struct timeval* t0 = calloca(len, struct timeval);

        // we need a rcvbuf large enough for a ICMP_TIME_EXCEEDED
        // which contains a copy of the outgoing ICMP message,
        // well only the first ICMP_MINLEN bytes of it
        const size_t bufsiz = nbytes < sizeof(struct ip) + sizeof(struct icmp) + sizeof(struct ip) + ICMP_MINLEN
                            ? sizeof(struct ip) + sizeof(struct icmp) + sizeof(struct ip) + ICMP_MINLEN
                            : nbytes;
        void* buf = alloca(bufsiz);
        nbytes -= sizeof(struct ip); // OS will add the IP header for us
        (void) so_sndbuf(nbytes);

        struct timeval last_packet_ts = { 0, 0 };
        const uint16_t seq = rand() % (uint16_t)(0xFFFF - len - 1);
        bool trust_peeraddr = false;
        for (uint8_t i = 0; i < len; )
        {
            int ttl = minttl + incrttl * i;
            if (ttl > max_ttl())
                ttl = max_ttl();

            FDSet rfds, wfds;
            rfds.set(_sockfd);
            if (i < len)
                wfds.set(_sockfd);

            if (interval
                && (interval->tv_sec > 0 || interval->tv_usec > 0))
            {
                struct timeval now;
                (void) gettimeofday(&now, NULL);

                if (last_packet_ts + *interval <= now)
                {
                    switch (select(&rfds, &wfds, waittime))
                    {
                    case -1:    return -1;
                    case 0:     LOGGER_DEBUG("ICMP: %3d *", ttl);
                                return i;
                    default:    break;
                    }
                }
                else
                {
                    struct timeval tv = last_packet_ts - now + *interval;
                    if (! waittime || tv < *waittime)
                    {
                        switch (select(&rfds, NULL, &tv))
                        {
                        case -1:    return -1;
                        case 0:     LOGGER_ERROR("ICMP: %3d !", ttl);
                                    return -1;
                        default:    break;
                        }
                    }
                    else
                    {
                        switch (select(&rfds, NULL, waittime))
                        {
                        case -1:    return -1;
                        case 0:     LOGGER_ERROR("ICMP: %3d !", ttl);
                                    return -1;
                        default:    break;
                        }
                    }
                }
            }
            else
            {
                switch (select(&rfds, &wfds, waittime))
                {
                case -1:    return -1;
                case 0:     LOGGER_DEBUG("ICMP: %3d *", ttl);
                            return i;
                default:    break;
                }
            }

            if (wfds.isset(_sockfd))
            {
                // ICMP ECHO

                if (incrttl > 0)
                {
                    int ttl2 = minttl + incrttl * i;
                    if (ttl2 <= max_ttl())
                    {
                        if (setsockopt(IPPROTO_IP, IP_TTL, ttl2) == -1)
                            return -1;
                    }
                    else if (ttl2 < max_ttl() + incrttl)
                    {
                        if (setsockopt(IPPROTO_IP, IP_TTL, max_ttl()) == -1)
                            return -1;
                    }
                }

                struct icmp* icmp = reinterpret_cast<struct icmp*>(buf);
                memset(icmp, 0, sizeof(*icmp));
                icmp->icmp_type = ICMP_ECHO;
                icmp->icmp_id = pid;
                icmp->icmp_seq = seq + i;
                icmp->icmp_cksum = Checksum::icmp(icmp, nbytes);

                (void) gettimeofday(&t0[i], NULL);

                ssize_t n = ::sendto(_sockfd,
                                     icmp, nbytes,
                                     MSG_NOSIGNAL,
                                     (struct sockaddr*) &target, sizeof(target));
                if (n == -1)
                {
                    LOGGER_PERROR("sendmsg");
                    return -1;
                }
                if ((size_t)n != nbytes)
                    LOGGER_WARN("sendmsg: %'zd < %'zd", n, nbytes);

                last_packet_ts = t0[i];
                i += 1;
            }

            if (rfds.isset(_sockfd))
            {
                // ICMP reply

                SockAddr peer;

                struct msghdr msg;
                memset(&msg, 0, sizeof(msg));
                msg.msg_name = peer.addr();
                msg.msg_namelen = peer.addrlen();
                msg.msg_iov = reinterpret_cast<struct iovec*>(alloca(sizeof(struct iovec)));
                msg.msg_iovlen = 1;
                msg.msg_iov[0].iov_base = buf;
                msg.msg_iov[0].iov_len = bufsiz;
                msg.msg_controllen = CMSG_SPACE(sizeof(struct timeval));
                msg.msg_control = reinterpret_cast<caddr_t>(alloca(msg.msg_controllen));

                struct timeval t1;
                (void) gettimeofday(&t1, NULL);

                const ssize_t n = ::recvmsg(_sockfd, &msg, MSG_DONTWAIT);
                if (n == -1)
                {
                    LOGGER_PERROR("recvmsg");
                    return -1;
                }
                if ((size_t)n < sizeof(struct ip) + ICMP_MINLEN)
                {
                    LOGGER_WARN("recvmsg: received message too short: %zd < %zu", n, sizeof(struct ip) + ICMP_MINLEN);
                    continue;
                }
                if (BITMASK_ISSET(msg.msg_flags, MSG_CTRUNC))
                    LOGGER_WARN("recvmsg: MSG_CTRUNC");

                const struct ip* ip = reinterpret_cast<const struct ip*>(msg.msg_iov[0].iov_base);
                if (ip->ip_v != IPVERSION)
                {
                    LOGGER_WARN("Ignore message: ip_v (%d) != %d", ip->ip_v, IPVERSION);
                    continue;
                }
                if (ip->ip_p != IPPROTO_ICMP)
                {
                    LOGGER_WARN("Ignore message: not ICMP (%d)", ip->ip_p);
                    continue;
                }

#ifndef __APPLE__
                const uint16_t ip_len = ntohs(ip->ip_len);
#else
                // __APPLE__ already byte-swaps ip_len
                const uint16_t ip_len = ip->ip_len;
#endif
                if (ip_len < n)
                    LOGGER_DEBUG("IP len (%hu) < %zd", ip_len, n);

                const size_t ip_hl = ip->ip_hl << 2;
                if ((size_t)n < ip_hl || ip_hl > (size_t)n - ICMP_MINLEN)
                {
                    LOGGER_WARN("Ignore ICMP message: IP header too large: %zd", ip_hl);
                    continue;
                }

                const struct icmp* icmp = reinterpret_cast<const struct icmp*>(reinterpret_cast<const uint8_t*>(ip) + ip_hl);

#ifndef NDEBUG
                if (ip_len == n && icmp->icmp_cksum != 0 && Checksum::icmp(icmp, ip_len - ip_hl) != 0)
                {
                    LOGGER_WARN("Ignore ICMP message: checksum mismatch");
                    continue;
                }
#endif

                if (LOGGER_IS_DEBUG())
                {
                    const char* type = icmp_type(icmp);
                    const char* code = icmp_code(icmp);
                    LOGGER_DEBUG("ICMP [%s%s%s]: %'zd bytes from %s", type, code[0] == '\0' ? "" : " ", code, ip_len, peer.ascii());

                    LOGGER_ASSERT2(peer.s_addr() == ip->ip_src.s_addr, peer.ascii(), Addr(ip->ip_src).ascii());
                }

                const uint8_t type = icmp->icmp_type;
                int j;
                if (type == ICMP_TIME_EXCEEDED || type == ICMP_DEST_UNREACH)
                {
                    const struct ip* sub_ip = reinterpret_cast<const struct ip*>(&icmp->icmp_ip);
                    const size_t sub_n = n - (reinterpret_cast<const uint8_t*>(sub_ip) - reinterpret_cast<const uint8_t*>(ip));
                    if (sub_n < sizeof(struct ip) + ICMP_MINLEN)
                    {
                        LOGGER_WARN("Ignore ICMP message: sub-message too short: %zu < %zu", sub_n, sizeof(struct ip) + ICMP_MINLEN);
                        continue;
                    }

                    if (sub_ip->ip_p != IPPROTO_ICMP)
                    {
                        LOGGER_DEBUG("Ignore ICMP message: outgoing packet wasn't ICMP but %hhu", sub_ip->ip_p);
                        continue;
                    }

                    const unsigned sub_ip_hl = sub_ip->ip_hl << 2;
                    if (sub_ip_hl > (size_t)sub_n - ICMP_MINLEN)
                    {
                        LOGGER_WARN("Ignore ICMP message: sub-IP header too large: %zd", sub_ip_hl);
                        continue;
                    }

                    const struct icmp* sub_icmp = reinterpret_cast<const struct icmp*>(reinterpret_cast<const uint8_t*>(sub_ip) + sub_ip_hl);

                    if (sub_icmp->icmp_type != ICMP_ECHO)
                    {
                        LOGGER_WARN("Ignore ICMP message: not ECHO (%s)", icmp_type(sub_icmp));
                        continue;
                    }
                    if (sub_icmp->icmp_id != pid)
                    {
                        LOGGER_WARN("Ignore ICMP message: not my ident");
                        continue;
                    }
                    j = sub_icmp->icmp_seq - seq;
                    if (j < 0 || i < j)
                    {
                        LOGGER_WARN("Ignore ICMP message: not my sequence([%hu...%hu]: %hu", seq, (uint16_t)(seq + i), sub_icmp->icmp_seq);
                        continue;
                    }
                }
                else if (type == ICMP_ECHOREPLY)
                {
                    if (icmp->icmp_id != pid)
                    {
                        LOGGER_WARN("Ignore ICMP message: not my ident");
                        continue;
                    }
                    j = icmp->icmp_seq - seq;
                    if (j < 0 || i < j)
                    {
                        LOGGER_WARN("Ignore ICMP message: not my sequence([%hu...%hu]: %hu", seq, (uint16_t)(seq + i), icmp->icmp_seq);
                        continue;
                    }
                }
                else
                {
                    LOGGER_WARN("Ignore ICMP message: not ECHOREPLY (%s)", icmp_type(icmp));
                    continue;
                }

                for (struct cmsghdr* cmsg = CMSG_FIRSTHDR(&msg);
                     cmsg != NULL;
                     cmsg = CMSG_NXTHDR(&msg, cmsg))
                {
                    if (   cmsg->cmsg_level == SOL_SOCKET
                        && cmsg->cmsg_type == SCM_TIMESTAMP
                        && cmsg->cmsg_len >= CMSG_LEN(sizeof(t1)))
                    {
                        memcpy(&t1, CMSG_DATA(cmsg), sizeof(t1));
                        break;
                    }
                }

                if (! trust_peeraddr)
                {
                    // in case the network is hiding the real source of the message
                    trust_peeraddr = (peer.s_addr() != target.sin_addr.s_addr);
                }

                peer.copy(&from[i]);
                timeus[i] = elapsedus(t1, t0[j]);
                if (type == ICMP_DEST_UNREACH)
                    timeus[i] = - timeus[i];

                if (LOGGER_IS_DEBUG())
                {
                    if (type == ICMP_TIME_EXCEEDED)
                        LOGGER_DEBUG("ICMP %3d %-16s %.3fms", ttl, peer.ascii(), timeus[i] / 1000.0);
                    else if (type == ICMP_DEST_UNREACH)
                        LOGGER_DEBUG("ICMP %3d %-16s %.3fms !", ttl, peer.ascii(), timeus[i] / -1000.0);
                    else
                        LOGGER_DEBUG("ICMP %-16s %.3fms", peer.ascii(), timeus[i] / 1000.0);
                }

                if (type == ICMP_ECHOREPLY || type == ICMP_DEST_UNREACH)
                    return i + 1;

                if (trust_peeraddr && peer.s_addr() == target.sin_addr.s_addr)
                    return i + 1;
            }
        }

        return len;
    }

private:

    static const long NANOSEC = 1000000000;
};

#endif
