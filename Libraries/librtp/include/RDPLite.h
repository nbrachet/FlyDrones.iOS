
#ifndef RDP_LITE_H_
#define RDP_LITE_H_

/* C99 requires that stdint.h only exposes UINT16_MAX if this is defined: */
#ifndef __STDC_LIMIT_MACROS
#  define __STDC_LIMIT_MACROS
#endif

#include <netinet/in.h>

#include <list>
#include <memory>
#include <set>

#ifdef IPPROTO_UDPLITE
#  include "UDPLite.h"
#else
#  include "UDP.h"
#endif

#ifndef LOGGER_OSTREAM
#  warning "LOGGER_OSTREAM not defined"
#endif

static const int _rdplite_srand = ( srand(time(NULL)), 0 );

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             RDPLITE                               //
//                                                                   //
///////////////////////////////////////////////////////////////////////

// @see http://tools.ietf.org/html/rfc908
// @see http://tools.ietf.org/html/rfc1151
//
// Differences with RFC:
//   - Header:
//     - bit5 is changed to 1 (from 0)
//     - Ver.No. is changed to 0
//     - source and destination ports are not present (not implemented)
//     - sequence numbers are 16 bits (instead of 32)
//     - max. segment size is not included (in SYN header)
//     - options flag filed is not included (in SYN header)
//   - NUL segments are never sent
//   - SND.MAX is renamed SND.MNS (_sdmns), and RCV.MAX is renamed RCV.MNS (_rcvmns)
//   - no timer is used to exit the CLOSE-WAIT state.
//     Instead a two-way handshake is implemented.
//   - no retransmittion timer
//   - no flow control or window management
//   - SBUF.MAX is sndbufsiz(), RBUF.MAX is rcvbfsiz()
//
// Extensions to the RFC:
//   - Delay sending ACK's for segments received in sequence
//     until RCV.MNS of them have been received
//
class RDPLite
#ifdef IPPROTO_UDPLITE
    : public UDPLite
#else
    : public UDP
#endif
{
public:

    RDPLite(uint16_t mns, const struct sockaddr_in* dest = NULL)
#ifdef IPPROTO_UDPLITE
        : Datagram(IPPROTO_UDPLITE)
        , UDPLite(dest)
#else
        : UDP(dest)
#endif
        , _state(STATE_CLOSED)
        , _sndmns(mns)
    {
#ifdef IPPROTO_UDPLITE
        UDPLite::cscov(sizeof(struct udphdr));
#endif
        cscov(sizeof(Header));

        LOGGER_DEBUG("SND.MNS = %hu", _sndmns);
    }

    size_t sndbufsiz() const
    {
#ifdef IPPROTO_UDPLITE
        return UDPLiteSender::sndbufsiz() - sizeof(Header);
#else
        return UDPSender::sndbufsiz() - sizeof(Header);
#endif
    }

    void sndbufsiz(int bufsiz)
    {
#ifdef IPPROTO_UDPLITE
        UDPLiteSender::sndbufsiz(bufsiz);
#else
        UDPSender::sndbufsiz(bufsiz);
#endif
    }

    size_t rcvbufsiz()
    {
#ifdef IPPROTO_UDPLITE
        size_t bufsiz = UDPLiteReceiver::rcvbufsiz();
#else
        size_t bufsiz = UDPReceiver::rcvbufsiz();
#endif
        if (bufsiz <= sizeof(Header))
            return 0;
        return bufsiz - sizeof(Header);
    }

    void rcvbufsiz(int bufsiz)
    {
#ifdef IPPROTO_UDPLITE
        UDPLiteReceiver::rcvbufsiz(bufsiz + sizeof(Header));
#else
        UDPReceiver::rcvbufsiz(bufsiz + sizeof(Header));
#endif
    }

    void cscov(int32_t cscov)
    {
        _cscov = cscov;
        LOGGER_DEBUG("CSCOV = %d", cscov);
    }

    int disconnect(struct timeval* timeout = NULL)
    {
        LOGGER_DEBUG("User disconnect");

        switch (_state)
        {
        case STATE_OPEN:
        {
            if (flush(timeout) == -1)
            {
                if (errno != EWOULDBLOCK)
                    return -1;
            }

            LOGGER_DEBUG("close in OPEN: RST");

            set_state(STATE_CLOSE_WAIT);

            Header rst;
            rst.rst = true;
            rst.seq = _sndnxt;
            if (send(&rst, timeout) == -1)
                return -1;

            while (_state != STATE_CLOSED)
            {
                if (run(timeout) == -1)
                {
                    if (errno != EWOULDBLOCK)
                        return -1;

                    set_state(STATE_CLOSED);
                    break;
                }
            }

            return 0;
        }

        case STATE_LISTEN:
        {
            LOGGER_DEBUG("close in LISTEN: close connection");
            set_state(STATE_CLOSED);
            return 0;
        }

        case STATE_SYN_RCVD:
        case STATE_SYN_SENT:
        {
            LOGGER_DEBUG("close in %s: RST", _state == STATE_SYN_RCVD ? "SYN-RCVD" : "SYN-SENT");

            set_state(STATE_CLOSED);

            Header rst;
            rst.rst = true;
            rst.seq = _sndnxt;
            if (send(&rst, timeout) == -1)
                return -1;

            return 0;
        }

        case STATE_CLOSE_WAIT:
        {
            LOGGER_DEBUG("close in CLOSE-WAIT");
            return 0;   // deviate from RFC: not treated as an error
        }

        case STATE_CLOSED:
        {
            LOGGER_DEBUG("close in CLOSE");
            errno = ENOTCONN;
            return -1;
        }
        }
        UNREACHABLE();
    }

    int connect(struct timeval* timeout = NULL)
    {
        LOGGER_DEBUG("User connect");

        if (_state == STATE_CLOSE_WAIT)
        {
            LOGGER_DEBUG("connect in STATE_CLOSE_WAIT: reset connection");
            set_state(STATE_CLOSED);
        }
        else if (_state != STATE_CLOSED)
        {
            LOGGER_ERROR("Connection is not closed");
            errno = EISCONN;
            return -1;
        }

        init();

        std::auto_ptr<SYNHeader> syn(new (0) SYNHeader);
        if (syn.get() == NULL)
            return -1;
        syn->syn = true;
        syn->seq = _sndiss;
        syn->mns = _sndmns;
        if (send(syn.get(), timeout) == -1)
            return -1;
        _sndnxt = _sndiss + 1;

        set_state(STATE_SYN_SENT);

        Header* hdr = syn.get();
        LOGGER_ASSERT1(_outq.empty(), _outq.size());
        if (schedule(hdr) == 0)
            syn.release();

        while (_state != STATE_OPEN)
        {
            if (run(timeout) == -1)
            {
                (void) unschedule(hdr);
                return -1;
            }

            switch (_state)
            {
            case STATE_CLOSED:
                LOGGER_ERROR("connect refused");
                (void) unschedule(hdr);
                errno = ECONNREFUSED;
                return -1;

            case STATE_CLOSE_WAIT:
                LOGGER_ERROR("connect reset");
                (void) unschedule(hdr);
                errno = ECONNRESET;
                return -1;

            default:
                break;
            }
        }
        (void) unschedule(hdr);

        return _state == STATE_OPEN ? 1 : 0;
    }

    int accept(struct timeval* timeout = NULL)
    {
        if (_state == STATE_CLOSE_WAIT)
        {
            LOGGER_DEBUG("accept in STATE_CLOSE_WAIT: reset connection");
            set_state(STATE_CLOSED);
        }
        else if (_state != STATE_CLOSED)
        {
            LOGGER_ERROR("Connection is not closed");
            errno = EINVAL;
            return -1;
        }

        set_state(STATE_LISTEN);

        for (;;)
        {
            if (run(timeout) == -1)
                return -1;

            switch (_state)
            {
            case STATE_OPEN:
                return 0;

            case STATE_CLOSED:
                // return to LISTEN
                set_state(STATE_LISTEN);
                break;

            default:
                break;
            }
        }
        UNREACHABLE();
    }

    ssize_t recv(void* buffer, size_t buflen,
                 struct timeval* timeout = NULL)
    {
        LOGGER_DEBUG("User read request: len=%zu", buflen);

        if (_state == STATE_CLOSED)
        {
            LOGGER_ERROR("Connection not open");
            errno = ENOTCONN;
            return -1;
        }

        for (;;)
        {
            if (run(timeout) == -1)
                return -1;

            switch (_state)
            {
            case STATE_CLOSED:
                LOGGER_ERROR("Connection not open");
                errno = ENOTCONN;
                return -1;

            case STATE_CLOSE_WAIT:
                LOGGER_ERROR("Connection reset");
                errno = ECONNRESET;
                return -1;

            default:
                break;
            }

            if (_state == STATE_OPEN && input_pending())
                break;
        }

        InQ::iterator first = _inq.begin();
        LOGGER_ASSERT(first != _inq.end());

        if ((*first)->datalen > buflen)
        {
            LOGGER_ERROR("Not enough room for msg: %zu < %u", buflen, (*first)->datalen);
            errno = EMSGSIZE;
            return -1;
        }

        std::auto_ptr<Header> hdr(*first);
        memcpy(buffer, hdr->data(), hdr->datalen);

        _inq.erase(first);
#ifdef LOGGER_OSTREAM
        if (LOGGER_IS_DEBUG())
        {
            LOGGER_ODEBUG(cdbg) << "INQ (" << _inq.size() << ") =" << _inq;
        }
#endif

        LOGGER_DEBUG("User read request: read len=%hu", hdr->datalen);

        return hdr->datalen;
    }

    ssize_t send(const void* buffer, size_t buflen,
                 struct timeval* timeout = NULL)
    {
        struct iovec iovec;
        iovec.iov_base = const_cast<void*>(buffer);
        iovec.iov_len = buflen;
        return sendv(&iovec, 1, timeout);
    }

    ssize_t sendv(struct iovec* iov, unsigned iovcnt,
                  struct timeval* timeout = NULL)
    {
        LOGGER_DEBUG("User write request");

        // quick run to flush input
        struct timeval notimeout = { 0, 0 };
        if (run(&notimeout) == -1 && errno != EWOULDBLOCK)
            return -1;

        if (_state != STATE_OPEN)
        {
            LOGGER_ERROR("Not connected");
            errno = ENOTCONN;
            return -1;
        }

        size_t len = 0;
        for (unsigned i = 0; i < iovcnt; ++i)
            len += iov[i].iov_len;
        LOGGER_DEBUG("len=%zu", len);

        if (len == 0)
        {
            if (run(timeout) == -1)
                return -1;
            return 0;
        }
        if (len > sndbufsiz())
        {
            LOGGER_ERROR("Buffer too large");
            errno = EMSGSIZE;
            return -1;
        }
        if (! less16()(_sndnxt, (uint16_t)(_snduna + _sndmns)))
        {
            LOGGER_WARN("No more buffer space: SND.NXT=%hu SND.UNA=%hu SND.MNS=%hu", _sndnxt, _snduna, _sndmns);

            // see if we can flush output
            while (_state == STATE_OPEN
                   && ! less16()(_sndnxt, (uint16_t)(_snduna + _sndmns)))
            {
                if (run(timeout) == -1)
                {
                    if (errno == EWOULDBLOCK)
                    {
                        LOGGER_ERROR("Out of buffer space: SND.NXT=%hu SND.UNA=%hu SND.MNS=%hu", _sndnxt, _snduna, _sndmns);
                        errno = ENOBUFS;
                    }
                    return -1;
                }
            }
            if (_state != STATE_OPEN)
            {
                LOGGER_ERROR("Not connected");
                errno = ENOTCONN;
                return -1;
            }
        }
        LOGGER_ASSERT3(less16()(_sndnxt, (uint16_t)(_snduna + _sndmns)), _sndnxt, _snduna, _sndmns);

        Header* hdr;
        unsigned neak = _inq.size();
        if (neak == 0)
        {
            // still try to allocate an EAKHeader for retries

            neak = (sndbufsiz() - len) / sizeof(uint16_t);
            if (neak > _rcvmns)
                neak = _rcvmns;
        }
        else if (neak * sizeof(uint16_t) + len > sndbufsiz())
            neak = (sndbufsiz() - len) / sizeof(uint16_t);
        LOGGER_ASSERT2(neak <= _rcvmns, neak, _rcvmns);
        if (neak == 0)
        {
            hdr = new (len) Header;
        }
        else
        {
            hdr = new (neak, (uint16_t)len) EAKHeader(neak);
            hdr->eak = true;
        }
        if (hdr == NULL)
            return -1;

        hdr->seq = _sndnxt;
        hdr->datalen = len;
        char* p = reinterpret_cast<char*>(hdr->data());
        for (unsigned i = 0; i < iovcnt; ++i)
        {
            memcpy(p, iov[i].iov_base, iov[i].iov_len);
            p += iov[i].iov_len;
        }

        if (send(hdr, timeout) == -1)
            return -1;

        ++_sndnxt;

        if (schedule(hdr) == -1)
        {
            // FIXME: not quite right... but should never happen anyway
            delete hdr;
            return -1;
        }

        while (output_pending())
        {
            if (run(timeout) == -1)
            {
                if (errno != EWOULDBLOCK)
                    return -1;
                errno = 0;
                break;
            }
        }

        LOGGER_DEBUG("User write request: wrote len=%zu", len);

        return len;
    }

    int flush(struct timeval* timeout = NULL)
    {
        LOGGER_DEBUG("User flush request");

        if (_state != STATE_OPEN)
        {
            LOGGER_ERROR("Not connected");
            errno = ENOTCONN;
            return -1;
        }

        while (output_pending())
        {
            if (run(timeout) == -1)
                return -1;
        }

        return 0;
    }

    virtual ssize_t /*Socket::*/ read(void* buffer, size_t len,
                                      struct timeval* timeout = NULL)
    {
        return recv(buffer, len, timeout);
    }

    virtual ssize_t /*Socket::*/ readv(struct iovec* iov, unsigned iovcnt,
                                       struct timeval* timeout = NULL)
    {
        errno = ENOSYS;
        return -1;
    }

    virtual ssize_t /*Socket::*/ write(const void* buffer, size_t len,
                                       struct timeval* timeout = NULL)
    {
        return send(buffer, len, timeout);
    }

    virtual ssize_t /*Socket::*/ writev(struct iovec* iov, unsigned iovcnt,
                                        struct timeval* timeout = NULL)
    {
        return sendv(iov, iovcnt, timeout);
    }

protected:

    enum State
    {
        STATE_CLOSED,
        STATE_LISTEN,
        STATE_SYN_SENT,
        STATE_SYN_RCVD,
        STATE_OPEN,
        STATE_CLOSE_WAIT
    };

    enum
    {
        VERSION = 0
    };

    struct Header
    {
#ifdef __BIG_ENDIAN_BITFIELD
        bool syn:1;
        bool ack:1;
        bool eak:1;
        bool rst:1;
        bool nul:1;
        unsigned one:1;
        unsigned version:2;
#else
        unsigned version:2;
        unsigned one:1;
        bool nul:1;
        bool rst:1;
        bool eak:1;
        bool ack:1;
        bool syn:1;
#endif
        uint8_t hdrlen;
//        uint16_t sport;
//        uint16_t dport;
        uint16_t datalen;
        uint16_t seq;
        uint16_t ackseq;
        uint16_t checksum;

        Header()
        {
            memset(this, 0, sizeof(*this));
            version = VERSION;
            one = 1;
            hdrlen = sizeof(*this);
        }

        void* data()
        {
            return reinterpret_cast<uint8_t*>(this) + hdrlen;
        }

        void hton()
        {
            datalen = htons(datalen);
            seq = htons(seq);
            ackseq = htons(ackseq);
            checksum = htons(checksum);
        }

        void ntoh()
        {
            datalen = ntohs(datalen);
            seq = ntohs(seq);
            ackseq = ntohs(ackseq);
            checksum = ntohs(checksum);
        }

        void* operator new(std::size_t hdrlen) throw()
        {
           return malloc(hdrlen);
        }

        // call with: new(datalen) Header
        void* operator new(size_t hdrlen, uint16_t datalen) throw()
        {
            LOGGER_ASSERT2(hdrlen + datalen <= 0xFFFF, hdrlen, datalen);
            return malloc(hdrlen + datalen);
        }

        void operator delete(void* ptr, size_t) throw()
        {
            if (ptr != NULL)
                free(ptr);
        }
    }  __attribute__ ((__packed__));

    struct SYNHeader
        : public Header
    {
        uint16_t mns;   // The maximum number of segments that should be sent without getting an acknowledgement
//        uint16_t mss;   // The maximum size segment in octets that the sender should send

        SYNHeader()
        {
            syn = true;
            hdrlen = sizeof(*this);
            mns = 0;
        }

        void hton()
        {
            Header::hton();
            mns = htons(mns);
        }

        void ntoh()
        {
            Header::ntoh();
            mns = ntohs(mns);
        }
    } __attribute__ ((__packed__));

    struct EAKHeader
        : public Header
    {
        uint16_t eakseq[0];

        EAKHeader(unsigned neak)
            : Header()
        {
            LOGGER_ASSERT1(neak > 0, neak);

            eak = true;
            hdrlen = sizeof(EAKHeader) + neak * sizeof(uint16_t);
        }

        void hton()
        {
            Header::hton();

            const unsigned neak = this->neak();
            for (unsigned i = 0; i < neak; ++i)
            {
                eakseq[i] = htons(eakseq[i]);
            }
        }

        void ntoh()
        {
            Header::ntoh();

            const unsigned neak = this->neak();
            for (unsigned i = 0; i < neak; ++i)
            {
                eakseq[i] = ntohs(eakseq[i]);
            }
        }

        unsigned neak() const
        {
            return (hdrlen - sizeof(EAKHeader)) / sizeof(uint16_t);
        }

        void* operator new(std::size_t hdrlen) throw()
        {
           return malloc(hdrlen);
        }

        // call with: new(n, datalen) Header
        void* operator new(size_t hdrlen, unsigned neak, uint16_t datalen) throw()
        {
            LOGGER_ASSERT1(neak > 0, neak);
            LOGGER_ASSERT3(hdrlen + neak * sizeof(uint16_t) + datalen <= 0xFFFF, hdrlen, neak, datalen);
            return malloc(hdrlen + neak * sizeof(uint16_t) + datalen);
        }
    }  __attribute__ ((__packed__));

    static void hton(Header* hdr)
    {
        if (hdr->syn)
        {
            SYNHeader* syn = reinterpret_cast<SYNHeader*>(hdr);
            syn->hton();
        }
        else if (hdr->eak)
        {
            EAKHeader* eak = reinterpret_cast<EAKHeader*>(hdr);
            eak->hton();
        }
        else
        {
            hdr->hton();
        }
    }

    static void ntoh(Header* hdr)
    {
        if (hdr->syn)
        {
            SYNHeader* syn = reinterpret_cast<SYNHeader*>(hdr);
            syn->ntoh();
        }
        else if (hdr->eak)
        {
            EAKHeader* eak = reinterpret_cast<EAKHeader*>(hdr);
            eak->ntoh();
        }
        else
        {
            hdr->ntoh();
        }
    }

#ifdef LOGGER_OSTREAM
    friend std::ostream& operator<<(std::ostream& out, const Header* hdr)
    {
        if (! out)
            return out;

        out << "SEQ=" << hdr->seq;
        if (hdr->syn) out << ",SYN";
        if (hdr->ack) out << ",ACK=" << hdr->ackseq;
        if (hdr->eak)
        {
            out << ",EAK=";
            const EAKHeader* eak = reinterpret_cast<const EAKHeader*>(hdr);
            const unsigned neak = eak->neak();
            unsigned i;
            for (i = 0; i < neak - 1 && eak->eakseq[i] != hdr->ackseq; ++i)
                out << eak->eakseq[i] << "+";
            out << eak->eakseq[i];
        }
        if (hdr->rst) out << ",RST";
        if (hdr->nul) out << ",NUL";
        if (hdr->datalen > 0) out << ",datalen=" << hdr->datalen;

        return out;
    }
#endif

    static inline int16_t diff16(uint16_t a, uint16_t b)
    {
        return (a - b) & ((1 << 16) - 1);
    }

    struct less16
    {
        bool operator() (uint16_t lhs, uint16_t rhs) const
        {
            return diff16(lhs, rhs) < 0;
        }

        bool operator() (const Header* lhs, const Header* rhs) const
        {
            return operator()(lhs->seq, rhs->seq);
        }
    };

    struct less_or_equal16
    {
        bool operator() (uint16_t lhs, uint16_t rhs) const
        {
            return diff16(lhs, rhs) <= 0;
        }

        bool operator() (const Header* lhs, const Header* rhs) const
        {
            return operator()(lhs->seq, rhs->seq);
        }
    };

    typedef std::set<Header*, less16> InQ;

    // yes: I know about std::tuple... but I don't like 'em
    template <typename T, typename U, typename V>
    struct triplet
    {
        T first;
        U second;
        V third;

        triplet()
            : first(), second(), third()
        {}

        triplet(const T& t, const U& u, const V& v)
            : first(t), second(u), third(v)
        {}

        triplet(const triplet& rhs)
            : first(rhs.first), second(rhs.second), third(rhs.third)
        {}

        triplet& operator=(const triplet& rhs)
        {
            first = rhs.first;
            second = rhs.second;
            third = rhs.third;
            return *this;
        }
    };

    typedef triplet<struct timeval, Header*, struct sockaddr_in*> Triplet;

    static Triplet make_triplet(struct timeval& tv, Header* hdr, struct sockaddr_in* dest)
    {
        return Triplet(tv, hdr, dest);
    }

    typedef std::list<Triplet> OutQ;

#ifdef LOGGER_OSTREAM
    friend std::ostream& operator<<(std::ostream& out, const InQ& q)
    {
        if (! out)
            return out;
        for (InQ::const_iterator it = q.begin(); it != q.end(); ++it)
            out << " " << (*it)->seq;
        return out;
    }

    friend std::ostream& operator<<(std::ostream& out, const OutQ& q)
    {
        if (! out)
            return out;
        for (OutQ::const_iterator it = q.begin(); it != q.end(); ++it)
            out << " " << it->second->seq;
        return out;
    }
#endif

protected:

    int schedule(Header* hdr, struct sockaddr_in* dest = NULL)
    {
        if (schedule_quiet(hdr, dest) == -1)
            return -1;

#ifdef LOGGER_OSTREAM
        if (LOGGER_IS_DEBUG())
        {
            LOGGER_ODEBUG(cdbg);
//            cdbg << "Schedule " << hdr << std::flush;
            cdbg << "OUTQ (" << _outq.size() << ") =" << _outq;
        }
#endif
        if (_outq.size() > _sndmns)
            LOGGER_WARN("OUTQ > SND.MNS=%hu", _sndmns);

        return 0;
    }

    int schedule_quiet(Header* hdr, struct sockaddr_in* dest)
    {
        struct timeval tv;
        if (timestamp(&tv) == -1)
            return -1;

        struct timeval defaulttmo = { 0, 200000 }; // FIXME: use RTT
        tv += defaulttmo;

        _outq.push_back(make_triplet(tv, hdr, dest));

        return 0;
    }

    int reschedule(Header* hdr, struct sockaddr_in* dest = NULL)
    {
        LOGGER_ASSERT(! _outq.empty());
        LOGGER_ASSERT(hdr == _outq.begin()->second);

        if (schedule_quiet(hdr, dest) == -1)
            return -1;

        (void) _outq.pop_front();

#ifdef LOGGER_OSTREAM
        if (LOGGER_IS_DEBUG())
        {
            LOGGER_ODEBUG(cdbg);
//            cdbg << "Reschedule " << hdr->seq << std::flush;
            cdbg << "OUTQ (" << _outq.size() << ") =" << _outq;
        }
#endif

        return 0;
    }

    int schedule_now(Header* hdr, struct sockaddr_in* dest = NULL)
    {
        struct timeval epoch = { 0, 0 };
        _outq.push_front(make_triplet(epoch, hdr, dest));
#ifdef LOGGER_OSTREAM
        if (LOGGER_IS_DEBUG())
        {
            LOGGER_ODEBUG(cdbg);
//            cdbg << "Schedule now " << hdr << std::flush;
            cdbg << "OUTQ (" << _outq.size() << ") =" << _outq;
        }
#endif
        if (_outq.size() > _sndmns)
            LOGGER_WARN("OUTQ > SND.MNS (%hu)", _sndmns);

        return 0;
    }

    int unschedule(Header* hdr)
    {
       for (OutQ::iterator it = _outq.begin(); it != _outq.end(); ++it)
       {
            if (it->second == hdr)
            {
//                LOGGER_DEBUG("Unscheduling %hu", hdr->seq);

                delete hdr;
                (void) _outq.erase(it);

#ifdef LOGGER_OSTREAM
                if (LOGGER_IS_DEBUG())
                {
                    LOGGER_ODEBUG(cdbg) << "OUTQ (" << _outq.size() << ") =" << _outq;
                }
#endif

                return 0;
            }
       }
       return -1;
    }

    ssize_t send(Header* hdr,
                 struct timeval* timeout,
                 struct sockaddr_in* dest = NULL)
    {
        if (! (less_or_equal16()(_sndnxt - _sndmns, hdr->seq) && less_or_equal16()(hdr->seq, _sndnxt)))
        {
            LOGGER_WARN("SND.NXT=%hu SND.MNS=%hu seq=%hu", _sndnxt, _sndmns, hdr->seq);
        }

        LOGGER_ASSERT2(hdr->datalen == 0 || ! hdr->ack, hdr->datalen, hdr->ack);
        const bool resetack = hdr->datalen > 0 && ! hdr->ack;
        bool seteak = false;
        if (resetack)
        {
            LOGGER_ASSERT(! hdr->ack);
            if (hdr->eak)
            {
                if (_inq.empty())
                {
                    // sending an EAK if the peer is in SYN-RCVD will cause it to reset
                    seteak = true;
                    hdr->eak = false;
                }
                else
                {
                    EAKHeader* eak = reinterpret_cast<EAKHeader*>(hdr);

                    const unsigned neak = eak->neak();
                    unsigned i = 0;
                    for (InQ::const_iterator it = _inq.begin(); it != _inq.end() && i < neak; ++it)
                    {
                        const uint16_t seq = (*it)->seq;
                        if (less16()(_rcvcur, seq))
                            eak->eakseq[i++] = seq;
                    }
                    for (; i < neak; ++i)
                        eak->eakseq[i] = _rcvcur;
                }
            }

            hdr->ack = true;
            hdr->ackseq = _rcvcur;
        }

        hdr->checksum = checksum(hdr);

#ifdef LOGGER_OSTREAM
        if (LOGGER_IS_DEBUG())
        {
            LOGGER_ODEBUG(cdbg) << "send(" << hdr << ") state=" << _state;
        }
#endif

        const size_t len = hdr->hdrlen + hdr->datalen;

        hton(hdr);

#ifdef IPPROTO_UDPLITE
        ssize_t n = UDPLiteSender::send(hdr, len, MSG_NOSIGNAL, timeout, dest);
#else
        ssize_t n = UDPSender::send(hdr, len, MSG_NOSIGNAL, timeout, dest);
#endif

        ntoh(hdr);

        if (resetack)
            hdr->ack = false;
        if (seteak)
            hdr->eak = true;

#if 1 // ndef STRICT_RFC
        if (n != -1)
            _rcvuna = _rcvcur + 1;
#endif

        return n;
    }

    ssize_t recv(std::auto_ptr<Header>& ptr,
                 struct timeval* timeout,
                 struct sockaddr_in* peer = NULL)
    {
        Header hdr1;
        const ssize_t len = peek(&hdr1, sizeof(hdr1), MSG_NOSIGNAL | MSG_TRUNC, timeout);
        switch (len)
        {
        case -1:    return -1;
        case 0:     LOGGER_ERROR("Connection reset");
                    errno = ECONNRESET;
                    return -1;
        }

        const size_t bufsiz = len <= (ssize_t)(rcvbufsiz() + sizeof(Header)) ? len : rcvbufsiz() + sizeof(Header);
        ptr.reset(reinterpret_cast<Header*>(realloc(ptr.get(), bufsiz)));
        if (ptr.get() == NULL)
        {
            LOGGER_ERROR("Couldn't reallocate %.0biB", (float) bufsiz);
            errno = ENOMEM;
            return -1;
        }

#ifdef IPPROTO_UDPLITE
        ssize_t n = UDPLite::recv(ptr.get(), bufsiz, MSG_NOSIGNAL, timeout, peer);
#else
        ssize_t n = UDP::recv(ptr.get(), bufsiz, MSG_NOSIGNAL, timeout, peer);
#endif
        if (n == -1)
            return -1;

        Header hdr2;
        struct sockaddr_in peer2;
        ssize_t n2;
        while ((n2 = peek(&hdr2, sizeof(hdr2), MSG_NOSIGNAL | MSG_TRUNC | MSG_DONTWAIT, NULL, &peer2)) == len
            && memcmp(&hdr1, &hdr2, sizeof(hdr2)) == 0
            && memcmp(peer, &peer2, sizeof(peer2)) == 0)
        {
            LOGGER_DEBUG("Dropping duplicate seg %hu", ntohs(hdr1.seq));

#ifdef IPPROTO_UDPLITE
            n = UDPLite::recv(ptr.get(), bufsiz, MSG_NOSIGNAL, timeout, peer);
#else
            n = UDP::recv(ptr.get(), bufsiz, MSG_NOSIGNAL, timeout, peer);
#endif
            if (n == -1)
                return -1;
        }

        if (n == 0)
        {
            LOGGER_ERROR("Connection reset");
            errno = ECONNRESET;
            return -1;
        }
        if (n < (ssize_t)sizeof(Header))
        {
            LOGGER_WARN("Received seg smaller than Header (%zdB)", n);
            return 0;
        }

        Header* hdr = ptr.get();
        ntoh(hdr);

        uint16_t hdrsum = hdr->checksum;
        if (hdrsum != 0)
        {
            uint16_t csum = checksum(hdr);
            if (hdrsum != csum)
            {
                LOGGER_WARN("Received seg failed checksum validation: %hx != %hx", hdrsum, csum);
                return 0;
            }
        }

        if (n < len)
        {
            LOGGER_WARN("Received seg %hu truncated: %zi < %zi", hdr->seq, n, len);
            return 0;
        }
        LOGGER_ASSERT2(n == len, n, len);
        LOGGER_ASSERT2(n == (ssize_t)bufsiz, n, bufsiz);

        if (hdr->syn && n < (ssize_t)sizeof(SYNHeader))
        {
            LOGGER_WARN("Received seg %hu smaller than SYNHeader (%ziB)", hdr->seq, n);
            return 0;
        }
        if (n < hdr->hdrlen + hdr->datalen)
        {
            LOGGER_WARN("Received seg %hu with inconsistent len: %zi < %u", hdr->seq, n, hdr->hdrlen + hdr->datalen);
            return 0;
        }

        if (hdr->version != VERSION)
        {
            LOGGER_WARN("Received seg %hu with invalid version: %x", hdr->seq, hdr->version);
            return 0;
        }
        if (hdr->one != 1)
        {
            LOGGER_WARN("Received seg %hu with invalid one", hdr->seq);
            return 0;
        }

#if 0
        // simulate packet loss
        if (rand() % 100 < 50) // 50% loss
        {
#ifdef LOGGER_OSTREAM
            LOGGER_ODEBUG(cdbg) << "--- simulate packet loss: dropping " << hdr;
#endif
            return 0;
        }
#endif

#if 0
        {
            static Queue reorder;

            reorder.insert(hdr);

            if (rand() % 4 != 0)
            {
#ifdef LOGGER_OSTREAM
                LOGGER_ODEBUG(cdbg) << "--- simulate packet re-ordering: holding " << hdr << std::flush;
#endif

                return 0;
            }

            int r = rand() % reorder.size();
            Queue::iterator it = reorder.begin();
            while (--r >= 0)
                ++it;

            hdr = *it;
            n = hdr->hdrlen + hdr->datalen;

            reorder.erase(it);
        }
#endif

#ifdef LOGGER_OSTREAM
        if (LOGGER_IS_DEBUG())
        {
            LOGGER_ODEBUG(cdbg) << "recv(" << hdr << ") state=" << _state;
        }
#endif

        return n;
    }

    /**
     * @return -1 on error
     *         0 if no input/output is ready
     *         >0 if input (in that case read will be true),
     *            or output (in that case write will be true)
     *            is ready
     */
    int select(bool& read, bool& write, struct timeval* timeout)
    {
        // TODO: there's got to be a better way to implement this!

        if (_outq.empty())
        {
            // no output pending

            if (input_pending())
            {
                // but input pending

                read = true;
                write = false;
                return 1;
            }

            // no input pending... wait for socket (read)

            switch (wait_for_input(timeout))
            {
            case -1:    return -1;
            case 0:     return 0;
            case 1:     read = true;
                        write = false;
                        return 1;
            }
            UNREACHABLE();
        }

        struct timeval now;
        if (timestamp(&now) == -1)
            return -1;

        if (_outq.front().first <= now)
        {
            // output pending

            if (input_pending())
            {
                // and input pending... check socket for write

                switch (wait_for_output())
                {
                case -1:    return -1;
                case 0:     // socket is not ready for write
                            read = true;
                            write = false;
                            return 1;
                case 1:     // socket is ready for write
                            read = true;
                            write = true;
                            return 1;
                }
                UNREACHABLE();
            }

            // no input pending... wait until socket is ready for read/write

            FDSet readfds;
            readfds.set(*this);
            FDSet writefds;
            writefds.set(*this);
            switch (INet::select(&readfds, &writefds, timeout))
            {
            case -1:    return -1;
            case 0:     // socket not ready for read/write
                        return 0;
            case 1:     read = readfds.isset(*this);
                        write = writefds.isset(*this);
                        return 1;
            case 2:     read = true;
                        write = true;
                        return 2;
            }
            UNREACHABLE();
        }

        // output not yet ready

        if (input_pending())
        {
            // but input pending

            read = true;
            write = false;
            return 1;
        }

        // output will be ready in (_outq.begin()->first - now) = outtmo
        // select until for then

        struct timeval outtmo = _outq.begin()->first;
        outtmo -= now;

        if (! timeout)
        {
            // wait from input until next output is ready, ie. outtmo

            switch (wait_for_input(&outtmo))
            {
            case -1:    return -1;
            case 0:     break;
            case 1:     read = true;
                        write = false;
                        return 1;
            default:    UNREACHABLE();
            }

            // now wait forever for input/output

            FDSet readfds;
            readfds.set(*this);
            FDSet writefds;
            writefds.set(*this);
            switch (INet::select(&readfds, &writefds))
            {
            case -1:    return -1;
            case 0:     // socket not ready for reading/writing... shouldn't happen
                        return 0;
            case 1:     read = readfds.isset(*this);
                        write = writefds.isset(*this);
                        return 1;
            case 2:     read = true;
                        write = true;
                        return 2;
            }
            UNREACHABLE();
        }

        if (*timeout < outtmo)
        {
            // wait for input for *timeout

            switch (wait_for_input(timeout))
            {
            case -1:    return -1;
            case 0:     return 0;
            case 1:     read = true;
                        write = false;
                        return 1;
            }
            UNREACHABLE();
        }
        else
        {
            // wait from input until next output is ready, ie. outtmo

            struct timeval tmo = outtmo;
            switch (wait_for_input(&tmo))
            {
            case -1:    return -1;
            case 0:     // we've slept for outtmo... adjust timeout
                        *timeout -= outtmo;
                        break;
            case 1:     // we've slept for (outtmo - tmo)... adjust timeout
                        *timeout -= outtmo;
                        *timeout += tmo;
                        read = true;
                        write = false;
                        return 1;
            default:    UNREACHABLE();
            }

            // output pending... wait for socket for read/write

            FDSet readfds;
            readfds.set(*this);
            FDSet writefds;
            writefds.set(*this);
            switch (INet::select(&readfds, &writefds, timeout))
            {
            case -1:    return -1;
            case 0:     // socket not ready for reading/writing...
                        read = false;
                        write = false;
                        return 0;
            case 1:     read = readfds.isset(*this);
                        write = writefds.isset(*this);
                        return 1;
            case 2:     read = true;
                        write = true;
                        return 2;
            }
            UNREACHABLE();
        }
        UNREACHABLE();
    }

    int run(struct timeval* timeout)
    {
        for (;;)
        {
            bool read, write;
            switch (select(read, write, timeout))
            {
            case -1:    return -1;
            case 0:     errno = EWOULDBLOCK;
                        return -1;
            }

            int n = 0;
            if (read)
            {
                n = run_input(timeout);
                if (n == -1)
                    return -1;
            }

            if (write
                && ! _outq.empty()) // _outq could have been cleared in run_input() above
            {
                if (run_output(timeout) == -1)
                    return -1;
            }

//            if (n > 0)
//                return n;

            return 0;
        }
        UNREACHABLE();
    }

    int run_input(struct timeval* timeout)
    {
        struct sockaddr_in peer;
        std::auto_ptr<Header> hdr;

        ssize_t n;
        if (input_pending())
        {
            n = recv(hdr, timeout, &peer);
            if (n == -1 && errno == EWOULDBLOCK)
                return 0; // input pending
        }
        else
        {
            n = recv(hdr, timeout, &peer);
        }
        if (n <= 0)
            return n;

        switch (_state)
        {
        case STATE_CLOSED:
        {
            if (hdr->rst)
            {
                LOGGER_DEBUG("RST in CLOSED: discard %hu", hdr->seq);
                return 0;
            }

            if (hdr->ack || hdr->nul)
            {
                if (hdr->ack)
                    LOGGER_DEBUG("ACK (%hu) in CLOSED: RST", hdr->ackseq);
                else
                    LOGGER_DEBUG("NUL in CLOSED: RST");

                Header rst;
                rst.rst = true;
                rst.seq = hdr->ackseq + 1; // FIXME RFC: if hdr->ack == false ackseq is not valid
                if (send(&rst, timeout, &peer) == -1)
                    return -1;
            }
            else
            {
                LOGGER_DEBUG("CLOSED: RST+ACK");

                Header rstack;
                rstack.rst = true;
                rstack.seq = 0;
                rstack.ack = true;
                rstack.ackseq = hdr->seq; // see RFC1151
                if (send(&rstack, timeout, &peer) == -1)
                    return -1;
            }

            return 0;
        }

        case STATE_CLOSE_WAIT:
        {
            if (hdr->rst)
            {
#if 1 // ndef STRICT_RFC
                // move to CLOSE, unlike what RFC1151 says

                LOGGER_DEBUG("RST in CLOSE_WAIT: shutdown connection");

                set_state(STATE_CLOSED);
#endif
            }

            LOGGER_DEBUG("CLOSE-WAIT: discard %hu", hdr->seq);
            return 0;
        }

        case STATE_LISTEN:
        {
            if (hdr->rst)
            {
                LOGGER_DEBUG("RST in LISTEN: discard %hu", hdr->seq);
                return 0;
            }

            if (hdr->ack || hdr->nul)
            {
                if (hdr->ack)
                    LOGGER_DEBUG("ACK (%hu) in LISTEN: RST", hdr->ackseq);
                else
                    LOGGER_DEBUG("NUL in LISTEN: RST");

                Header rst;
                rst.rst = true;
                rst.seq = hdr->ackseq + 1; // FIXME RFC: if hdr->ack == false ackseq is not valid
                if (send(&rst, timeout, &peer) == -1)
                    return -1;

                return 0;
            }

            if (hdr->syn)
            {
                LOGGER_DEBUG("SYN in LISTEN: SYN+ACK");

                destaddr(&peer);
                set_state(STATE_SYN_RCVD);

                const SYNHeader* syn = reinterpret_cast<SYNHeader*>(hdr.get());
                _rcvcur = syn->seq;
                _rcvirs = syn->seq;
                _rcvmns = syn->mns;
                LOGGER_DEBUG("RCV.CUR=%hu RCV.IRS=%hu RCV.MNS=%hu", _rcvcur, _rcvirs, _rcvmns);

                // Send SYN+ACK

                SYNHeader synack;
                synack.syn = true;
                synack.seq = _sndiss;
                synack.mns = _sndmns;
                synack.ack = true;
                synack.ackseq = _rcvcur;
                if (send(&synack, timeout, &peer) == -1)
                    return -1;
                _sndnxt = _sndiss + 1;
#if 1 // ndef STRICT_RFC
                _rcvuna = _rcvcur + 1;
#endif

                return 0;
            }

            LOGGER_DEBUG("LISTEN: discard %hu", hdr->seq);
            return 0;
        }

        case STATE_SYN_SENT:
        {
            if (hdr->rst)
            {
                if (hdr->ack && matches_dest(&peer))
                {
                    LOGGER_DEBUG("RST+ACK in SYN-SENT: connection refused");

                    set_state(STATE_CLOSED);

                    errno = ECONNREFUSED;
                    return 0;
                }

                LOGGER_DEBUG("RST in SYN-SENT: discard seg %hu", hdr->seq);
                return 0;
            }

#if 1 // ndef STRICT_RFC
            // RFC1151 says:
            // "The test for the ACK bit should be placed after all the other tests"
            // but I think it needs to be *before* the test for SYN
            // to ensure the SYN-ACK corresponds to the SYN we went

            if (hdr->ack && hdr->ackseq != _sndiss)
            {
                LOGGER_DEBUG("ACK (%hu) in SYN-SENT for unexpected ackseq: RST", hdr->ackseq);

                set_state(STATE_CLOSED); // see RFC1151

                Header rst;
                rst.rst = true;
                rst.seq = hdr->ackseq + 1;
                if (send(&rst, timeout, &peer) == -1)
                    return -1;

                errno = ECONNRESET;
                return 0;
            }
#endif

            if (hdr->syn)
            {
                const SYNHeader* syn = reinterpret_cast<SYNHeader*>(hdr.get());
                _rcvcur = syn->seq;
                _rcvirs = syn->seq;
                _rcvmns = syn->mns;
                LOGGER_DEBUG("RCV.CUR=%hu RCV.IRS=%hu RCV.MNS=%hu", _rcvcur, _rcvirs, _rcvmns);

                if (hdr->ack)
                {
                    LOGGER_DEBUG("SYN+ACK (%hu) in SYN-SENT: open connection + ACK", hdr->ackseq);

                    _snduna = hdr->ackseq + 1; // see RFC1151
                    LOGGER_DEBUG("SND.UNA=%hu", _snduna);

#ifdef LOGGER_OSTREAM
                    const bool flushed = flush_outq();
                    if (flushed && LOGGER_IS_DEBUG())
                    {
                        LOGGER_ODEBUG(cdbg) << "OUTQ (" << _outq.size() << ") =" << _outq;
                    }
#endif

                    destaddr(&peer);
                    set_state(STATE_OPEN);

                    Header ack;
                    ack.ack = true;
                    ack.seq = _sndnxt;
                    ack.ackseq = _rcvcur;
                    if (send(&ack, timeout, &peer) == -1)
                        return -1;
                }
                else
                {
                    LOGGER_DEBUG("SYN in SYN-SENT: SYN+ACK");

                    destaddr(&peer);
                    set_state(STATE_SYN_RCVD);

                    SYNHeader synack;
                    synack.syn = true;
                    synack.seq = _sndiss;
                    synack.mns = _sndmns;
                    synack.ack = true;
                    synack.ackseq = _rcvcur;
                    if (send(&synack, timeout, &peer) == -1)
                        return -1;
                    _sndnxt = _sndiss + 1;
                }

#if 1 // ndef STRICT_RFC
                _rcvuna = _rcvcur + 1;
#endif

                return 0;
            }

#if 0 // def STRICT_RFC
            // see above

            if (hdr->ack)
            {
                if (! hdr->rst && hdr->ackseq != _sndiss)
                {
                    LOGGER_DEBUG("ACK (%hu) in SYN-SENT for unexpected ackseq: RST", hdr->ackseq);

                    set_state(STATE_CLOSED); // see RFC1151

                    Header rst;
                    rst.rst = true;
                    rst.seq = hdr->ackseq + 1;
                    if (send(&rst, timeout, &peer) == -1)
                        return -1;

                    errno = ECONNRESET;
                    return 0;
                }
            }
#endif

            return 0;
        }

        case STATE_SYN_RCVD:
        {
            if (! (less16()(_rcvirs, hdr->seq)
                    && less_or_equal16()(hdr->seq, (uint16_t)(_rcvcur + (uint16_t)(_rcvmns * 2)))))
            {
#if 1 // ndef STRICT_RFC
                // allow connection to be re-established
                if (hdr->syn)
                {
                    LOGGER_DEBUG("SYN in SYN-RCVD: SYN+ACK");

                    const SYNHeader* syn = reinterpret_cast<SYNHeader*>(hdr.get());
                    if (_rcvcur != syn->seq
                        || _rcvirs != syn->seq
                        || _rcvmns != syn->mns
                        || ! matches_dest(&peer))
                    {
                        clear(); // shutdown current connection
                        init(); // start a new one

                        destaddr(&peer);
                        set_state(STATE_SYN_RCVD);

                        _rcvcur = syn->seq;
                        _rcvirs = syn->seq;
                        _rcvmns = syn->mns;
                        LOGGER_DEBUG("RCV.CUR=%hu RCV.IRS=%hu RCV.MNS=%hu", _rcvcur, _rcvirs, _rcvmns);
                    }

                    // Send SYN+ACK

                    SYNHeader synack;
                    synack.syn = true;
                    synack.seq = _sndiss;
                    synack.mns = _sndmns;
                    synack.ack = true;
                    synack.ackseq = _rcvcur;
                    if (send(&synack, timeout, &peer) == -1)
                        return -1;
                    _sndnxt = _sndiss + 1;
#if 1 // ndef STRICT_RFC
                    _rcvuna = _rcvcur + 1;
#endif

                    return 0;
                }
#endif

                LOGGER_DEBUG("Seg unacceptable in SYN-RCVD (RCV.IRS=%hu RCV.CUR=%hu RCV.MNS=%hu): discard %hu", _rcvirs, _rcvcur, _rcvmns, hdr->seq);

                Header ack;
                ack.ack = true;
                ack.seq = _sndnxt;
                ack.ackseq = _rcvcur;
                if (send(&ack, timeout, &peer) == -1)
                    return -1;
#if 1 // ndef STRICT_RFC
                _rcvuna = _rcvcur + 1;
#endif

                return 0;
            }

            if (hdr->rst)
            {
                LOGGER_DEBUG("RST in SYN-RCVD: connection refused");

                set_state(STATE_CLOSED);

                errno = ECONNREFUSED;
                return 0;
            }

            if (hdr->syn)
            {
#if 1 // ndef STRICT_RFC
                // this is not in RFC908

                const SYNHeader* syn = reinterpret_cast<SYNHeader*>(hdr.get());
                if (_rcvcur == syn->seq
                    && _rcvirs == syn->seq
                    && _rcvmns == syn->mns
                    && matches_dest(&peer))
                {
                    LOGGER_DEBUG("Duplicate SYN in SYN-RCVD: SYN+ACK");

                    // Send SYN+ACK

                    SYNHeader synack;
                    synack.syn = true;
                    synack.seq = _sndiss;
                    synack.mns = _sndmns;
                    synack.ack = true;
                    synack.ackseq = hdr->seq;
                    if (send(&synack, timeout, &peer) == -1)
                        return -1;
                    _sndnxt = _sndiss + 1;

                    return 0;
                }
#endif

                LOGGER_DEBUG("SYN in SYN-RCVD: connection reset + RST");

                set_state(STATE_CLOSED);

                Header rst;
                rst.rst = true;
                rst.seq = hdr->ackseq + 1; // FIXME: if hdr->ack == false ackseq is not valid
                if (send(&rst, timeout, &peer) == -1)
                    return -1;

                errno = ECONNRESET;
                return 0;
            }

#if 1 // ndef STRICT_RFC
            // allow connection to be established (below with ACK) even if EAK is received
            if (hdr->eak && ! hdr->ack)
#else
            if (hdr->eak)
#endif
            {
                LOGGER_DEBUG("EAK in SYN-RCVD: RST");

                set_state(STATE_CLOSED); // see RFC1151

                Header rst;
                rst.rst = true;
                rst.seq = hdr->ackseq + 1;
                if (send(&rst, timeout, &peer) == -1)
                    return -1;

                errno = ECONNRESET;
                return 0;
            }

            if (hdr->ack)
            {
                if (hdr->ackseq == _sndiss && matches_dest(&peer))
                {
                    LOGGER_DEBUG("ACK (%hu) in SYN-RCVD: open connection", hdr->ackseq);

                    destaddr(&peer);
                    set_state(STATE_OPEN);
                }
                else
                {
                    LOGGER_DEBUG("ACK (%hu) in SYN-RCVD: RST", hdr->ackseq);

                    set_state(STATE_CLOSED); // see RFC1151

                    Header rst;
                    rst.rst = true;
                    rst.seq = hdr->ackseq + 1;
                    if (send(&rst, timeout, &peer) == -1)
                        return -1;

                    errno = ECONNRESET;
                    return 0;
                }
            }

            if (hdr->datalen > 0 || hdr->nul)
            {
                if (receive_data(hdr, timeout, &peer) == -1)
                    return -1;
            }

            return 0;
        }

        case STATE_OPEN:
        {
            if (! (less16()(_rcvcur, hdr->seq)
                    && less_or_equal16()(hdr->seq, (uint16_t)(_rcvcur + (uint16_t)(_rcvmns * 2)))))
            {
#if 1 // ndef STRICT_RFC
                // allow connection to be re-established
                if (hdr->syn)
                {
                    LOGGER_DEBUG("SYN in OPEN: SYN+ACK");

                    const SYNHeader* syn = reinterpret_cast<SYNHeader*>(hdr.get());
                    if (_rcvcur != syn->seq
                        || _rcvirs != syn->seq
                        || _rcvmns != syn->mns
                        || ! matches_dest(&peer))
                    {
                        clear(); // shutdown current connection
                        init(); // start a new one

                        destaddr(&peer);
                        set_state(STATE_SYN_RCVD);

                        _rcvcur = syn->seq;
                        _rcvirs = syn->seq;
                        _rcvmns = syn->mns;
                        LOGGER_DEBUG("RCV.CUR=%hu RCV.IRS=%hu RCV.MNS=%hu", _rcvcur, _rcvirs, _rcvmns);
                    }

                    // Send SYN+ACK

                    SYNHeader synack;
                    synack.syn = true;
                    synack.seq = _sndiss;
                    synack.mns = _sndmns;
                    synack.ack = true;
                    synack.ackseq = _rcvcur;
                    if (send(&synack, timeout, &peer) == -1)
                        return -1;
                    _sndnxt = _sndiss + 1;
#if 1 // ndef STRICT_RFC
                    _rcvuna = _rcvcur + 1;
#endif

                    return 0;
                }
#endif

                LOGGER_DEBUG("Seq unacceptable in OPEN (RCV.CUR=%hu RCV.MNS=%hu): discard %hu", _rcvcur, _rcvmns, hdr->seq);

                Header ack;
                ack.ack = true;
                ack.seq = _sndnxt;
                ack.ackseq = _rcvcur;
                if (send(&ack, timeout, &peer) == -1)
                    return -1;
#if 1 // ndef STRICT_RFC
                _rcvuna = _rcvcur + 1;
#endif

                return 0;
            }

            if (hdr->rst)
            {
#if 0 // def STRICT_RFC
                LOGGER_DEBUG("RST in OPEN: connection reset");

                set_state(STATE_CLOSE_WAIT);
#else
                // two-way handshake close

                LOGGER_DEBUG("RST in OPEN: connection reset + RST+ACK");

                set_state(STATE_CLOSE_WAIT);

                Header rstack;
                rstack.rst = true;
                rstack.seq = _sndnxt;
                rstack.ack = true;
                rstack.ackseq = hdr->seq;
                if (send(&rstack, timeout, &peer) == -1)
                    return -1;
#endif

                errno = ECONNRESET;
                return 0;
            }

            if (hdr->nul)
            {
                LOGGER_DEBUG("NUL in OPEN: ACK");

                _rcvcur = hdr->seq;
                LOGGER_DEBUG("RCV.CUR=%hu", _rcvcur);

                Header ack;
                ack.ack = true;
                ack.seq = _sndnxt;
                ack.ackseq = _rcvcur;
                if (send(&ack, timeout, &peer) == -1)
                    return -1;
#if 1 // ndef STRICT_RFC
                _rcvuna = _rcvcur + 1;
#endif

                return 0;
            }

            if (hdr->syn)
            {
                LOGGER_DEBUG("SYN in OPEN: RST");

                set_state(STATE_CLOSED);

                Header rst;
                rst.rst = true;
                rst.seq = hdr->ackseq + 1; // FIXME: if hdr->ack == false ackseq is not valid
                if (send(&rst, timeout, &peer) == -1)
                    return -1;

                errno = ECONNRESET;
                return 0;
            }

            if (hdr->ack)
            {
                LOGGER_DEBUG("ACK %hu", hdr->ackseq);

                if (less_or_equal16()(_snduna, hdr->ackseq) && less16()(hdr->ackseq, _sndnxt))
                {
                    _snduna = hdr->ackseq + 1; // see RFC1151
                    LOGGER_DEBUG("Flushing acknowledged segments SND.UNA=%hu SND.NXT=%hu", _snduna, _sndnxt);

                    // Flush acknowledged segments

#ifdef LOGGER_OSTREAM
                    const bool flushed = flush_outq();
                    if (flushed && LOGGER_IS_DEBUG())
                    {
                        LOGGER_ODEBUG(cdbg) << "OUTQ (" << _outq.size() << ") =" << _outq;
                    }
#endif
                }
                else
                {
                    LOGGER_DEBUG("No segments to flush SND.UNA=%hu SND.NXT=%hu", _snduna, _sndnxt);
                }
            }

            if (hdr->eak)
            {
                // Flush acknowledged segments

                const EAKHeader* eak = reinterpret_cast<EAKHeader*>(hdr.get());
                const unsigned neak = eak->neak();
                LOGGER_DEBUG("EAK %hu (neak=%u)", hdr->ackseq, neak);
                LOGGER_ASSERT2(neak <= _rcvmns, neak, _rcvmns);

#ifdef LOGGER_OSTREAM
                bool flushed = false;
#endif
                for (unsigned i = 0; i < neak; ++i)
                {
                    const uint16_t eakseq = eak->eakseq[i];
                    if (less_or_equal16()(_snduna, eakseq) && less16()(eakseq, _sndnxt))
                    {
                        LOGGER_DEBUG("EAK %hu", eakseq);
#ifdef LOGGER_OSTREAM
                        if (flush_outq(eakseq))
                            flushed = true;
#else
                        (void) flush_outq(eakseq);
#endif
                    }
#ifndef NDEBUG
                    else if (less_or_equal16()(_sndnxt, eakseq))
                        LOGGER_DEBUG("Spurious eak %hu > SNDNXT=%hu", eakseq, _sndnxt);
#endif
                }

#ifdef LOGGER_OSTREAM
                if (flushed && LOGGER_IS_DEBUG())
                {
                    LOGGER_ODEBUG(cdbg) << "OUTQ (" << _outq.size() << ") =" << _outq;
                }
#endif
            }

            if (hdr->datalen > 0)
            {
                if (receive_data(hdr, timeout, &peer) == -1)
                    return -1;
            }

            return 0;
        }
        }
        UNREACHABLE();
    }

    int receive_data(std::auto_ptr<Header>& hdr, struct timeval* timeout, struct sockaddr_in* peer)
    {
        if (hdr->datalen > 0)
        {
#if 1 // ndef STRICT_RFC
            if (_inq.size() >= _rcvmns)
            {
                LOGGER_WARN("INQ full (RCV.MNS=%hu): discard %hu", _rcvmns, hdr->seq);

                Header ack;
                ack.ack = true;
                ack.seq = _sndnxt;
                ack.ackseq = _rcvcur;
                if (send(&ack, timeout, peer) == -1)
                    return -1;
                _rcvuna = _rcvcur + 1;

                return 0;
            }
#endif

            if (hdr->seq == (uint16_t)(_rcvcur + 1))
            {
                LOGGER_DEBUG("Received seg %hu is in sequence", hdr->seq);

                _rcvcur = hdr->seq;

#if 1 // ndef STRICT_RFC
                // advance _rcvcur to the last received seg in sequence

                for (InQ::const_iterator it = _inq.begin(); it != _inq.end(); ++it)
                {
                    if ((*it)->seq == (uint16_t)(_rcvcur + 1))
                        _rcvcur = (*it)->seq;
                    else if (less16()((uint16_t)(_rcvcur + 1), (*it)->seq))
                        break;
                }
#endif

                LOGGER_DEBUG("RCV.CUR=%hu", _rcvcur);
            }
            else
            {
                LOGGER_DEBUG("Received seg %hu is out of sequence (RCV.CUR=%hu)", hdr->seq, _rcvcur);
            }

            std::pair<InQ::iterator, bool> pair = _inq.insert(hdr.get());
            if (! pair.second)
            {
                LOGGER_DEBUG("Received seg %hu has already been received", (*pair.first)->seq);
            }
            else
            {
                hdr.release();

#ifdef LOGGER_OSTREAM
                if (LOGGER_IS_DEBUG())
                {
                    LOGGER_ODEBUG(cdbg) << "INQ (" << _inq.size() << ") =" << _inq;
                }
#endif
            }
            LOGGER_ASSERT(! _inq.empty());
            LOGGER_ASSERT2(_inq.size() <= _rcvmns, _inq.size(), _rcvmns);
        }

        // send back ACK
        // this logic doesn't follow RFC908:
        // it always sends as much ack's as possible, whether the
        // received seg was in sequence or not

        unsigned neak = 0;
        for (InQ::const_iterator it = _inq.begin(); it != _inq.end(); ++it)
        {
            if (less16()(_rcvcur, (*it)->seq))
                ++neak;
        }

        if (neak == 0)
        {
#if 1 // ndef STRICT_RFC
            // wait until _rcvmns seg before sending ACK
            if (less16()(_rcvcur, _rcvuna + _rcvmns - 1))
            {
                LOGGER_DEBUG("Delay acknowledge of %hu (neak=0, RCV.UNA=%hu, RCV.MNS=%hu)", _rcvcur, _rcvuna, _rcvmns);
            }
            else
            {
                LOGGER_DEBUG("Acknowledge %hu (neak=0, RCV.UNA=%hu)", _rcvcur, _rcvuna);

                Header ack;
                ack.ack = true;
                ack.seq = _sndnxt;
                ack.ackseq = _rcvcur;
                if (send(&ack, timeout, peer) == -1)
                    return -1;
                _rcvuna = _rcvcur + 1;
            }
#else
            LOGGER_DEBUG("Acknowledge %hu (neak=0)", _rcvcur);

            Header ack;
            ack.ack = true;
            ack.seq = _sndnxt;
            ack.ackseq = _rcvcur;
            if (send(&ack, timeout, peer) == -1)
                return -1;
#endif
        }
        else
        {
#ifdef LOGGER_OSTREAM
            if (LOGGER_IS_DEBUG())
            {
                LOGGER_ODEBUG(cdbg) << "Acknowledge " << _rcvcur << " (neak=" << neak << ")";
                for (InQ::const_iterator it = _inq.begin(); it != _inq.end(); ++it)
                {
                    if (less16()(_rcvcur, (*it)->seq))
                        cdbg << " " << (*it)->seq;
                }
            }
#endif

            std::auto_ptr<EAKHeader> eak(new (neak, 0) EAKHeader(neak));
            if (eak.get() == NULL)
                return -1;
            eak->eak = true;
            eak->seq = _sndnxt;
            eak->ack = true;
            eak->ackseq = _rcvcur;

            unsigned i = 0;
            for (InQ::const_iterator it = _inq.begin(); it != _inq.end(); ++it)
            {
                if (less16()(_rcvcur, (*it)->seq))
                    eak->eakseq[i++] = (*it)->seq;
            }
            LOGGER_ASSERT2(i == neak, i, neak);

            if (send(eak.get(), timeout, peer) == -1)
                return -1;
#if 1 // ndef STRICT_RFC
            _rcvuna = _rcvcur + 1;
#endif
        }

        return 0;
    }

    int run_output(struct timeval* timeout)
    {
        LOGGER_ASSERT(! _outq.empty());

        Header* hdr = _outq.front().second;
        struct sockaddr_in* dest = _outq.front().third;

        if (_outq.front().first.tv_sec > 0
            || _outq.front().first.tv_usec > 0)
        {
            LOGGER_DEBUG("%hu timed out. Resend.", hdr->seq);
        }

        if (send(hdr, timeout, dest) == -1)
            return -1;

        (void) reschedule(hdr, dest);

        return 0;
    }

    bool flush_outq()
    {
        bool flushed = false;
        for (OutQ::iterator it = _outq.begin(); it != _outq.end(); )
        {
            if (less16()(it->second->seq, _snduna))
            {
                LOGGER_DEBUG("Flushing seg %hu", it->second->seq);

                delete it->second;
                it = _outq.erase(it);
                flushed = true;
            }
            else
            {
                ++it;
            }
        }
        return flushed;
    }

    bool flush_outq(uint16_t eakseq)
    {
        for (OutQ::iterator it = _outq.begin(); it != _outq.end(); ++it)
        {
            if (it->second->seq == eakseq)
            {
                LOGGER_DEBUG("Flushing seg %hu", eakseq);

                delete it->second;

                (void) _outq.erase(it);

                return true;
            }
        }
        return false;
    }

    inline bool input_pending() const
    {
        return ! _inq.empty()
            && less_or_equal16()((*_inq.begin())->seq, _rcvcur);
    }

    inline bool output_pending() const
    {
        return _state == STATE_OPEN && ! _outq.empty();
    }

    void init()
    {
        // RFC908
        uint16_t sndiss;
        do
        {
            sndiss = (uint16_t) rand();
        } while (abs(diff16(_sndiss, sndiss)) <= 2 * _sndmns);
        _sndiss = sndiss;
        LOGGER_DEBUG("SND.ISS = %hu", _sndiss);

        _sndnxt = _sndiss; // deviate from RFC908: implementation detail
        _snduna = _sndiss;
        LOGGER_DEBUG("SND.UNA = %hu", _snduna);

        LOGGER_ASSERT1(_outq.empty(), _outq.size());
        LOGGER_ASSERT1(_inq.empty(), _inq.size());

        _rcvcur = _rcvmns = _rcvirs = 0;
#if 1 // ndef STRICT_RFC
        _rcvuna = 0;
#endif
    }

    void clear()
    {
        if (! _outq.empty())
        {
            for (OutQ::iterator it = _outq.begin(); it != _outq.end(); ++it)
                delete it->second;
            _outq.clear();
            LOGGER_DEBUG("OUTQ (0) =");
        }

        if (! _inq.empty())
        {
            for (InQ::iterator it = _inq.begin(); it != _inq.end(); ++it)
                delete (*it);
            _inq.clear();
            LOGGER_DEBUG("INQ (0) =");
        }
    }

    void set_state(State state)
    {
        if (_state == state)
            return;

        switch (state)
        {
        case STATE_CLOSED:
            clear();
            destaddr(NULL);

            LOGGER_DEBUG("\n*** state = CLOSED (%d) ***", state);
            break;

        case STATE_LISTEN:
            init();

            LOGGER_DEBUG("\n*** state = LISTEN (%d) ***", _state);
            break;

        case STATE_SYN_SENT:
            LOGGER_DEBUG("\n*** state = SYN-SENT (%d) ***", state);
            break;

        case STATE_SYN_RCVD:
            LOGGER_DEBUG("\n*** state = SYN-RCVD (%d) with %s:%u ***", state, destname(), destport());
            break;

        case STATE_OPEN:
            LOGGER_DEBUG("\n*** state = OPEN (%d) with %s:%u ***\n", state, destname(), destport());
            break;

        case STATE_CLOSE_WAIT:
            clear();

            LOGGER_DEBUG("\n*** state = CLOSE-WAIT (%d) ***", state);
            break;
        }
        _state = state;
    }

    uint16_t checksum(Header* hdr)
    {
        if (_cscov < 0)
            return 0;

        uint16_t cscov;
        if (_cscov == 0) // entire seg
            cscov = hdr->hdrlen + hdr->datalen;
        else if (_cscov <= hdr->hdrlen) // only the header
            cscov = hdr->hdrlen;
        else if (_cscov <= hdr->hdrlen + hdr->datalen)
            cscov = _cscov;
        else
            cscov = hdr->hdrlen + hdr->datalen;

        hdr->checksum = 0;

        INet::Checksum sum;
        sum.update(hdr, cscov);
        return sum.checksum();
    }

    static int timestamp(struct timeval* tv)
    {
#if (_POSIX_C_SOURCE - 0) >= 199309L
        struct timespec ts;
        if (clock_gettime(CLOCK_MONOTONIC, &ts) == -1)
        {
            LOGGER_PERROR("clock_gettime(CLOCK_MONOTONIC)");
            return -1;
        }

        tv->tv_sec = ts.tv_sec;
        tv->tv_usec = ts.tv_nsec / 1000;

        return 0;
#elif defined(__APPLE__) // see https://gist.github.com/jbenet/1087739
        clock_serv_t cclock;
        mach_timespec_t mts;
        host_get_clock_service(mach_host_self(), REALTIME_CLOCK, &cclock);
        int r = clock_get_time(cclock, &mts);
        mach_port_deallocate(mach_task_self(), cclock);
        if (r == -1)
        {
            LOGGER_PERROR("clock_get_time");
            return -1;
        }

        tv->tv_sec = mts.tv_sec;
        tv->tv_usec = mts.tv_nsec / 1000;

        return 0;
#else
        if (gettimeofday(tv, NULL) == -1)
        {
            LOGGER_PERROR("gettimeofday");
            return -1;
        }
        return 0;
#endif
    }

protected:

    State _state;

    OutQ _outq;
    InQ _inq;

    int32_t _cscov;     // checksum coverage;
                        // < 0: disabled
                        // 0: all message
                        // > 0: up-to (min = sizeof header)

    uint16_t _sndiss;   // The initial send sequence number
    uint16_t _sndnxt;   // The sequence number of the next segment that is to be sent
    uint16_t _snduna;   // The sequence number of the oldest unacknowledged segment
    uint16_t _sndmns;   // The maximum number of outstanding (unacknowledged) segments that can be sent
    uint16_t _rcvcur;   // The sequence number of the last segment received correctly and in sequence
    uint16_t _rcvmns;   // The maximum number of segments that can be buffered for this connection
    uint16_t _rcvirs;   // The initial receive sequence number

#if 1 // ndef STRICT_RFC
    uint16_t _rcvuna;   // The sequence number of the oldest unacknowledged (received) segment
#endif
};

#endif
