
#ifndef _NET_STATS_H_
#define _NET_STATS_H_

#include <ifaddrs.h>
#include <string.h>
#include <unistd.h>

#include <net/if.h>

#ifdef __linux__
#  include <net/if_ppp.h>
#endif

#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>

#include "Net.h"
#include "Logger.h"

///////////////////////////////////////////////////////////////////////
// NetStats
///////////////////////////////////////////////////////////////////////

template <typename T, unsigned N>
class NetStats
{
public:

    NetStats()
        : _sockfd(-1)
    {
        clear();
    }

    virtual ~NetStats()
    {
        if (_sockfd != -1)
            (void) close(_sockfd);
    }

    unsigned count() const
    {
        return N;
    }

    virtual int snapshot() =0;

    const char* ifname(unsigned i) const
    {
        LOGGER_ASSERT1(i < N, i);
        return _ifname[i][0] ? _ifname[i] : NULL;
    }

    const struct timeval* timestamp(unsigned i) const
    {
        LOGGER_ASSERT1(i < N, i);
        return &_timestamp[i];
    }

    const struct timeval* timestamp(const char* ifname) const
    {
        for (unsigned i = 0; i < N; ++i)
        {
            if (strncmp(_ifname[i], ifname, sizeof(_ifname[i])) == 0)
                return &_timestamp[i];
        }
        return NULL;
    }

    const T* get(unsigned i) const
    {
        LOGGER_ASSERT1(i < N, i);
        return &_stats[i];
    }

    const T* get(const char* ifname) const
    {
        for (unsigned i = 0; i < N; ++i)
        {
            if (strncmp(_ifname[i], ifname, sizeof(_ifname[i])) == 0)
                return &_stats[i];
        }
        return NULL;
    }

    const T* add(const char* ifname,
                 const struct timeval* timestamp,
                 const T* stats)
    {
#ifndef NDEBUG
        for (unsigned i = 0; i < N; ++i)
        {
            LOGGER_ASSERT1(strncmp(_ifname[i], ifname, sizeof(_ifname[i])) != 0, i);
        }
#endif

        for (unsigned i = 0; i < N; ++i)
        {
            if (_ifname[i][0] != '\0')
                continue;

            strncpy(_ifname[i], ifname, sizeof(_ifname[i]));
            memcpy(&_timestamp[i], timestamp, sizeof(_timestamp[i]));
            memcpy(&_stats[i], stats, sizeof(_stats[i]));

            return &_stats[i];
        }

        LOGGER_ASSERT1(!"NetStats: N too small", N);
        return NULL;
    }

    void clear(unsigned i)
    {
        LOGGER_ASSERT1(i < N, i);
        _ifname[i][0] = '\0';
    }

    // - add new interfaces
    // - remove old interfaces
    void sync(const NetStats& recent)
    {
        // add new interfaces

        for (unsigned i = 0; i < N; ++i)
        {
            const char* ifname = recent.ifname(i);
            if (ifname == NULL)
                continue;
            if (get(ifname) != NULL)
                continue;

            add(ifname, recent.timestamp(i), recent.get(i));
        }

        // remove old interfaces

        for (unsigned i = 0; i < N; ++i)
        {
            const char* ifname = this->ifname(i);
            if (ifname == NULL)
                continue;
            if (recent.get(ifname) != NULL)
                continue;

            clear(i);
        }
    }

protected:

    void clear()
    {
        memset(_ifname, 0, sizeof(_ifname));
        memset(_timestamp, 0, sizeof(_timestamp));
        memset(_stats, 0, sizeof(_stats));
    }

    int open()
    {
        if (_sockfd == -1)
        {
            _sockfd = socket(AF_INET, SOCK_DGRAM, 0);
            if (_sockfd == -1)
                LOGGER_PERROR("socket(AF_INET, SOCK_DGRAM, 0)");
        }
        return _sockfd;
    }

protected:

    int _sockfd;

    char _ifname[N][IFNAMSIZ];
    struct timeval _timestamp[N];
    T _stats[N];
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             IFStats                               //
//                                                                   //
///////////////////////////////////////////////////////////////////////

#ifdef __linux__

#  include <ctype.h>
#  include <stdio.h>

// @see <a href="http://lxr.free-electrons.com/source/include/uapi/linux/if_link.h?v=3.12#L8">struct rtnl_link_stats</a>
struct if_stats
{
    unsigned long rx_packets;             /* total packets received       */
    unsigned long tx_packets;             /* total packets transmitted    */
    unsigned long rx_bytes;               /* total bytes received         */
    unsigned long tx_bytes;               /* total bytes transmitted      */
    unsigned long rx_errors;              /* bad packets received         */
    unsigned long tx_errors;              /* packet transmit problems     */
//    unsigned long rx_dropped;             /* no space in linux buffers    */
    unsigned long tx_dropped;             /* no space available in linux  */
    unsigned long multicast;              /* multicast packets received   */
    unsigned long collisions;

    unsigned long rx_other_errors; // rx_dropped + rx_missed_errors
    unsigned long rx_detailed_errors; // rx_length_errors + rx_over_errors + rx_crc_errors + rx_frame_errors

    unsigned long tx_other_errors; // tx_carrier_errors + tx_aborted_errors + tx_window_errors + tx_heartbeat_errors

    /* detailed rx_errors: */
//    unsigned long rx_length_errors;
//    unsigned long rx_over_errors;         /* receiver ring buff overflow  */
//    unsigned long rx_crc_errors;          /* recved pkt with crc error    */
//    unsigned long rx_frame_errors;        /* recv'd frame alignment error */
    unsigned long rx_fifo_errors;         /* recv'r fifo overrun          */
//    unsigned long rx_missed_errors;       /* receiver missed packet       */

    /* detailed tx_errors */
//    unsigned long tx_aborted_errors;
//    unsigned long tx_carrier_errors;
    unsigned long tx_fifo_errors;
//    unsigned long tx_heartbeat_errors;
//    unsigned long tx_window_errors;

    /* for cslip etc */
    unsigned long rx_compressed;
    unsigned long tx_compressed;


    unsigned long rx_all_errors() const
    {
        return rx_errors + rx_other_errors + rx_detailed_errors + rx_fifo_errors;
    }

    unsigned long tx_all_errors() const
    {
        return tx_errors + tx_dropped + tx_other_errors + tx_fifo_errors;
    }
};

class IFStats
    : public NetStats<struct if_stats, 8>
{
public:

    IFStats()
    {
        FILE* stream = fopen("/proc/net/dev", "r");
        if (! stream)
        {
            LOGGER_PWARN("/proc/net/dev");
        }
        else
        {
            char buf[128];
            (void) fgets(buf, sizeof(buf), stream);
            (void) fgets(buf, sizeof(buf), stream);
            _offset = ftell(stream);
            (void) fclose(stream);
        }
    }

    virtual int snapshot()
    {
        clear();

        FILE* stream = fopen("/proc/net/dev", "r");
        if (! stream)
        {
            LOGGER_PWARN("/proc/net/dev");
            return -1;
        }

        if (fseek(stream, _offset, SEEK_SET) == -1)
        {
            LOGGER_PWARN("fseek(/proc/net/dev, %ld)", _offset);
            return -1;
        }

        struct timeval now;
        (void) gettimeofday(&now, NULL); // FIXME: don't use gettimeofday

        char buf[256];
        unsigned i = 0;
        while (fgets(buf, sizeof(buf), stream))
        {
            LOGGER_ASSERT(strrchr(buf, '\n') != NULL); // probably need to increase size of buf

            const char* p = buf;
            while (*p && isspace(*p))
                ++p;

#define STR_EXPAND0(x) #x
#define STR_EXPAND(x) STR_EXPAND0(x)

            if (sscanf(p,
                       "%" STR_EXPAND(IFNAMSIZ) "s %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu",
                       &_ifname[i][0],
                       &_stats[i].rx_bytes,
                       &_stats[i].rx_packets,
                       &_stats[i].rx_errors,
                       &_stats[i].rx_other_errors, // rx_dropped + rx_missed_errors
                       &_stats[i].rx_fifo_errors,
                       &_stats[i].rx_detailed_errors, // rx_length_errors + rx_over_errors + rx_crc_errors + rx_frame_errors,
                       &_stats[i].rx_compressed,
                       &_stats[i].multicast,
                       &_stats[i].tx_bytes,
                       &_stats[i].tx_packets,
                       &_stats[i].tx_errors,
                       &_stats[i].tx_dropped,
                       &_stats[i].tx_fifo_errors,
                       &_stats[i].collisions,
                       &_stats[i].tx_other_errors, // tx_carrier_errors + tx_aborted_errors + tx_window_errors + tx_heartbeat_errors,
                       &_stats[i].tx_compressed) != 17)
            {
                LOGGER_WARN("scanf(%s) != 17", p);
                continue;
            }

#undef STR_EXPAND
#undef STR_EXPAND0

            LOGGER_ASSERT1(_ifname[i][strlen(_ifname[i]) - 1] == ':', _ifname[i][strlen(_ifname[i]) - 1]);
            _ifname[i][strlen(_ifname[i]) - 1] = '\0';

            if (i == 0 && open() == -1)
                return -1;

            LOGGER_ASSERT1(i < count(), count());
            if (i >= count())
            {
                LOGGER_ALERT("IFStats: N (%u) too smal", count());
                break;
            }

            struct ifreq ifr;
            memset(&ifr, 0, sizeof(ifr));
            strncpy(ifr.ifr_name, _ifname[i], sizeof(ifr.ifr_name));
            if (ioctl(_sockfd, SIOCGIFFLAGS, &ifr) == -1)
            {
                LOGGER_PWARN("ioctl(%s, SIOCGIFFLAGS)", _ifname[i]);
                // continue
            }
            if (! BITMASK_ARESET(ifr.ifr_flags, IFF_UP | IFF_RUNNING))
            {
                clear(i);
                continue;   // interface is not running. Skip it.
            }

            // FIXME: when a ppp interface comes up
            //        it is picked up much earlier by IFStats than it is
            //        by PPPStats (ie. the interface is "up", by PPP isn't yet).
            //        No: we can't (easily) check for IFF_LOWER_UP here
            //        as it is not reported by SIOCGIFFLAGS.
            //        This causes a discrepancy in the stats reported.

            memcpy(&_timestamp[i], &now, sizeof(_timestamp[i]));

            ++i;
        }

        (void) fclose(stream);

        return i;
    }

    int siociftxqlen(const char* ifname)
    {
        if (open() == -1)
            return -1;

        struct ifreq ifr;
        memset(&ifr, 0, sizeof(ifr));
        strncpy(ifr.ifr_name, ifname, IF_NAMESIZE);
        if (ioctl(_sockfd, SIOCGIFTXQLEN, &ifr) == -1)
            return -1;

        return ifr.ifr_qlen;
    }

private:

    long _offset;
};

#endif

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             IWStats                               //
//                                                                   //
///////////////////////////////////////////////////////////////////////

#ifdef __linux__

#  include <iwlib.h>
#  include <stdio.h>

// TODO: Derive from NetStats
//       and deal correctly with interface coming & going
class IWStats
{
public:

    IWStats()
        : _skfd(iw_sockets_open())
    {
        memset(_ifname, 0, sizeof(_ifname));
        memset(_range, 0, sizeof(_range));
        memset(_has_range, 0, sizeof(_has_range));
        memset(_stats, 0, sizeof(_stats));

        if (_skfd < 0)
        {
            LOGGER_PWARN("iw_sockets_open");
            return;
        }

        (void) init_range_info();
    }

    IWStats(const IWStats& rhs)
    {
        memcpy(this, &rhs, sizeof(*this));

        _skfd = iw_sockets_open();
        if (_skfd < 0)
        {
            LOGGER_PWARN("iw_sockets_open");
            return;
        }
    }

    ~IWStats()
    {
        if (_skfd != -1)
            iw_sockets_close(_skfd);
    }

    unsigned count() const
    {
        unsigned i;
        for (i = 0; i < N && _ifname[i][0]; ++i)
        {}
        return i;
    }

    int snapshot()
    {
        memset(_stats, 0, sizeof(_stats));

        if (_skfd == -1)
            return 0;

        unsigned i;
        for (i = 0; i < N && _ifname[i][0]; ++i)
        {
            if (iw_get_stats(_skfd, _ifname[i], &_stats[i], &_range[i], _has_range[i]) < 0)
                LOGGER_PWARN("iw_get_stats(%s)", _ifname[i]);
            else
                memset(&_stats[i], 0, sizeof(_stats[i]));
        }

        return i;
    }

    unsigned throughput(unsigned ifindex) const
    {
        const iwrange* range = get_range(ifindex);
        return range ? range->throughput : 0;
    }

    const char* ifname(unsigned ifindex) const
    {
        LOGGER_ASSERT1(ifindex < N, ifindex);
        return _ifname[ifindex];
    }

    int name(unsigned ifindex, char* buffer, int buflen)
    {
        struct iwreq wrq;
        if (get_ext(ifindex, SIOCGIWNAME, &wrq) == -1)
        {
            ierror(ifindex, "SIOCGIWNAME");
            if (buflen > 0)
                buffer[0] = '\0';
            return 0;
        }

        return snprintf(buffer, buflen, "%-*s", IFNAMSIZ, wrq.u.name);
    }

    int link_quality(unsigned ifindex, char* buffer, int buflen) const
    {
        const iwrange* range = get_range(ifindex);
        const iwstats* stats = get_stats(ifindex);
        if (range
            && ((stats->qual.level != 0) || (stats->qual.updated & (IW_QUAL_DBM | IW_QUAL_RCPI))))
        {
            /* Deal with quality : always a relative value */
            if (! (stats->qual.updated & IW_QUAL_QUAL_INVALID))
            {
                if (range->max_qual.qual == 0)
                {
                    return snprintf(buffer, buflen,
                                    "%c%'d/%'d",
                                    stats->qual.updated & IW_QUAL_QUAL_UPDATED ? '=' : ':',
                                    stats->qual.qual,
                                    range->max_qual.qual);
                }
                else
                {
                    return snprintf(buffer, buflen,
                                    "%c%.0f%%",
                                    stats->qual.updated & IW_QUAL_QUAL_UPDATED ? '=' : ':',
                                    stats->qual.qual * 100.0 / range->max_qual.qual);
                }
            }
        }
        else
        {
            return snprintf(buffer, buflen,
                            ":%'d", stats->qual.qual);
        }

        if (buflen > 0)
            buffer[0] = '\0';
        return 0;
    }

    int signal_level(unsigned ifindex, char* buffer, int buflen) const
    {
        const iwrange* range = get_range(ifindex);
        const iwstats* stats = get_stats(ifindex);
        if (range
            && ((stats->qual.level != 0) || (stats->qual.updated & (IW_QUAL_DBM | IW_QUAL_RCPI))))
        {
            /* Check if the statistics are in RCPI (IEEE 802.11k) */
            if (stats->qual.updated & IW_QUAL_RCPI)
            {
                /* Deal with signal level in RCPI */
                /* RCPI = int{(Power in dBm +110)*2} for 0dbm > Power > -110dBm */
                if (! (stats->qual.updated & IW_QUAL_LEVEL_INVALID))
                {
                    double rcpilevel = (stats->qual.level / 2.0) - 110.0;
                    return snprintf(buffer, buflen,
                                    "%c%g dBm",
                                    stats->qual.updated & IW_QUAL_LEVEL_UPDATED ? '=' : ':',
                                    rcpilevel);
                }
            }
            else
            {
                /* Check if the statistics are in dBm */
                if ((stats->qual.updated & IW_QUAL_DBM)
                    || (stats->qual.level > range->max_qual.level))
                {
                    /* Deal with signal level in dBm  (absolute power measurement) */
                    if (! (stats->qual.updated & IW_QUAL_LEVEL_INVALID))
                    {
                        int dblevel = stats->qual.level;
                        /* Implement a range for dBm [-192; 63] */
                        if (stats->qual.level >= 64)
                            dblevel -= 0x100;
                        return snprintf(buffer, buflen,
                                        "%c%'d dBm",
                                        stats->qual.updated & IW_QUAL_LEVEL_UPDATED ? '=' : ':',
                                        dblevel);
                    }
                }
                else
                {
                    /* Deal with signal level as relative value (0 -> max) */
                    if (! (stats->qual.updated & IW_QUAL_LEVEL_INVALID))
                    {
                        if (range->max_qual.level == 0)
                        {
                            return snprintf(buffer, buflen,
                                            "%c%'d/%'d",
                                            stats->qual.updated & IW_QUAL_LEVEL_UPDATED ? '=' : ':',
                                            stats->qual.level,
                                            range->max_qual.level);
                        }
                        else
                        {
                            return snprintf(buffer, buflen,
                                            "%c%.0f%%",
                                            stats->qual.updated & IW_QUAL_LEVEL_UPDATED ? '=' : ':',
                                            stats->qual.level * 100.0 / range->max_qual.level);
                        }
                    }
                }
            }
        }
        else
        {
            return snprintf(buffer, buflen,
                            ":%'d", stats->qual.level);
        }

        if (buflen > 0)
            buffer[0] = '\0';
        return 0;
    }

    int noise_level(unsigned ifindex, char* buffer, int buflen) const
    {
        const iwrange* range = get_range(ifindex);
        const iwstats* stats = get_stats(ifindex);
        if (range
            && ((stats->qual.level != 0) || (stats->qual.updated & (IW_QUAL_DBM | IW_QUAL_RCPI))))
        {
            /* Check if the statistics are in RCPI (IEEE 802.11k) */
            if (stats->qual.updated & IW_QUAL_RCPI)
            {
                /* Deal with noise level in dBm (absolute power measurement) */
                if (! (stats->qual.updated & IW_QUAL_NOISE_INVALID))
                {
                    double rcpinoise = (stats->qual.noise / 2.0) - 110.0;
                    return snprintf(buffer, buflen,
                                    "%c%g dBm",
                                    stats->qual.updated & IW_QUAL_NOISE_UPDATED ? '=' : ':',
                                    rcpinoise);
                }
            }
            else
            {
                /* Check if the statistics are in dBm */
                if ((stats->qual.updated & IW_QUAL_DBM)
                    || (stats->qual.level > range->max_qual.level))
                {
                    /* Deal with noise level in dBm (absolute power measurement) */
                    if (! (stats->qual.updated & IW_QUAL_NOISE_INVALID))
                    {
                        int dbnoise = stats->qual.noise;
                        /* Implement a range for dBm [-192; 63] */
                        if (stats->qual.noise >= 64)
                            dbnoise -= 0x100;
                        return snprintf(buffer, buflen,
                                        "%c%'d dBm",
                                        stats->qual.updated & IW_QUAL_NOISE_UPDATED ? '=' : ':',
                                        dbnoise);
                    }
                }
                else
                {
                    /* Deal with noise level as relative value (0 -> max) */
                    if ( !(stats->qual.updated & IW_QUAL_NOISE_INVALID))
                    {
                        if (range->max_qual.noise == 0)
                        {
                            return snprintf(buffer, buflen,
                                            "%c%'d/%'d",
                                            stats->qual.updated & IW_QUAL_NOISE_UPDATED ? '=' : ':',
                                            stats->qual.noise,
                                            range->max_qual.noise);
                        }
                        else
                        {
                            return snprintf(buffer, buflen,
                                            "%c%'.0f%%",
                                            stats->qual.updated & IW_QUAL_NOISE_UPDATED ? '=' : ':',
                                            stats->qual.noise * 100.0 / range->max_qual.noise);
                        }
                    }
                }
            }
        }
        else
        {
            return snprintf(buffer, buflen,
                            ":%'d", stats->qual.noise);
        }

        if (buflen > 0)
            buffer[0] = '\0';
        return 0;
    }

    int discard_nwid(unsigned ifindex) const
    {
        return get_stats(ifindex)->discard.nwid;
    }

    int discard_code(unsigned ifindex) const
    {
        return get_stats(ifindex)->discard.code;
    }

    int discard_fragment(unsigned ifindex) const
    {
        const iwrange* range = get_range(ifindex);
        if (! range || range->we_version_compiled <= 11)
            return 0;
        return get_stats(ifindex)->discard.fragment;
    }

    int discard_retries(unsigned ifindex) const
    {
        const iwrange* range = get_range(ifindex);
        if (! range || range->we_version_compiled <= 11)
            return 0;
        return get_stats(ifindex)->discard.retries;
    }

    int discard_misc(unsigned ifindex) const
    {
        return get_stats(ifindex)->discard.misc;
    }

    int miss_beacon(unsigned ifindex) const
    {
        const iwrange* range = get_range(ifindex);
        if (! range || range->we_version_compiled <= 11)
            return 0;
        return get_stats(ifindex)->miss.beacon;
    }

    int bitrate(unsigned ifindex, char* buffer, int buflen)
    {
        struct iwreq wrq;
        if (get_ext(ifindex, SIOCGIWRATE, &wrq) == -1)
        {
            ierror(ifindex, "SIOCGIWRATE");
            if (buflen > 0)
                buffer[0] = '\0';
            return 0;
        }

        return snprintf(buffer, buflen,
                        "%c%.0Bb/s",
                        wrq.u.bitrate.fixed ? '=' : ':',
                        (float) wrq.u.bitrate.value);
    }

    int sensitivity(unsigned ifindex, char* buffer, int buflen)
    {
        const iwrange* range = get_range(ifindex);
        struct iwreq wrq;
        if ((range && range->sensitivity == 0)
            || get_ext(ifindex, SIOCGIWSENS, &wrq) == -1)
        {
            if (! range || range->sensitivity > 0)
                ierror(ifindex, "SIOCGIWSENS");
            if (buflen > 0)
                buffer[0] = '\0';
            return 0;
        }

        if (range)
        {
            if (wrq.u.sens.value < 0)
                return snprintf(buffer, buflen,
                                "%c%'d dBm",
                                wrq.u.sens.fixed ? '=' : ':',
                                wrq.u.sens.value);
            else
                return snprintf(buffer, buflen,
                                "%c%'d/%'d",
                                wrq.u.sens.fixed ? '=' : ':',
                                wrq.u.sens.value,
                                range->sensitivity);
        }
        else
        {
            return snprintf(buffer, buflen,
                            "%c%'d",
                            wrq.u.sens.fixed ? '=' : ':',
                            wrq.u.sens.value);
        }
    }

    int fragment_thr(unsigned ifindex, char* buffer, int buflen)
    {
        struct iwreq wrq;
        if (get_ext(ifindex, SIOCGIWFRAG, &wrq) == -1)
        {
            ierror(ifindex, "SIOCGIWFRAG");
            if (buflen > 0)
                buffer[0] = '\0';
            return 0;
        }

        if (wrq.u.frag.disabled)
        {
            return snprintf(buffer, buflen, ":off");
        }
        else
        {
            return snprintf(buffer, buflen,
                            "%c%'d B",
                            wrq.u.frag.fixed ? '=' : ':',
                            wrq.u.frag.value);
        }
    }

private:

    const iwstats* get_stats(unsigned ifindex) const
    {
        LOGGER_ASSERT1(ifindex < N, ifindex);
        return &_stats[ifindex];
    }

    const iwrange* get_range(unsigned ifindex) const
    {
        LOGGER_ASSERT1(ifindex < N, ifindex);
        return _has_range[ifindex] ? &_range[ifindex] : NULL;
    }

    int get_ext(unsigned ifindex, int request, struct iwreq* pwrq)
    {
        LOGGER_ASSERT1(ifindex < N, ifindex);
        strncpy(pwrq->ifr_name, _ifname[ifindex], sizeof(pwrq->ifr_name));
        return ioctl(_skfd, request, pwrq);
    }

    void ierror(unsigned ifindex, const char* ioctl)
    {
        LOGGER_ASSERT1(ifindex < N, ifindex);
        LOGGER_PWARN("ioctl(%s, %s)", _ifname[ifindex], ioctl);
    }

    int init_range_info()
    {
        unsigned i = 0;
        char* argv[] = { (char*)this, (char*)&i };
        iw_enum_devices(_skfd, init_range_info_handler, argv, 2);
        return i;
    }

    static int init_range_info_handler(int skfd, char* ifname, char* argv[], int argc)
    {
        LOGGER_ASSERT1(argc >= 2, argc);
        IWStats* that = (IWStats*) argv[0];
        unsigned* i = (unsigned*) argv[1];
        LOGGER_ASSERT(that);
        LOGGER_ASSERT(i);

        that->init_range_info_handler(ifname, *i);
        return 0; // ignored
    }

    void init_range_info_handler(char* ifname, unsigned& i)
    {
        LOGGER_ASSERT1(i < N, i);

        // ensure interface is up and running
        // don't monitor lo or ppp either

        struct ifreq ifr;
        memset(&ifr, 0, sizeof(ifr));
        strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
        if (ioctl(_skfd, SIOCGIFFLAGS, &ifr) == -1)
        {
            LOGGER_PWARN("ioctl(%s, SIOCGIFFLAGS)", ifname);
            return;
        }
        if (! BITMASK_ARESET(ifr.ifr_flags, IFF_UP | IFF_RUNNING))
            return;
        // Note: Don't check IFF_LOWER_UP here. Doesn't appear to be set by SIOCGIFFLAGS
        if (BITMASK_ANYSET(ifr.ifr_flags, IFF_LOOPBACK | IFF_POINTOPOINT))
            return;

        // get the ranges

        if (iw_get_range_info(_skfd, ifname, &_range[i]) < 0)
        {
            int saved_errno = errno;

            struct iwreq wrq;
            if (iw_get_ext(_skfd, ifname, SIOCGIWNAME, &wrq) < 0)
                return; // not a wireless interface

            errno = saved_errno;
            LOGGER_PWARN("iw_get_range_info(%s)", ifname);
            _has_range[i] = false;
        }
        else
        {
            _has_range[i] = true;
        }

        // let's make sure we can get stats for this interface...

        if (iw_get_stats(_skfd, ifname, &_stats[i], &_range[i], _has_range[i]) < 0)
        {
            LOGGER_PWARN("iw_get_stats(%s)", ifname);
            return;
        }

        strncpy(_ifname[i], ifname, sizeof(_ifname[i]));
        ++i;
    }

private:

    static const unsigned N = 2;

    int _skfd;

    char _ifname[N][IFNAMSIZ];

    iwrange _range[N];
    bool _has_range[N];

    iwstats _stats[N];
};

#endif

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             PPPStats                              //
//                                                                   //
///////////////////////////////////////////////////////////////////////

#ifdef __linux__

class PPPStats
    : public NetStats<struct ppp_stats, 3>
{
public:

    PPPStats()
    {}

    virtual int snapshot()
    {
        clear();

        struct ifaddrs* ifa;
        if (getifaddrs(&ifa) == -1)
        {
            LOGGER_PWARN("getifaddrs");
            return -1;
        }

        unsigned i = 0;
        for (struct ifaddrs* p = ifa; p; p = p->ifa_next)
        {
            if (p->ifa_addr == NULL)
                continue;
            if (p->ifa_addr->sa_family != AF_INET)
                continue;
            if (! BITMASK_ARESET(p->ifa_flags, IFF_UP | IFF_RUNNING | IFF_POINTOPOINT))
                continue;
#ifdef IFF_LOWER_UP
            if (! BITMASK_ISSET(p->ifa_flags, IFF_LOWER_UP))
                continue;
#endif

            LOGGER_ASSERT1(i < count(), i);

            if (i == 0 && open() == -1)
                break;

            LOGGER_ASSERT1(i < count(), count());
            if (i >= count())
            {
                LOGGER_WARN("PPPStats: N (%u) too small", count());
                break;
            }

            struct timeval now;
            (void) gettimeofday(&now, NULL); // FIXME: don't use gettimeofday

            struct ifreq ifr;
            memset(&ifr, 0, sizeof(ifr));
            strncpy(ifr.ifr_name, p->ifa_name, sizeof(ifr.ifr_name));
            ifr.ifr_data = (caddr_t) &_stats[i];
            if (ioctl(_sockfd, SIOCGPPPSTATS, &ifr) == -1)
            {
                LOGGER_PWARN("ioctl(%s, SIOCGPPPSTATS)", p->ifa_name);
                continue;
            }

            (void) strncpy(_ifname[i], p->ifa_name, sizeof(_ifname[i]));
            memcpy(&_timestamp[i], &now, sizeof(_timestamp[i]));

            i++;
        }

        freeifaddrs(ifa);

        return i;
    }

    int version(const char* ifname, char buffer[16])
    {
        if (open() == -1)
            return -1;

        memset(buffer, 0, 16);

        struct ifreq ifr;
        memset(&ifr, 0, sizeof(ifr));
        strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
        ifr.ifr_data = buffer;
        if (ioctl(_sockfd, SIOCGPPPVER, &ifr) == -1)
        {
            LOGGER_PERROR("ioctl(%s, SIOCGPPPVER)", ifname);
            return -1;
        }

        return 0;
    }
};

#endif

#endif
