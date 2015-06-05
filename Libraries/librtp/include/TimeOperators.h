
#ifndef _TIME_OPERATORS_H_
#define _TIME_OPERATORS_H_

#include <time.h>

#ifdef __APPLE__
#  include <mach/clock.h>
#  include <mach/mach.h>
#  include <mach/mach_time.h>
#endif

#include <locale>

#include "Logger.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             TIMEVAL                               //
//                                                                   //
///////////////////////////////////////////////////////////////////////

#ifdef LOGGER_OSTREAM
std::ostream& operator<<(std::ostream& out, const struct timeval& tv)
{
    if (! out)
        return out;

    // force default locale (for grouping char)
    std::locale oldlocale = out.imbue(std::locale(""));
    if (tv.tv_sec > 0)
    {
        if (tv.tv_sec > 24 * 60 * 60) // 1 day
        {
            // assume tv is an actual date (not an elapsed time)

            struct tm tm;
            if (localtime_r(&tv.tv_sec, &tm) != NULL)
            {
                char tmp[32];
                const size_t n = strftime(tmp, sizeof(tmp), "%F %T", &tm);
                LOGGER_ASSERT(n > 0);
                out << tmp;

                if (tv.tv_usec > 0)
                    out << '.';
            }
            else
            {
                out << tv.tv_sec << 's';
            }
        }
        else
        {
            out << tv.tv_sec << 's';
        }
        if (tv.tv_usec > 0)
        {
            // %'06ld
            out.width(6);
            num_put<char>().put(out, out, '0', (unsigned long)tv.tv_usec);
        }
    }
    else
    {
        out << tv.tv_usec << "us";
    }
    out.imbue(oldlocale);

    return out;
}
#endif

static inline void
timespec_to_timeval(const struct timespec& ts, struct timeval& tv)
{
    tv.tv_sec = ts.tv_sec;
    tv.tv_usec = ts.tv_nsec / 1000;
}

inline struct timeval&
operator+=(struct timeval& a, const struct timeval& b)
{
    a.tv_sec += b.tv_sec;
    a.tv_usec += b.tv_usec;
    while (a.tv_usec > 1000000)
    {
        a.tv_sec += 1;
        a.tv_usec -= 1000000;
    }
    return a;
}

inline struct timeval&
operator+=(struct timeval& a, long n)
{
    a.tv_sec += n / 1000000;
    a.tv_usec += n % 1000000;
    while (a.tv_usec > 1000000)
    {
        a.tv_sec += 1;
        a.tv_usec -= 1000000;
    }
    return a;
}

inline struct timeval
operator+(struct timeval a, const struct timeval b)
{
    return a += b;
}

inline struct timeval&
operator-=(struct timeval& a, const struct timeval& b)
{
    a.tv_sec -= b.tv_sec;
    a.tv_usec -= b.tv_usec;
    while (a.tv_usec < 0)
    {
        a.tv_sec -= 1;
        a.tv_usec += 1000000;
    }
    return a;
}

inline struct timeval
operator-(struct timeval a, const struct timeval b)
{
    return a -= b;
}

inline struct timeval&
operator-=(struct timeval& a, const struct timespec& b)
{
    struct timeval c;
    timespec_to_timeval(b, c);
    return a -= c;
}

inline bool
operator==(const struct timeval& a, const struct timeval& b)
{
    return a.tv_sec == b.tv_sec
        && a.tv_usec == b.tv_usec;
}

inline bool
operator!=(const struct timeval& a, const struct timeval& b)
{
    return a.tv_sec != b.tv_sec
        || a.tv_usec != b.tv_usec;
}

inline bool
operator<(struct timeval a, const struct timeval& b)
{
    return a.tv_sec < b.tv_sec
        || (a.tv_sec == b.tv_sec && a.tv_usec < b.tv_usec);
}

inline bool
operator<=(struct timeval a, const struct timeval& b)
{
    return a.tv_sec < b.tv_sec
        || (a.tv_sec == b.tv_sec && a.tv_usec <= b.tv_usec);
}

inline unsigned long
elapseds(struct timeval a, const struct timeval& b)
{
    LOGGER_ASSERT2(b <= a, a, b);
    a -= b;
    return a.tv_sec + (long)(a.tv_usec / 1e6);
}

inline unsigned long
elapsedms(struct timeval a, const struct timeval& b)
{
    LOGGER_ASSERT2(b <= a, a, b);
    a -= b;
    return a.tv_sec * 1000L + (long)(a.tv_usec / 1e3);
}

// This will overflow after
// ULONG_MAX = 4294967295us = 4294s = 71min = 1h11
inline unsigned long
elapsedus(struct timeval a, const struct timeval& b)
{
    LOGGER_ASSERT2(b <= a, a, b);
    a -= b;
    return a.tv_sec * 1000000L + a.tv_usec;
}

inline double
elapsed(struct timeval a, const struct timeval& b)
{
    a -= b;
    return a.tv_sec + a.tv_usec / 1e6;
}

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             TIMESPEC                              //
//                                                                   //
///////////////////////////////////////////////////////////////////////

#ifdef LOGGER_OSTREAM
std::ostream& operator<<(std::ostream& out, const struct timespec& ts)
{
    if (! out)
        return out;

    // force default locale (for grouping char)
    std::locale oldlocale = out.imbue(std::locale(""));
    if (ts.tv_sec > 0)
    {
        out << ts.tv_sec << 's';
        if (ts.tv_nsec > 0)
        {
            // %'09ld
            out.width(9);
            num_put<char>().put(out, out, '0', ts.tv_nsec);
        }
    }
    else
    {
        out << ts.tv_nsec << "ns";
    }
    out.imbue(oldlocale);
    return out;
}
#endif

static inline void
timeval_to_timespec(const struct timeval& tv, struct timespec& ts)
{
    ts.tv_sec = tv.tv_sec;
    ts.tv_nsec = tv.tv_usec * 1000;
}

inline struct timespec&
operator+=(struct timespec& a, const struct timespec& b)
{
    a.tv_sec += b.tv_sec;
    a.tv_nsec += b.tv_nsec;
    while (a.tv_nsec > 1000000000L)
    {
        a.tv_sec += 1;
        a.tv_nsec -= 1000000000L;
    }
    return a;
}

inline struct timespec&
operator-=(struct timespec& a, const struct timespec& b)
{
    a.tv_sec -= b.tv_sec;
    a.tv_nsec -= b.tv_nsec;
    while (a.tv_nsec < 0)
    {
        a.tv_sec -= 1;
        a.tv_nsec += 1000000000L;
    }
    return a;
}

inline struct timespec&
operator-=(struct timespec& a, const struct timeval& b)
{
    struct timespec c;
    timeval_to_timespec(b, c);
    return a -= c;
}

inline bool
operator==(const struct timespec& a, const struct timespec& b)
{
    return a.tv_sec == b.tv_sec
        && a.tv_nsec == b.tv_nsec;
}

inline bool
operator<(struct timespec a, const struct timespec& b)
{
    a -= b;
    return a.tv_sec < 0;
}

inline bool
operator<=(struct timespec a, const struct timespec& b)
{
    a -= b;
    return a.tv_sec < 0 || (a.tv_sec == 0 && a.tv_nsec == 0);
}

inline unsigned long
elapseds(struct timespec a, const struct timespec& b)
{
    LOGGER_ASSERT2(b <= a, a, b);
    a -= b;
    return a.tv_sec + (long)(a.tv_nsec / 1e9);
}

inline unsigned long
elapsedms(struct timespec a, const struct timespec& b)
{
    LOGGER_ASSERT2(b <= a, a, b);
    a -= b;
    return a.tv_sec * 1000L + (long)(a.tv_nsec / 1e6);
}

// This will overflow after
// ULONG_MAX = 4294967295us = 4294s = 71min = 1h11
inline unsigned long
elapsedus(struct timespec a, const struct timespec& b)
{
    LOGGER_ASSERT2(b <= a, a, b);
    a -= b;
    return a.tv_sec * 1000000L + (long)(a.tv_nsec / 1e3);
}

// This will overflow after
// ULLONG_MAX = 18446744073709551615ns = 18446744073s = 584 yrs
inline unsigned long long
elapsedns(struct timespec a, const struct timespec& b)
{
    LOGGER_ASSERT2(b <= a, a, b);
    a -= b;
    return a.tv_sec * 1000000000ULL + a.tv_nsec;
}

inline double
elapsed(struct timespec a, const struct timespec& b)
{
    a -= b;
    return a.tv_sec + a.tv_nsec / 1e9;
}

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                            HiResTimer                             //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class HiResTimer
    : public timespec
{
public:

    HiResTimer()
    {
        reset();
    }

    HiResTimer(const struct timespec& other)
        : timespec(other)
    {}

    void reset()
    {
        timestamp(this);
    }

    unsigned long long elapsedns(const HiResTimer& other = HiResTimer()) const
    {
        return ::elapsedns(other, *this);
    }

    unsigned long elapsedus(const HiResTimer& other = HiResTimer()) const
    {
        return ::elapsedus(other, *this);
    }

    unsigned long elapsedms(const HiResTimer& other = HiResTimer()) const
    {
        return ::elapsedms(other, *this);
    }

    unsigned long elapseds(const HiResTimer& other = HiResTimer()) const
    {
        return ::elapseds(other, *this);
    }

    double elapsed(const HiResTimer& other = HiResTimer()) const
    {
        return ::elapsed(other, *this);
    }

private:

    static void timestamp(struct timespec* ts)
    {
#ifdef __APPLE__ // see https://gist.github.com/jbenet/1087739
        clock_serv_t cclock;
        mach_timespec_t mts;
        host_get_clock_service(mach_host_self(), REALTIME_CLOCK, &cclock);
        clock_get_time(cclock, &mts);
        mach_port_deallocate(mach_task_self(), cclock);

        ts->tv_sec = mts.tv_sec;
        ts->tv_nsec = mts.tv_nsec;
#else
        if (clock_gettime(CLOCK_MONOTONIC_RAW, ts) == -1)
            LOGGER_PWARN("clock_gettime(CLOCK_MONOTONIC_RAW)");
#endif
    }
};

#endif
