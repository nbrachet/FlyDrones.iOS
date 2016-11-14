
#ifndef _PINGER_H_
#define _PINGER_H_

#if defined(__GLIBC__) && !defined(_GNU_SOURCE)
#  define _GNU_SOURCE
#endif

#include <math.h>
#include <pthread.h>
#include <sched.h>

#include <sys/resource.h>
#include <sys/select.h>
#include <sys/time.h>

#include <atomic>

#include "ICMP.h"
#include "Thread.h"
#include "UDP.h"

///////////////////////////////////////////////////////////////////////

static int log_exec(const char* cmd,
                    int level = Logger::LEVEL_INFO, const char* prefix = NULL)
{
    FILE* f = popen(cmd,
#ifdef __GNU_LIBRARY__
                    "re"
#else
                    "r"
#endif
                    );
    if (f == NULL)
    {
        LOGGER_PERROR("popen(%s)", cmd);
        return -1;
    }

    if (prefix)
        logger.log(level, "%s: %s", prefix, cmd);
    else
        logger.log(level, "%s", cmd);

    char buf[128];
    while (fgets(buf, sizeof(buf), f))
    {
        char* eol = buf + strlen(buf) - 1;
        if (*eol == '\n')
            *eol = '\0';

        if (prefix)
            logger.log(level, "%s: %s", prefix, buf);
        else
            logger.log(level, "%s", buf);
    }

    (void) pclose(f);

    return 0;
}

///////////////////////////////////////////////////////////////////////
//                                                                   //
// PingTask                                                          //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class PingTask
    : public TimerTask
{
public:

    PingTask(const struct sockaddr_in& target,
             time_t seconds)
        : TimerTask(0, seconds)
        , _target(target.sin_addr, 0)
        , _reset(true)
        , _icmp()
        , _proto(_icmp ? "ICMP" : "UDP")
    {
#ifndef __linux__
        priority(priority() - 1);
        stacksize(16 * 1024);
#endif
    }

    virtual int start()
    {
        if (! LOGGER_IS_INFO())
            return 0;

        reset();

        return TimerTask::start();
    }

    void reset()
    {
        _reset = true;
    }

protected:

    virtual void execute()
    {
        if (_reset)
        {
            _ntransmitted = 0;
            _nreceived = 0;
            _tmin = HUGE;
            _tmax = 0;
            _tsum = 0;
            _tsumsq = 0;
            _reset = false;
        }

        struct timeval timeout = { 1, 0 };
        const int n = ping(&timeout);
        if (n <= 0)
        {
#ifndef __linux__
            testcancel();
#endif
            traceroute(&timeout);
        }
    }

    int ping(const struct timeval* timeout)
    {
        struct sockaddr_in from;
        uint8_t hops = 0;
        long timeus;

        int n;
        if (_icmp)
            n = _icmp.ping(&from, &timeus, 1, _target, timeout);
        else
            n = Datagram::ping(&from, &hops, &timeus, *_target, timeout);
        switch (n)
        {
        case -1:    // error
            return -1;

        case 0:     // timeout
            ++_ntransmitted;
            LOGGER_INFO("PING/%s: %-16s *", _proto, _target.ascii());
            break;

        case 1:     // success
            ++_ntransmitted;
            if (timeus >= 0)
            {
                ++_nreceived;
                const float t = timeus / 1000.0;
                if (t < _tmin)
                    _tmin = t;
                if (t > _tmax)
                    _tmax = t;
                _tsum += t;
                _tsumsq += t * t;

                LOGGER_INFO("PING/%s: %-3hhu %-16s %.3fms", _proto, hops, _target.ascii(), t);
            }
            else
            {
                LOGGER_INFO("PING/%s: %-3hhu %-16s %.3fms !", _proto, hops, _target.ascii(), timeus / -1000.0);
            }
            break;
        }

        if (_nreceived > 0)
        {
            const double tavg = _tsum / _nreceived;
            const double tstddev2 = _tsumsq / _nreceived - tavg * tavg;
            const double tstddev = tstddev2 <= 0 ? 0 : sqrt(tstddev2);
            LOGGER_INFO("PING/%s: %-16s %u/%u packets received (%.1f%%) %.3f min / %.3f avg / %.3f stddev / %.3f max",
                        _proto, _target.ascii(),
                        _nreceived, _ntransmitted, _nreceived * 100.0 / _ntransmitted,
                        _tmin, tavg, tstddev, _tmax);
        }
        else if (_ntransmitted > 0)
        {
            LOGGER_INFO("PING/%s: %-16s 0/%u packets received (0%%)",
                        _proto, _target.ascii(),
                        _ntransmitted);
        }

        return n;
    }

    int traceroute(const struct timeval* timeout)
    {
        static const unsigned maxttl = 30;

        struct sockaddr_in from[maxttl];
        long timeus[maxttl];

        const char* proto;
        int n = 0;
        if (_icmp)
        {
            proto = "ICMP";
            n = _icmp.traceroute(from, timeus, maxttl, _target, timeout);
            if (n == 0)
                LOGGER_INFO("TRACEROUTE/ICMP: %-16s *", _target.ascii());
        }
        if (n == 0)
        {
            proto = "UDP";
            n = Datagram::traceroute(from, NULL, timeus, maxttl, *_target, timeout);
            if (n == 0)
            {
                LOGGER_INFO("TRACEROUTE/UDP: %-16s *", _target.ascii());
                return 0;
            }
        }
        if (n > 0)
        {
            for (int i = 0; i < n; ++i)
            {
                if (timeus[i] > 0)
                {
                    INet::SockAddr f(from[i]);
                    LOGGER_INFO("TRACEROUTE/%s: %3i %-16s %.3fms", proto, i+1, f.ascii(), timeus[i] / 1000.0);
                }
                else if (timeus[i] < 0)
                {
                    INet::SockAddr f(from[i]);
                    LOGGER_INFO("TRACEROUTE/%s: %3i %-16s %.3fms !", proto, i+1, f.ascii(), timeus[i] / -1000.0);
                }
                else
                {
                    LOGGER_INFO("TRACEROUTE/%s: %3i *", proto, i+1);

                    int j;
                    for (j = i + 1; j < n; ++j)
                    {
                        if (timeus[j] != 0)
                            break;
                    }
                    if (j == n)
                        break;
                }
            }
            return n;
        }
        else
        {
            char cmd[80];
            snprintf(cmd, sizeof(cmd), "traceroute -n -w 1 -q 1 -m 30 %s 2>/dev/null", _target.ascii());
            log_exec(cmd, Logger::LEVEL_INFO, "TRACEROUTE");
            return 0;
        }
    }

private:

    const INet::SockAddr _target;

    std::atomic<bool> _reset;

        // NOT SYNCHRONIZED: only accessible in the thread

    ICMP _icmp;
    const char* _proto;
    unsigned _ntransmitted;
    unsigned _nreceived;
    float _tmin;
    float _tmax;
    double _tsum;
    double _tsumsq;
};

#endif
