
#ifndef RTP_H_
#define RTP_H_

/* C99 requires that stdint.h only exposes UINT16_MAX if this is defined: */
#ifndef __STDC_LIMIT_MACROS
#  define __STDC_LIMIT_MACROS
#endif

#include <alloca.h>
#include <math.h>

#include <map>
#include <memory>
#include <set>
#include <vector>

#include "UDP.h"

static const int _rtp_srand = ( srand((unsigned)time(NULL)), 0 );

///////////////////////////////////////////////////////////////////////
//                                                                   //
// RTP                                                               //
//                                                                   //
///////////////////////////////////////////////////////////////////////

struct RTP
{
    static const unsigned VERSION           = 2;
    static const uint16_t MIN_SEQUENTIAL    = 2;
    static const uint16_t MAX_DROPOUT       = 3000;
    static const uint16_t MAX_MISORDER      = 300; // 2MBits/s / (1400 - 12 - 2) = 190

    static const struct timeval EPOCH;

protected:

    struct Header {
#ifdef __BIG_ENDIAN_BITFIELD
        unsigned int        version:2;  /* protocol version           */
        unsigned int        p:1;        /* padding flag               */
        unsigned int        x:1;        /* header extension flag      */
        unsigned int        cc:4;       /* CSRC count                 */
        unsigned int        m:1;        /* marker bit                 */
        unsigned int        pt:7;       /* payload type               */
#else
        unsigned int        cc:4;       /* CSRC count                 */
        unsigned int        x:1;        /* header extension flag      */
        unsigned int        p:1;        /* padding flag               */
        unsigned int        version:2;  /* protocol version           */
        unsigned int        pt:7;       /* payload type               */
        unsigned int        m:1;        /* marker bit                 */
#endif
        uint16_t            seq;        /* sequence number            */
        uint32_t            ts;         /* timestamp                  */
        uint32_t            ssrc;       /* synchronization source     */
        uint32_t            csrc[0];    /* optional CSRC list         */

        Header(unsigned cc = 0)
        {
            memset(this, 0, sizeof(*this) + cc * sizeof(uint32_t));
            this->cc = cc;
        }

        void resize(unsigned cc)
        {
            this->cc = cc;
        }

        size_t length() const
        {
            return sizeof(*this) + cc * sizeof(uint32_t);
        }

        // placement new: call with new (cc, p) RRPacket(count)
        void* operator new(size_t len, unsigned cc, void* p) throw()
        {
            LOGGER_ASSERT1(len == sizeof(Header), len);
            LOGGER_ASSERT(p != NULL);
            return p;
        }
    } __attribute__ ((__packed__));

#define RTPHeader_alloca(cc) new (cc, reinterpret_cast<RTP::Header*>(alloca(sizeof(RTP::Header) + (cc) * sizeof(uint32_t)))) RTP::Header(cc)

    static void ntoh(Header* hdr)
    {
        hdr->seq = ntohs(hdr->seq);
        hdr->ts = ntohl(hdr->ts);
        hdr->ssrc = ntohl(hdr->ssrc);

        for (unsigned i = 0; i < hdr->cc; ++i)
            hdr->csrc[i] = ntohl(hdr->csrc[i]);
    }

    static void hton(Header* hdr)
    {
        hdr->seq = htons(hdr->seq);
        hdr->ts = htonl(hdr->ts);
        hdr->ssrc = htonl(hdr->ssrc);

        for (unsigned i = 0; i < hdr->cc; ++i)
            hdr->csrc[i] = htonl(hdr->csrc[i]);
    }

    static inline int16_t diff16(uint16_t a, uint16_t b)
    {
        return (a - b) & ((1 << 16) - 1);
    }

    static inline uint16_t udiff16(uint16_t a, uint16_t b)
    {
        if (a >= b)
            return (uint16_t)(a - b);
        else
            return (uint16_t)(((1<<16) - 1) + (a - b));
    }
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
// RTCP                                                              //
//                                                                   //
///////////////////////////////////////////////////////////////////////

struct RTCP
{
protected:

    enum
    {
        RTCP_SR   = 200,            /* Sender Report */
        RTCP_RR   = 201,            /* Receiver Report */
        RTCP_SDES = 202,            /* Source Description */
        RTCP_BYE  = 203,            /* Goodbye */
        RTCP_APP  = 204             /* Application-Defined */
    };

    struct Header
    {
#ifdef __BIG_ENDIAN_BITFIELD
        unsigned int    version:2;  /* protocol version */
        unsigned int    p:1;        /* padding flag */
        unsigned int    count:5;    /* varies by packet type */
        unsigned int    pt:8;       /* RTCP packet type */
#else
        unsigned int    count:5;    /* varies by packet type */
        unsigned int    p:1;        /* padding flag */
        unsigned int    version:2;  /* protocol version */
        unsigned int    pt:8;       /* RTCP packet type */
#endif
        uint16_t        length;     /* pkt len in words, w/o this word */

        Header()
        {
            memset(this, 0, sizeof(*this));
            version = RTP::VERSION;
            length = sizeof(*this);
        }

        void hton()
        {
            length = htons(length);
        }

        void ntoh()
        {
            length = ntohs(length);
        }
    } __attribute__ ((__packed__));

    struct RRItem
    {
        uint32_t        ssrc;       /* data source being reported */
#ifdef __BIG_ENDIAN_BITFIELD
        unsigned int    fraction:8; /* fraction lost since last SR/RR */
        int             lost:24;    /* cumul. no. pkts lost (signed!) */
#else
        int             lost:24;    /* cumul. no. pkts lost (signed!) */
        unsigned int    fraction:8; /* fraction lost since last SR/RR */
#endif
        uint32_t        last_seq;   /* extended last seq. no. received */
        uint32_t        jitter;     /* interarrival jitter */
        uint32_t        lsr;        /* last SR packet from this source */
        uint32_t        dlsr;       /* delay since last SR packet */

        void hton()
        {
            ssrc = htonl(ssrc);
#if BYTE_ORDER == LITTLE_ENDIAN
            lost = ((lost & 0xFF) << 16) | (lost & 0xFF00) | ((lost & 0xFF0000) >> 16);
#endif
            last_seq = htonl(last_seq);
            jitter = htonl(jitter);
            lsr = htonl(lsr);
            dlsr = htonl(dlsr);
        }

        void ntoh()
        {
            ssrc = ntohl(ssrc);
#if BYTE_ORDER == LITTLE_ENDIAN
            lost = ((lost & 0xFF) << 16) | (lost & 0xFF00) | ((lost & 0xFF0000) >> 16);
#endif
            last_seq = ntohl(last_seq);
            jitter = ntohl(jitter);
            lsr = ntohl(lsr);
            dlsr = ntohl(dlsr);
        }
    } __attribute__ ((__packed__));

    /* reception report (RR) */
    struct RRPacket
        : public Header
    {
        uint32_t        ssrc;       /* receiver generating this report */
        RRItem          items[0];   /* variable-length list */

        RRPacket(unsigned _count = 0)
        {
            memset(&this->ssrc, 0, sizeof(*this) - sizeof(Header) + _count * sizeof(RRItem));
            pt = RTCP_RR;
            count = _count;
            length = sizeof(*this) + count * sizeof(RRItem);
            memset(items, 0, count * sizeof(RRItem));
        }

#define RRPacket_alloca(count) new (count, reinterpret_cast<RTCP::RRPacket*>(alloca(sizeof(RTCP::RRPacket) + (count) * sizeof(RTCP::RRItem)))) RTCP::RRPacket(count)

        // placement new: call with new (count, p) RRPacket(count)
        void* operator new(size_t len, unsigned count, void* p) throw()
        {
            LOGGER_ASSERT1(len == sizeof(RRPacket), len);
            LOGGER_ASSERT(p != NULL);
            return p;
        }

        void resize(unsigned _count)
        {
            if (count != _count)
            {
                count = _count;
                length = sizeof(*this) + count * sizeof(RRItem);
            }
        }

        const RRItem* item(unsigned i) const
        {
            LOGGER_ASSERT1(pt == RTCP_RR, pt);
            LOGGER_ASSERT2(i < count, i, count);
            return &items[i];
        }

        RRItem* item(unsigned i)
        {
            LOGGER_ASSERT1(pt == RTCP_RR, pt);
            LOGGER_ASSERT2(i < count, i, count);
            return &items[i];
        }

        const RRItem* find(uint32_t ssrc) const
        {
            for (unsigned i = 0; i < count; ++i)
            {
                if (items[i].ssrc == ssrc)
                    return &items[i];
            }
            return NULL;
        }

        RRItem* find(uint32_t ssrc)
        {
            for (unsigned i = 0; i < count; ++i)
            {
                if (items[i].ssrc == ssrc)
                    return &items[i];
            }
            return NULL;
        }

        void hton()
        {
            Header::hton();
            ssrc = htonl(ssrc);
            for (unsigned i = 0; i < count; ++i)
                items[i].hton();
        }

        void ntoh()
        {
            Header::ntoh();
            ssrc = ntohl(ssrc);
            for (unsigned i = 0; i < count; ++i)
                items[i].ntoh();
        }
    } __attribute__ ((__packed__));

    /* sender report (SR) */
    struct SRPacket
        : public Header
    {
        uint32_t    ssrc;       /* sender generating this report    */
        uint32_t    ntp_sec;    /* NTP timestamp                    */
        uint32_t    ntp_frac;
        uint32_t    rtp_ts;     /* RTP timestamp                    */
        uint32_t    psent;      /* packets sent                     */
        uint32_t    osent;      /* octets sent                      */
        RRItem      items[0];   /* variable-length list             */

        SRPacket(unsigned _count = 0)
        {
            memset(&this->ssrc, 0, sizeof(*this) - sizeof(Header) + _count * sizeof(RRItem));
            pt = RTCP_SR;
            count = _count;
            length = sizeof(*this) + count * sizeof(RRItem);
        }

#define SRPacket_alloca(count) new (count, reinterpret_cast<RTCP::SRPacket*>(alloca(sizeof(RTCP::SRPacket) + (count) * sizeof(RTCP::RRItem)))) RTCP::SRPacket(count)

        // placement new: call with new (count, p) SRPacket(count)
        void* operator new(size_t len, unsigned count, void* p) throw()
        {
            LOGGER_ASSERT1(len == sizeof(SRPacket), len);
            LOGGER_ASSERT(p != NULL);
            return p;
        }

#if 0
        // call with: new(count) SRPacket(count)
        void* operator new(size_t n, unsigned count) throw()
        {
            return calloc(1, n + count * sizeof(RRItem));
        }
#endif

        void resize(unsigned _count)
        {
            if (count != _count)
            {
                count = _count;
                length = sizeof(*this) + count * sizeof(RRItem);
            }
        }

        struct timeval ntp() const
        {
            struct timeval tv;
            tv.tv_sec = ntp_sec;
            tv.tv_usec = ntp_frac;
            return tv;
        }

        const uint32_t lsr() const
        {
            return (ntp_sec << 16) | (ntp_frac >> 16);
        }

        static const uint32_t lsr(const struct timeval& t)
        {
            return ((uint32_t)t.tv_sec << 16) | ((uint32_t)t.tv_usec >> 16);
        }

        const RRItem* item(unsigned i) const
        {
            LOGGER_ASSERT1(pt == RTCP_SR, pt);
            LOGGER_ASSERT2(i < count, i, count);
            return &items[i];
        }

        RRItem* item(unsigned i)
        {
            LOGGER_ASSERT1(pt == RTCP_SR, pt);
            LOGGER_ASSERT2(i < count, i, count);
            return &items[i];
        }

        void hton()
        {
            Header::hton();
            ssrc = htonl(ssrc);
            ntp_sec = htonl(ntp_sec);
            ntp_frac = htonl(ntp_frac);
            rtp_ts = htonl(rtp_ts);
            psent = htonl(psent);
            osent = htonl(osent);
            for (unsigned i = 0; i < count; ++i)
                items[i].hton();
        }

        void ntoh()
        {
            Header::ntoh();
            ssrc = ntohl(ssrc);
            ntp_sec = ntohl(ntp_sec);
            ntp_frac = ntohl(ntp_frac);
            rtp_ts = ntohl(rtp_ts);
            psent = ntohl(psent);
            osent = ntohl(osent);
            for (unsigned i = 0; i < count; ++i)
                items[i].ntoh();
        }
    } __attribute__ ((__packed__));

    struct ByePacket
        : public Header
    {
        uint32_t        items[0];   /* list of sources */
        // no reason

        ByePacket(unsigned _count = 0)
        {
            pt = RTCP_BYE;
            count = _count;
            length = sizeof(*this) + count * sizeof(uint32_t);
            memset(items, 0, count * sizeof(RRItem));
        }

        uint32_t src(unsigned i) const
        {
            LOGGER_ASSERT1(pt == RTCP_BYE, pt);
            LOGGER_ASSERT2(i < count, i, count);
            return items[i];
        }

        void hton()
        {
            Header::hton();
            for (unsigned i = 0; i < count; ++i)
                items[i] = htonl(items[i]);
        }

        void ntoh()
        {
            Header::ntoh();
            for (unsigned i = 0; i < count; ++i)
                items[i] = ntohl(items[i]);
        }
    } __attribute__ ((__packed__));

    struct AppPacket
        : public Header
    {
        uint32_t        src;
        char            name[4];
        char            data[0];

        AppPacket()
        {
            memset(&this->src, 0, sizeof(*this) - sizeof(Header));
            pt = RTCP_APP;
        }

        void hton()
        {
            Header::hton();
            src = htonl(src);
        }

        void ntoh()
        {
            Header::ntoh();
            src = ntohl(src);
        }
    } __attribute__ ((__packed__));


    static uint16_t length(const Header* hdr)
    {
        switch (hdr->pt)
        {
        case RTCP_SR:       return sizeof(SRPacket) + hdr->count * sizeof(RRItem);
        case RTCP_RR:       return sizeof(RRPacket) + hdr->count * sizeof(RRItem);
//         case RTCP_SDES:     return;
        case RTCP_BYE:      return sizeof(ByePacket) + hdr->count * sizeof(uint32_t);
        case RTCP_APP:      return sizeof(AppPacket) + hdr->count * sizeof(char);
        default:            UNREACHABLE();
                            return 0;
        }
    }

    static void ntoh(Header* hdr)
    {
        switch (hdr->pt)
        {
        case RTCP_SR:       reinterpret_cast<SRPacket*>(hdr)->ntoh();
                            return;
        case RTCP_RR:       reinterpret_cast<RRPacket*>(hdr)->ntoh();
                            return;
//         case RTCP_SDES:     reinterpret_cast<SDESPacket*>(hdr)->ntoh();
//                             return;
        case RTCP_BYE:      reinterpret_cast<ByePacket*>(hdr)->ntoh();
                            return;
        case RTCP_APP:      reinterpret_cast<AppPacket*>(hdr)->ntoh();
                            return;
        default:            UNREACHABLE();
        }
    }

    static void hton(Header* hdr)
    {
        switch (hdr->pt)
        {
        case RTCP_SR:       reinterpret_cast<SRPacket*>(hdr)->hton();
                            return;
        case RTCP_RR:       reinterpret_cast<RRPacket*>(hdr)->hton();
                            return;
//         case RTCP_SDES:     reinterpret_cast<SDESPacket*>(hdr)->hton();
//                             return;
        case RTCP_BYE:      reinterpret_cast<ByePacket*>(hdr)->hton();
                            return;
        case RTCP_APP:      reinterpret_cast<AppPacket*>(hdr)->hton();
                            return;
        default:            UNREACHABLE();
        }
    }

    static inline uint32_t udiff32(uint32_t a, uint32_t b)
    {
        if (a >= b)
            return (uint32_t)(a - b);
        else
            return (uint32_t)((uint32_t)0xFFFFFFFF - b + a);
    }

#ifdef LOGGER_OSTREAM
    friend std::ostream& operator<<(std::ostream& out, const Header* hdr)
    {
        if (! out)
            return out;

        switch (hdr->pt)
        {
        case RTCP_SR:       return out << "SR";
        case RTCP_RR:       return out << "RR";
        case RTCP_SDES:     return out << "SDES";
        case RTCP_BYE:      return out << "BYE";
        case RTCP_APP:      return out << "APP";

        default:            return out << "pt=" << hdr->pt;
        }
    }
#endif
};

class RTCPUDPSender
    : public UDPSender, protected RTCP
{
public:

    RTCPUDPSender(const struct sockaddr_in* dest)
        : UDPSender(dest)
    {}

    using UDPSender::send;

    virtual ssize_t send(RTCP::Header* hdr, int flags,
                         const struct sockaddr_in* dest = NULL)
    {
        const size_t len = hdr->length;
        hton(hdr);
        return UDPSender::send(hdr, len, flags, dest);
    }
};

class RTCPUDPReceiver
    : public UDPReceiver, protected RTCP
{
public:

    virtual ssize_t recv(RTCP::Header* hdr, size_t len, int flags,
                         struct timeval* timeout = NULL,
                         struct sockaddr_in* src = NULL)
    {
        for (;;)
        {
            const ssize_t n = UDPReceiver::recv(hdr, len, flags, timeout, src);
            if (n <= 0)
                return n;

            if (n <= (ssize_t)sizeof(RTCP::Header))
            {
                LOGGER_WARN("Ignoring RTCP msg: too short (%zd)", n);
                if (timeout && (timeout->tv_sec > 0 || timeout->tv_usec > 0))
                    continue;
                else
                    return 0;
            }

            ntoh(hdr);

            if (hdr->length != n)
            {
                LOGGER_WARN("Ignoring RTCP msg: invalid read: %'zd != %'hu", n, hdr->length);
                if (timeout && (timeout->tv_sec > 0 || timeout->tv_usec > 0))
                    continue;
                else
                    return 0;
            }

            if (hdr->length != RTCP::length(hdr))
            {
                LOGGER_WARN("Ignoring RTCP msg: invalid length: %'hu != %'hu", hdr->length, RTCP::length(hdr));
                if (timeout && (timeout->tv_sec > 0 || timeout->tv_usec > 0))
                    continue;
                else
                    return 0;
            }

            return n;
        }
        UNREACHABLE();
        return 0;
    }
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             RTPSender                             //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class RTPSender
   : public UDPSender
   , protected RTP
{
public:

    RTPSender(const struct sockaddr_in* dest)
        : UDPSender(dest)
        , _base_seq((uint16_t) rand())
    {
        do
        {
            _ssrc = (uint32_t) rand();
        } while (_ssrc == 0);

        _seq = _base_seq;
    }

    uint32_t ssrc() const
    {
        return _ssrc;
    }

    virtual size_t sndbufsiz() const
    {
        return UDPSender::sndbufsiz() - sizeof(RTP::Header);
    }

    virtual void sndbufsiz(int bufsiz)
    {
        UDPSender::sndbufsiz(bufsiz);
    }

    void discontinuity()
    {
        _seq += MAX_DROPOUT;
    }

    virtual ssize_t sendv(struct iovec* iov,
                          unsigned iovcnt,
                          int flags,
                          bool mark,
                          int pt,
                          uint32_t ts);

    static uint32_t rtp_compute_ts(unsigned frequency)
    {
        struct timeval tv;
        if (gettimeofday(&tv, NULL) == -1)
            return 0;
        tv -= EPOCH;
        return rtp_compute_ts(&tv, frequency);
    }

    static uint32_t rtp_compute_ts(const struct timeval* tv, unsigned frequency)
    {
        return (uint32_t)(tv->tv_sec * (int64_t)frequency
                        + tv->tv_usec * (int64_t)frequency / 1000000);
    }

    static uint32_t rtp_compute_ts(int64_t pts, unsigned frequency)
    {
#if 0
        // don't use MMAL pts which seems to be linearly incremented
        // by the framerate regardless of the actual elapsed time!

        struct timeval tv;
        if (gettimeofday(&tv, NULL) == -1)
            pts = 0;
        else
            pts = (tv.tv_sec * 1000000LL) + tv.tv_usec;
#endif

        // see vlc's rtp_compute_ts() in rtp.c

        /* This is an overflow-proof way of doing:
         * return pts * (int64_t)i_clock_rate / CLOCK_FREQ;
         *
         * NOTE: this plays nice with offsets because the (equivalent)
         * calculations are linear. */

        // i_clock_rate is 90000 for H264
        // CLOCK_FREQ is 1000000

        lldiv_t q = lldiv(pts, (int64_t)1000000);
        return (uint32_t)(q.quot * (int64_t)frequency
                        + q.rem * (int64_t)frequency / (int64_t)1000000);
    }

private:

    uint32_t _ssrc;
    const uint16_t _base_seq;
    uint32_t _seq;
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                          RTPLargeSender                           //
//                                                                   //
///////////////////////////////////////////////////////////////////////

// send packets larger than bufsiz()
// last RTP "fragment" is marked
class RTPLargeSender
    : public RTPSender
{
public:

    RTPLargeSender(const struct sockaddr_in* dest)
        : RTPSender(dest)
    {}

    ssize_t sendv(struct iovec* iov,
                  unsigned iovcnt,
                  int flags,
                  bool mark,
                  int pt,
                  uint32_t ts);
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                         RTPBoundedSender                          //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class RTPBoundedSender
    : public UDPBounded
    , protected RTP, protected RTCP
{
protected:

    static const size_t     MAX_LSR = 5;
    static const uint32_t   MIN_PSENT = 50;
    static const uint32_t   SR_PTS_DELAY = 1 * 90000            // 1sec (per ssrc)
                                         + 0 * 90000 / 1000000; // 0usec
                                                                // FIXME: frequency
    static const uint32_t   MIN_PROBES = 4; // must be <= SR_PTS_DELAY / 90000 * MAX_LSR;

private:

    struct SRPacket1
        : public RTCP::SRPacket
    {
        uint32_t        last_seq;   /* extended last seq. no. sent */

        SRPacket1()
            : RTCP::SRPacket(0)
        {}

        SRPacket1(const SRPacket1& rhs)
            : RTCP::SRPacket(rhs)
        {
            memcpy(this, &rhs, sizeof(SRPacket1));
            count = 0;
            length = sizeof(RTCP::SRPacket); // FIXME: that's going to be trouble
        }

        SRPacket1(const RTCP::SRPacket& rhs)
            : RTCP::SRPacket(rhs)
            , last_seq(0)
        {
            memcpy(this, &rhs, sizeof(RTCP::SRPacket));
            count = 0;
            length = sizeof(RTCP::SRPacket); // FIXME: that's going to be trouble
        }

        // order by ntp_sec, ntp_frac, ssrc
        bool operator<(const struct SRPacket1& rhs) const
        {
            return ntp_sec < rhs.ntp_sec
                || (ntp_sec == rhs.ntp_sec && ntp_frac < rhs.ntp_frac)
                || (ntp_sec == rhs.ntp_sec && ntp_frac == rhs.ntp_frac && ssrc < rhs.ssrc);
        }
    } __attribute__ ((__packed__));

public:

    RTPBoundedSender(const struct sockaddr_in* dest)
        : UDPBounded(dest)
        , _seq((uint16_t) rand())
        , _psent(0)
        , _last_sr_pts(0)
        , _last_sr_psent(0)
    {
        do
        {
            _ssrc = (uint32_t) rand();
        } while (_ssrc == 0);

        if (refresh_sockets() != -1)
            sndbufsiz(so_sndbuf());
    }

    uint32_t ssrc() const
    {
        return _ssrc;
    }

    size_t sndbufsiz() const
    {
        return UDPBounded::sndbufsiz()
                - sizeof(RTP::Header)
                - sizeof(uint32_t); // one csrc
    }

    void sndbufsiz(int bufsiz)
    {
        UDPBounded::sndbufsiz(bufsiz);
    }

    float link_quality(UpgradableRWLock::ReaderWriterGuard& rwguard) const;

    ssize_t sendv(struct iovec* iov,
                  unsigned iovcnt,
                  int flags,
                  bool mark,
                  int pt,
                  uint32_t rtp_ts);

    void discontinuity()
    {
        _seq += MAX_DROPOUT;
    }

protected:

    virtual void add_socket(UpgradableRWLock::WriterGuard& wguard,
                            const UDP* udp);

    virtual void remove_socket(UpgradableRWLock::WriterGuard& wguard,
                               const UDP* udp);

    // add new entry into ratio
    static void scale_up(std::map<uint32_t, float>& ratio, uint32_t ssrc);

    // add new entries from b into a
    static void scale_up(std::map<uint32_t, float>& a,
                         const std::map<uint32_t, float>& b);

    // remove entry from ratio
    static void scale_down(std::map<uint32_t, float>& ratio, uint32_t ssrc);

    int wait_for_available_output_locked(UpgradableRWLock::ReaderWriterGuard& rwguard,
                                         struct timeval* timeout = NULL);

    int wait_for_available_output_banned_locked(UpgradableRWLock::ReaderWriterGuard& rwguard,
                                                struct timeval* timeout = NULL);

    int wait_for_available_output_not_banned_locked(UpgradableRWLock::ReaderWriterGuard& rwguard,
                                                    struct timeval* timeout = NULL);

    unsigned available_sockets_locked(UpgradableRWLock::ReaderWriterGuard& rwguard) const
    {
        unsigned n = 0;
        for (std::map<uint32_t, float>::const_iterator it = _pratio.begin();
             it != _pratio.end();
             ++it)
        {
            if (it->second > 0)
                ++n;
        }
        LOGGER_ASSERT2(n <= sockets_locked(rwguard), n, sockets_locked(rwguard));
        return n;
    }

private:

    static uint32_t ssrc(const UDP* udp)
    {
        // TODO: create a map <const UDP*, uint32_t> so ssrc's are not re-used between RTP sessions
        return udp == NULL ? INADDR_ANY : udp->addr()->sin_addr.s_addr;
    }

    SRPacket1* srpackets_find(UpgradableRWLock::ReaderWriterGuard&,
                              uint32_t ssrc)
    {
        // Note: although this is a non-const version
        //       it is not necessary to create a WriterGuard
        //       to manipulate elements of _srpackets
        for (std::vector<SRPacket1>::iterator it = _srpackets.begin();
             it != _srpackets.end();
             ++it)
        {
            if (it->ssrc == ssrc)
                return &(*it);
        }
        return NULL;
    }

    const SRPacket1* lsr_find(uint32_t ssrc, uint32_t lsr) const
    {
        for (std::set<SRPacket1>::const_reverse_iterator it = _lsr.rbegin();
             it != _lsr.rend();
             ++it)
        {
            if (it->lsr() == lsr && it->ssrc == ssrc)
                return &(*it);
        }
        return NULL;
    }

    const RTCP::SRPacket* lsr_front(uint32_t ssrc) const
    {
        for (std::set<SRPacket1>::const_iterator it = _lsr.begin();
             it != _lsr.end();
             ++it)
        {
            if (it->ssrc == ssrc)
                return &(*it);
        }
        return NULL;
    }

    // return the first element in _lsr for ssrc that is after rtp_ts
    const RTCP::SRPacket* lsr_front(uint32_t ssrc, uint32_t rtp_ts) const
    {
        for (std::set<SRPacket1>::const_iterator it = _lsr.begin();
             it != _lsr.end();
             ++it)
        {
            if (it->ssrc == ssrc && it->rtp_ts >= rtp_ts)
                return &(*it);
        }
        return NULL;
    }

    const RTCP::SRPacket* lsr_back(uint32_t ssrc) const
    {
        for (std::set<SRPacket1>::const_reverse_iterator it = _lsr.rbegin();
             it != _lsr.rend();
             ++it)
        {
            if (it->ssrc == ssrc)
                return &(*it);
        }
        return NULL;
    }

    // return the first element is _lsr for ssrc that is before rtp_ts
    const RTCP::SRPacket* lsr_back(uint32_t ssrc, uint32_t rtp_ts) const
    {
        const RTCP::SRPacket* match = NULL;
        for (std::set<SRPacket1>::const_iterator it = _lsr.begin();
             it != _lsr.end();
             ++it)
        {
            if (it->ssrc != ssrc)
                continue;
            if (it->rtp_ts <= rtp_ts)
            {
                match = &(*it);
                continue;
            }
            if (it->rtp_ts > rtp_ts)
                break;
        }
        return match;
    }

    // return the first element in _lrr for ssrc
    std::map<SRPacket1, RTCP::RRItem>::const_iterator lrr_front(uint32_t ssrc) const
    {
        for (std::map<SRPacket1, RTCP::RRItem>::const_iterator it = _lrr.begin();
             it != _lrr.end();
             ++it)
        {
            if (it->first.ssrc == ssrc)
                return it;
        }
        return _lrr.end();
    }

    // return the first element in _lrr for ssrc that is after rtp_ts
    std::map<SRPacket1, RTCP::RRItem>::const_iterator lrr_front(uint32_t ssrc, uint32_t rtp_ts) const
    {
        for (std::map<SRPacket1, RTCP::RRItem>::const_iterator it = _lrr.begin();
             it != _lrr.end();
             ++it)
        {
            if (it->first.ssrc == ssrc && it->first.rtp_ts >= rtp_ts)
                return it;
        }
        return _lrr.end();
    }

    // return the first element is _lrr for ssrc that is before rtp_ts
    std::map<SRPacket1, RTCP::RRItem>::const_iterator lrr_back(uint32_t ssrc, uint32_t rtp_ts) const
    {
        std::map<SRPacket1, RTCP::RRItem>::const_iterator match = _lrr.end();
        for (std::map<SRPacket1, RTCP::RRItem>::const_iterator it = _lrr.begin();
             it != _lrr.end();
             ++it)
        {
            if (it->first.ssrc != ssrc)
                continue;
            if (it->first.rtp_ts <= rtp_ts)
            {
                match = it;
                continue;
            }
            if (it->first.rtp_ts > rtp_ts)
                break;
        }
        return match;
    }

    std::map<SRPacket1, RTCP::RRItem>::const_reverse_iterator lrr_back(uint32_t ssrc) const
    {
        for (std::map<SRPacket1, RTCP::RRItem>::const_reverse_iterator it = _lrr.rbegin();
             it != _lrr.rend();
             ++it)
        {
            if (it->first.ssrc == ssrc)
                return it;
        }
        return _lrr.rend();
    }

    void lrr_shrink(uint32_t rtp_ts);

    ssize_t sendSR(UpgradableRWLock::ReaderWriterGuard& rwguard,
                   uint32_t rtp_ts);

    ssize_t recvRR(UpgradableRWLock::ReaderWriterGuard& rwguard,
                   uint32_t rtp_ts);

    void recvRR(UpgradableRWLock::ReaderWriterGuard& rwguard,
                uint32_t rtp_ts, RTCP::RRPacket* rr);

    void dump_pratio() const
    {
        if (! LOGGER_IS_INFO())
            return;

        for (std::map<uint32_t, float>::const_iterator it = _pratio.begin();
             it != _pratio.end();
             ++it)
        {
            LOGGER_INFO("pratio[%08x] = %.2f%%", it->first, it->second * 100.0);
        }
    }

#ifdef LOGGER_OSTREAM
    friend std::ostream& operator<<(std::ostream& out, const std::set<SRPacket1>& set) // LSR
    {
        if (! out || set.empty())
            return out;

        const struct timeval t0 = set.rbegin()->ntp();

        struct timeval cur_t = { 0, 0 };
        for (std::set<SRPacket1>::const_reverse_iterator it = set.rbegin();
             it != set.rend();
             ++it)
        {
            const struct timeval t = it->ntp();
            if (t != cur_t)
            {
                cur_t = t;
                const uint32_t lsr = it->lsr();
                const double elapsed = ::elapsed(t0, t);
                out << std::endl
                    << '\t' << t << PrintF(" -%.1fs", elapsed) << " (" << lsr << "):";
            }
            out << " [ssrc=" << PrintF("%08x", it->ssrc) << " psent=" << it->psent << ']';
        }
        return out << std::endl;
    }

    friend std::ostream& operator<<(std::ostream& out, const std::map<SRPacket1, RTCP::RRItem>& map) // LRR
    {
        if (! out || map.empty())
            return out;

        const struct timeval t0 = map.rbegin()->first.ntp();
        const uint32_t rtp_ts0 = map.rbegin()->first.rtp_ts;
        struct timeval t1 = { 0, 0 };
        for (std::map<SRPacket1, RTCP::RRItem>::const_reverse_iterator it = map.rbegin();
             it != map.rend();
             ++it)
        {
            struct timeval t = it->first.ntp();
            if (t != t1)
            {
                t1 = t;
                const double elapsed = ::elapsed(t0, t1);
                out << std::endl
                    << '\t' << it->first.ntp() << PrintF(" -%.1fs", elapsed) << PrintF("/%.1fs", (rtp_ts0 - it->first.rtp_ts) / 90000.0) << ':'; // FIXME: frequency
            }
            out << " [ssrc=" << PrintF("%08x", it->first.ssrc) << " psent=" << it->first.psent << " lost=" << it->second.lost << ']';
        }
        return out << std::endl;
    }
#endif

private:

    uint32_t _ssrc;
    uint32_t _seq;

    // SR / RR

    // *** _srpackets, _last_seq, _t0, _pratio must be guarded ***
    // but elements of _srpackets, _last_seq, _t0 don't need to be guarded
    // elements of _pratio must be guarded too

    std::vector<SRPacket1> _srpackets; // next compound SRPacket to send
    std::map<uint32_t, uint32_t> _last_seq; // <seq, ssrc>
    std::map<uint32_t, struct timeval> _t0; // <ssrc, t0> TODO: remove (just add a fake entry in lrr)
    std::map<uint32_t, float> _pratio; // <ssrc, packets ratio>

    uint32_t _psent; // total packets sent
    uint32_t _last_sr_pts; // last SRPacket RTP ts
    uint32_t _last_sr_psent; // last SRPacket total psent
    std::set<SRPacket1> _lsr; // compound SRPacket's in flight
    std::map<SRPacket1, RTCP::RRItem> _lrr; // <sr, rr> received RRItem's
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                         RTPMarkedReceiver                         //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class RTPMarkedReceiver
    : public UDPReceiver, protected RTP
{
public:

    static const uint16_t MAX_MARKED        = 15;

public:

    RTPMarkedReceiver(uint32_t frequency = 0)
        : UDPReceiver()
        , _ssrc(0)
        , _probation(MIN_SEQUENTIAL - 1)
        , _curr_seq(0)
        , _deque_seq(0)
        , _max_seq(0)
        , _received(0)
        , _lost(0)
        , _dropped(0)
        , _strays(0)
        , _reset(0)
        , _last_lost(0)
        , _transit(0)
        , _jitter(0)
        , _frequency(frequency)
        , _last_ts(0)
    {}

    virtual ssize_t recv(void* buffer, size_t length,
                         struct timeval* timeout = NULL);

    uint32_t ssrc() const
    {
        return _ssrc;
    }

    uint32_t last_seq() const
    {
        return (uint32_t)(_cycles + _curr_seq);
    }

    uint32_t last_ts() const
    {
        return _last_ts;
    }

    unsigned long packets_received() const
    {
        return _received;
    }

    unsigned long packets_lost() const
    {
        return _lost;
    }

    unsigned long packets_dropped() const
    {
        return _dropped;
    }

    unsigned long packets_strays() const
    {
        return _strays;
    }

    unsigned session_resets() const
    {
        return _reset;
    }

    double jitter() const
    {
        return _jitter;
    }

private:

    ssize_t recv2(void* buffer, size_t length,
                  struct timeval* timeout);

    ssize_t recv2(RTP::Header* hdr, size_t length,
                  struct timeval* timeout,
                  struct sockaddr_in* src);

    void update_jitter(const RTP::Header* hdr);

private:

    struct RtpPacket
    {
        size_t len;
        RTP::Header hdr;
    };

    struct less16
    {
        bool operator() (uint16_t lhs, uint16_t rhs) const
        {
            return diff16(lhs, rhs) < 0;
        }

        bool operator() (const RTP::Header& lhs, const RTP::Header& rhs) const
        {
            return operator()(lhs.seq, rhs.seq);
        }

        bool operator() (const RtpPacket* lhs, const RtpPacket* rhs) const
        {
            return operator()(lhs->hdr, rhs->hdr);
        }
    };

    typedef std::set<RtpPacket*, less16> Queue;

#ifdef LOGGER_OSTREAM
    friend std::ostream& operator<<(std::ostream& out, const RtpPacket& pkt)
    {
        if (! out)
            return out;

        out << " " << pkt.hdr.seq;
        if (pkt.hdr.m)
            out << "(M)";
        return out;
    }

    friend std::ostream& operator<<(std::ostream& out, const Queue& q)
    {
        if (! out)
            return out;

        unsigned marked = 0;
        for (Queue::const_iterator it = q.begin(); it != q.end(); ++it)
        {
            if ((*it)->hdr.m)
                ++marked;
        }
        out << " (" << q.size() << '/' << marked << ')';

        for (Queue::const_iterator it = q.begin(); it != q.end(); )
        {
            out << *(*it);

            // move to the end of the sequence
            // ie. a marked fragment, or a break in seq

            const uint16_t curr = (*it)->hdr.seq;

            if (++it == q.end())
                break;
            if ((*it)->hdr.m)
                continue;

            uint16_t seq = (*it)->hdr.seq;
            if (diff16(seq, curr) != 1)
                continue;

            for (;;)
            {
                Queue::const_iterator next = it;
                if (++next == q.end())
                    break;
                if (diff16((*next)->hdr.seq, seq) != 1)
                    break;
                it = next;
                seq = (*it)->hdr.seq;
                if ((*it)->hdr.m)
                    break;
            }

            if (diff16((*it)->hdr.seq, curr) > 1)
                out << " ...";
        }
        return out;
    }
#endif

    void advance_in_sequence(Queue::iterator& it) const
    {
        const uint16_t seq = (*it)->hdr.seq;
        ++it;
        if (it == _queue.end())
            return;
        if ((*it)->hdr.seq != (uint16_t)(seq + 1))
            it = _queue.end();
    }

    bool pending_input() const
    {
        return ! _queue.empty()
            && (*_queue.begin())->hdr.seq == ((uint16_t)(_curr_seq + 1));
    }

    unsigned queue_count_marked() const
    {
        unsigned marked = 0;
        for (Queue::const_iterator it = _queue.begin(); it != _queue.end(); ++it)
        {
            if ((*it)->hdr.m)
                ++marked;
        }
        return marked;
    }

    void queue_clear()
    {
        for (Queue::iterator it = _queue.begin(); it != _queue.end(); ++it)
            free(*it);
        _queue.clear();
#ifdef LOGGER_OSTREAM
        LOGGER_DEBUG("_queue:");
#endif
    }

    bool queue_insert(RTP::Header* hdr, size_t len)
    {
        RtpPacket* pkt = reinterpret_cast<RtpPacket*>(malloc(sizeof(RtpPacket) + len - sizeof(RTP::Header)));
        pkt->len = len;
        memcpy(&pkt->hdr, hdr, len);

        std::pair<Queue::iterator, bool> pair = _queue.insert(pkt);

#ifdef LOGGER_OSTREAM
        if (LOGGER_IS_DEBUG())
        {
            LOGGER_ODEBUG(cdbg) << "_queue:" << _queue;
        }
#endif

        return pair.second;
    }

    ssize_t queue_pop(void* buffer, size_t length);

    void queue_drop();

private:

    Queue _queue;

    uint32_t _ssrc;
    uint16_t _probation;        /* seq. packets till source is valid */

    uint16_t _base_seq;         /* base seq number                   */
    uint16_t _curr_seq;         /* last delivered seq number         */
    uint16_t _deque_seq;        /* last dequeued seq number          */
    uint16_t _max_seq;          /* highest seq. number seen          */

    unsigned long _cycles;      /* shifted count of seq. cycles      */

    unsigned long _received;    /* # packets received                */
    unsigned long _lost;        /* # packets lost                    */
    unsigned long _dropped;     /* # packets dropped                 */
    unsigned long _strays;      /* # stray packets (ie. resent)      */
    unsigned _reset;            /* # resets                          */

    unsigned long _last_lost;   /* last # packets lost               */
    uint32_t _transit;          /* relative trans time for prev pkt  */
    double _jitter;             /* estimated jitter                  */
    const uint32_t _frequency;

    uint32_t _last_ts;          /* last delivered ts                 */
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                            RTPReceiver                            //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class RTPReceiver
    : public UDPReceiver, protected RTP
    , public RTCPUDPSender
{
public:

    static const unsigned MAX_MARKED        = 15;
    static const unsigned MAX_MILLISEC      = 500;

public:

    RTPReceiver(uint32_t frequency = 0)
        : UDPReceiver(), RTCPUDPSender(NULL)
        , _ssrc(0)
        , _base_seq(0)
        , _curr_seq(0)
        , _max_seq(0)
        , _probation(MIN_SEQUENTIAL)
        , _curr_ts(0)
        , _received(0)
        , _lost(0)
        , _dropped(0)
        , _strays(0)
        , _reset(0)
        , _remote_lost(-1)
        , _transit(0)
        , _jitter(0)
        , _frequency(frequency)
        , _received_sr(false)
    {}

    virtual size_t rcvbufsiz()
    {
        return UDPReceiver::rcvbufsiz();
    }

    virtual void rcvbufsiz(int bufsiz)
    {
        UDPReceiver::rcvbufsiz(bufsiz
                                + sizeof(RTP::Header)
                                + sizeof(uint32_t)); // for one csrc
    }

    ssize_t recv(void* buffer, size_t length,
                 struct timeval* timeout = NULL);

    uint32_t ssrc() const
    {
        return _ssrc;
    }

    /**
     * @return the last <b>known</b> RTP timestamp
     */
    uint32_t last_ts() const
    {
        return _curr_ts;
    }

    uint32_t last_seq() const
    {
        uint32_t cycles = XSeq::cycles(_max_seq);
        if (_curr_seq > (uint16_t)_max_seq)
        {
            // _max_seq is on the next cycles but not _curr_seq yet
            LOGGER_ASSERT(cycles > 1);
            cycles -= 1;
        }
        return cycles + _curr_seq;
    }

    /**
     * @return number of packets that should have been received
     *         up to the current one,
     *         ie. not including the packets in the queue
     */
    unsigned long packets_expected() const
    {
        return packets_received() - packets_strays() + packets_lost();
    }

    /**
     * @return number of packets that have actually been received
     *         up to the current one,
     *         ie. not including the packets in the queue
     */
    unsigned long packets_received() const
    {
        return _received - _queue.size();
    }

    unsigned long packets_lost() const
    {
        return _lost;
    }

    unsigned long remote_lost() const
    {
        return _remote_lost;
    }

    unsigned long packets_dropped() const
    {
        return _dropped;
    }

    unsigned long packets_strays() const
    {
        return _strays;
    }

    unsigned session_resets() const
    {
        return _reset;
    }

    double jitter() const
    {
        return _jitter;
    }

    unsigned queue_count() const
    {
        return (unsigned)_queue.size();
    }

    unsigned queue_count_marked() const
    {
        unsigned marked = 0;
        for (Queue::const_iterator it = _queue.begin(); it != _queue.end(); ++it)
        {
            if ((*it)->hdr.m)
                ++marked;
        }
        return marked;
    }

    double queue_stddev() const
    {
        uint16_t seq = _curr_seq;
        double sum = 0;
        double sumsq = 0;
        unsigned n = 0;
        for (Queue::const_iterator it = _queue.begin(); it != _queue.end(); ++it)
        {
            const uint16_t delta_seq = diff16((*it)->hdr.seq, seq);
            sum += delta_seq;
            sumsq += delta_seq * delta_seq;
            n += 1;
            seq = (*it)->hdr.seq;
        }
        if (n == 0)
            return 0;
        const double avg = sum / n;
        const double sq = sumsq / n - avg * avg;
        return sq <= 0 ? sq : sqrt(sq);
    }

    int queue_millis() const
    {
        if (_curr_ts == 0 || _frequency == 0)
            return -1;

        for (Queue::const_reverse_iterator it = _queue.rbegin(); it != _queue.rend(); ++it)
        {
            const uint32_t ts = (*it)->hdr.ts;
            if (ts != 0)
                return (ts - _curr_ts) * 1000.0 / _frequency;
        }
        return 0;
    }

protected:

    ssize_t pop(void* buffer, size_t length);

    void drop();

    void drop(uint16_t seq, unsigned n);

private:

    void reset(const RTP::Header* hdr)
    {
        _base_seq = hdr->seq;
        _curr_seq = (uint16_t)(hdr->seq - 1);
        _max_seq = hdr->seq;
        _probation = MIN_SEQUENTIAL;
        _received = 0;
        _lost = _dropped = _strays = 0;
        _reset += 1;
        _remote_lost = 0;
        _transit = 0;
        _jitter = 0;
        _curr_ts = 0;
        queue_clear();

        _received_sr = false;
        _precv.clear();
        _last_seq.clear();
        for (unsigned i = 0; i < hdr->cc; ++i)
        {
            const uint32_t csrc = hdr->csrc[i];
            _last_seq[csrc] = hdr->seq;
        }
    }

    ssize_t recv2(void* buffer, size_t length,
                  struct timeval* timeout);

    ssize_t recv2(RTP::Header* hdr, size_t length,
                  struct timeval* timeout,
                  struct sockaddr_in* src);

    void update_jitter(const RTP::Header* hdr);

    ssize_t recvSR(const struct sockaddr_in* peer, RTCP::SRPacket* sr, size_t n);

    ssize_t sendRR(const struct sockaddr_in* dest, RTCP::RRPacket* rr)
    {
        const ssize_t n = RTCPUDPSender::send(rr, MSG_DONTWAIT | MSG_NOSIGNAL, dest);
        if (n == -1 && errno == EWOULDBLOCK)
            return 0;
        return n;
    }

protected:

    struct RtpPacket
    {
        size_t len;
        size_t packetlen; // size of packet. if packetlen > len hdr is truncated
        RTP::Header hdr;
    };

    struct less16
    {
        bool operator() (uint16_t lhs, uint16_t rhs) const
        {
            return diff16(lhs, rhs) < 0;
        }

        bool operator() (const RTP::Header& lhs, const RTP::Header& rhs) const
        {
            return operator()(lhs.seq, rhs.seq);
        }

        bool operator() (const RtpPacket* lhs, const RtpPacket* rhs) const
        {
            return operator()(lhs->hdr, rhs->hdr);
        }
    };

    typedef std::set<RtpPacket*, less16> Queue;

#ifdef LOGGER_OSTREAM
    friend std::ostream& operator<<(std::ostream& out, const RtpPacket& pkt)
    {
        if (! out)
            return out;
        out << ' ' << pkt.hdr.seq;
        if (pkt.len < pkt.packetlen)
            out << '!';
        if (pkt.hdr.m)
            out << "(M)";
        return out;
    }

    friend std::ostream& operator<<(std::ostream& out, const Queue& q)
    {
        if (! out || q.empty())
            return out;

        unsigned marked = 0;
        uint32_t min_ts = UINT32_MAX;
        uint32_t max_ts = 0;
        for (Queue::const_iterator it = q.begin(); it != q.end(); ++it)
        {
            if ((*it)->hdr.m)
                ++marked;

            const uint32_t ts = (*it)->hdr.ts;
            if (ts > max_ts)
                max_ts = ts;
            if (ts < min_ts && ts > 0)
                min_ts = ts;
        }
        out << " (" << q.size();
        if (marked > 0)
            out << '/' << marked << 'M';
        if (max_ts > min_ts)
            out << '/' << (max_ts - min_ts);
        out << ')';

        for (Queue::const_iterator it = q.begin(); it != q.end(); )
        {
            out << *(*it);

            // move to the end of the sequence
            // ie. a marked fragment, or a break in seq

            const uint16_t curr = (*it)->hdr.seq;

            if (++it == q.end())
                break;
            if ((*it)->hdr.m)
                continue;

            uint16_t seq = (*it)->hdr.seq;
            if (diff16(seq, curr) != 1)
                continue;

            for (;;)
            {
                Queue::const_iterator next = it;
                if (++next == q.end())
                    break;
                if (diff16((*next)->hdr.seq, seq) != 1)
                    break;
                it = next;
                seq = (*it)->hdr.seq;
                if ((*it)->hdr.m)
                    break;
            }

            if (diff16((*it)->hdr.seq, curr) > 1)
                out << " ...";
        }
        return out;
    }
#endif

    Queue::iterator queue_last_in_sequence(Queue::iterator it) const;

    void queue_clear()
    {
        for (Queue::iterator it = _queue.begin(); it != _queue.end(); ++it)
            free(*it);
        _queue.clear();
#ifdef LOGGER_OSTREAM
        LOGGER_DEBUG("_queue:");
#endif
    }

    void queue_push(RTP::Header* hdr, size_t len, size_t packetlen);

    void queue_erase(const Queue::const_iterator& begin, const Queue::const_iterator& end);

    ssize_t queue_pop(void* buffer, size_t length, Queue::const_iterator& end);

private:

    struct XSeq // ExtendedSequence
    {
        static inline uint32_t cycles(uint32_t x)
        {
            return x & ~0xFFFF;
        }

        static inline uint16_t seq(uint32_t x)
        {
            return (uint16_t)x;
        }

        static inline void set(uint32_t& x, uint16_t y)
        {
            if (y < (uint16_t)x)
                x += (1<<16);
            x = (x & ~0xFFFF) | y;
        }

        static inline void set_cycles(uint32_t& x, uint32_t y)
        {
            const uint32_t ycycles = cycles(y);
            if (cycles(x) != ycycles)
                x = ycycles | seq(x);
        }

        static inline bool lt_cycles(uint32_t x, uint32_t y)
        {
            return cycles(x) < cycles(y);
        }
    };

    static uint32_t now65536()
    {
        struct timeval now;
        (void) gettimeofday(&now, NULL); // TODO: get now from socket
        // There are 15.2 1/65356 seconds in tv_usec << 2^4.
        return ((uint32_t)(now.tv_sec / 65536) << 4) | ((now.tv_usec / 65536) & 0xF);
    }

    static void erase_not_in(const RRPacket* rr,
                             std::map<uint32_t, uint32_t>& container)
    {
        for (std::map<uint32_t, uint32_t>::iterator it = container.begin();
             it != container.end();
             )
        {
            if (rr->find(it->first) == NULL)
            {
                std::map<uint32_t, uint32_t>::iterator j = it++;
                container.erase(j);
            }
            else
            {
                ++it;
            }
        }
    }

private:

    Queue _queue;

    uint32_t _ssrc;

    uint16_t _base_seq;         /* base seq number                   */
    uint16_t _curr_seq;         /* last delivered seq number         */
    uint32_t _max_seq;          /* highest seq. number seen          */

    uint16_t _probation;        /* seq. packets till source is valid */

    uint32_t _curr_ts;          /* last delivered ts                 */

    unsigned long _received;    /* # packets received                */
    unsigned long _lost;        /* # packets lost                    */
    unsigned long _dropped;     /* # packets dropped                 */
    unsigned long _strays;      /* # stray packets (ie. resent)      */
    unsigned _reset;            /* # resets                          */

    unsigned long _remote_lost;

    // jitter

    uint32_t _transit;          /* relative trans time for prev pkt  */
    double _jitter;             /* estimated jitter                  */
    const uint32_t _frequency;

    // flow control

    bool _received_sr;                      // SR packet received
    std::map<uint32_t, uint32_t> _precv;    // <ssrc, packets received (not incl. dups)>
    std::map<uint32_t, uint32_t> _last_seq; // <ssrc, max seq received>
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                               H264                                //
//                                                                   //
///////////////////////////////////////////////////////////////////////

struct H264
{
public:

    // machine-order representation of the H264 start code prefix (0x00000001)
    // TODO: rename to START_CODE_PREFIX
    static const uint32_t START_SEQUENCE;

    static const uint32_t CLOCK_FREQUENCY = 90000;

    typedef struct
    {
#ifdef __BIG_ENDIAN_BITFIELD
        unsigned f:1;       // forbidden zero bit = 0
        unsigned nri:2;     // nal ref idc
        unsigned type:5;
#else
        unsigned type:5;
        unsigned nri:2;
        unsigned f:1;
#endif
    } __attribute__ ((__packed__)) NAL;

    typedef enum
    {
       NAL_UNSPECIFIED  = 0,
       NAL_SLICE        = 1,    // Coded slice of a non-IDR picture
       NAL_SLICE_DPA    = 2,    // Coded slice data partition A
       NAL_SLICE_DPB    = 3,    // Coded slice data partition B
       NAL_SLICE_DPC    = 4,    // Coded slice data partition C
       NAL_SLICE_IDR    = 5,    // Coded slice of an IDR picture -- ref_idc != 0
       NAL_SEI          = 6,    // Supplemental enhancement information -- ref_idc == 0
       NAL_SPS          = 7,    // Sequence parameter set
       NAL_PPS          = 8,    // Picture parameter set
       NAL_AU_DELIMITER = 9,    // Access unit delimiter
       NAL_END_SEQ      = 10,   // End of sequence
       NAL_END_STREAM   = 11,   // End of stream
       NAL_FILTER       = 12,   // Filler data
       /* ref_idc == 0 for 6,9,10,11,12 */

       // RESERVED = 13..23

       NAL_STAP_A       = 24,   // Single-time aggregation packet
       NAL_STAP_B       = 25,   // Single-time aggregation packet
       NAL_MTAP16       = 26,   // Multi-time aggregation packet
       NAL_MTAP24       = 27,   // Multi-time aggregation packet
       NAL_FU_A         = 28,   // Fragmentation unit
       NAL_FU_B         = 29,   // Fragmentation unit
    } NAL_TYPE;

#ifdef LOGGER_OSTREAM
    friend std::ostream& operator<<(std::ostream& out, NAL_TYPE type)
    {
        out << "NAL_";
        switch (type)
        {
#  define DO(x)     case NAL_##x:   return out << #x;

        DO(UNSPECIFIED)
        DO(SLICE)
        DO(SLICE_DPA)
        DO(SLICE_DPB)
        DO(SLICE_DPC)
        DO(SLICE_IDR)
        DO(SEI)
        DO(SPS)
        DO(PPS)
        DO(AU_DELIMITER)
        DO(END_SEQ)
        DO(END_STREAM)
        DO(FILTER)

        DO(STAP_A)
        DO(STAP_B)
        DO(MTAP16)
        DO(MTAP24)
        DO(FU_A)
        DO(FU_B)

#  undef DO

        default:    return out << (unsigned)type;
        }
        UNREACHABLE();
        return out;
    }
#endif

    typedef struct
    {
        NAL indicator;

#ifdef __BIG_ENDIAN_BITFIELD
        unsigned s:1; // start bit
        unsigned e:1; // end bit
        unsigned r:1; // reserved = 0
        unsigned type:5;
#else
        unsigned type:5;
        unsigned r:1;
        unsigned e:1;
        unsigned s:1;
#endif
    } __attribute__ ((__packed__)) NAL_FU;
};

    ///////////////////////////////////////////////////////////////////
    //
    // H264RTPSender
    //
    ///////////////////////////////////////////////////////////////////

class H264RTPSender
    : public RTPBoundedSender
    , protected H264
{
public:

    H264RTPSender(const struct sockaddr_in* dest)
        : RTPBoundedSender(dest)
    {}

    size_t sndbufsiz() const
    {
        return RTPBoundedSender::sndbufsiz() - sizeof(NAL_FU);
    }

    void sndbufsiz(int bufsiz)
    {
        RTPBoundedSender::sndbufsiz(bufsiz);
    }

    ssize_t sendv(struct iovec* iov,
                  unsigned iovcnt,
                  int flags,
                  bool mark,
                  int pt,
                  uint32_t ts);

    static uint32_t rtp_compute_ts()
    {
        return RTPSender::rtp_compute_ts(H264::CLOCK_FREQUENCY);
    }

    static uint32_t rtp_compute_ts(int64_t pts)
    {
        return RTPSender::rtp_compute_ts(pts, H264::CLOCK_FREQUENCY);
    }
};

    ///////////////////////////////////////////////////////////////////
    //
    // H264RTPReceiver
    //
    ///////////////////////////////////////////////////////////////////

class H264RTPReceiver
    : public RTPReceiver
    , protected H264
{
public:

    H264RTPReceiver()
        : RTPReceiver(H264::CLOCK_FREQUENCY)
    {}

    ssize_t recv(void* buffer, size_t length,
                 struct timeval* timeout = NULL);
};

#endif
