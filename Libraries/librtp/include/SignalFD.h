
#ifndef _SIGNAL_FD_H_
#define _SIGNAL_FD_H_

#include <signal.h>
#include <string.h>
#include <unistd.h>

#include <sys/types.h>

#ifdef __linux__
#  include <sys/signalfd.h>
#elif defined(__APPLE__)
#  include <sys/event.h>
#  include <sys/time.h>
#endif

#include "Net.h"
#include "Logger.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                             SignalFD                              //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class SignalFD
    : public Socket
{
public:

    SignalFD(const sigset_t* mask)
    {
#ifdef __linux__

        for (int i = 1; i < _NSIG; ++i)
        {
            if (sigismember(mask, i))
            {
                struct sigaction sa;
                memset(&sa, 0, sizeof(struct sigaction));
                sa.sa_handler = SIG_IGN;
                if (sigaction(i, &sa, NULL) == -1)
                    LOGGER_PWARN("sigaction(%d)", i);
            }
        }

        if (pthread_sigmask(SIG_BLOCK, mask, NULL) == -1)
            LOGGER_PWARN("pthread_sigmask");

        _sockfd = signalfd(-1, mask, 0);
        if (_sockfd == -1)
            LOGGER_PERROR("signalfd");

#elif defined(__APPLE__)

        _kelist = NULL;
        _nsig = 0;
        for (int i = 1; i < NSIG; ++i)
        {
            if (sigismember(mask, i))
            {
                ++_nsig;
                if (signal(i, SIG_IGN) == SIG_ERR)
                    LOGGER_PWARN("signal(%d, SIG_IGN)", i);
            }
        }
        LOGGER_ASSERT1(_nsig > 0, _nsig);

        _sockfd = kqueue();
        if (_sockfd == -1)
        {
            LOGGER_PERROR("kqueue");
        }
        else
        {
            _kelist = new struct kevent[_nsig];
            unsigned j = 0;
            for (int i = 1; j < _nsig && i < NSIG; ++i)
            {
                if (sigismember(mask, i))
                {
                    EV_SET(&_kelist[j], i, EVFILT_SIGNAL, EV_ADD | EV_ENABLE, 0, 0, NULL);
                    ++j;
                }
            }
        }

#else
#  error "platform not supported"
#endif
    }

#ifdef __APPLE__
    virtual ~SignalFD()
    {
        delete[] _kelist;

        Socket::~Socket();
    }
#endif

    virtual int close()
    {
        if (::close(_sockfd) == -1)
        {
            LOGGER_PERROR("close");
            return -1;
        }

        _sockfd = -1;
        return 0;
    }

    ssize_t read(int* signo)
    {
#ifdef __linux__

        struct signalfd_siginfo fdsi;
        const ssize_t n = ::read(_sockfd, &fdsi, sizeof(struct signalfd_siginfo));
        if (n == -1)
        {
            LOGGER_PERROR("read");
            return -1;
        }
        *signo = fdsi.ssi_signo;

#elif defined(__APPLE__)

        struct kevent ke;
        const int n = kevent(_sockfd, _kelist, _nsig, &ke, 1, NULL);
        if (n == -1)
        {
            LOGGER_PERROR("kevent");
            return -1;
        }
        LOGGER_ASSERT1(n == 1, n);
        *signo = ke.ident;

#else
#  error "platform not supported"
#endif

        LOGGER_DEBUG("+++ signal %d +++", *signo);
        return sizeof(int);
    }

    ssize_t write(int signo)
    {
        if (raise(signo) != 0)
        {
            LOGGER_PERROR("raise");
            return -1;
        }
#ifdef __linux__
        return sizeof(struct signalfd_siginfo);
#elif defined(__APPLE__)
        return sizeof(uintptr_t);
#else
#  error "platform not supported"
#endif
    }

private:

#ifdef __APPLE__
    struct kevent* _kelist;
    unsigned _nsig;
#endif
};

#endif
