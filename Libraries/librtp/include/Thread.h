
#ifndef _THREAD_H_
#define _THREAD_H_

#include <errno.h>
#include <pthread.h>
#include <unistd.h>

#ifdef __linux__
// pthread.h doesn't define PTHREAD_STACK_MIN on linux but limits.h does?!
#  include <limits.h>
#endif

#include <sys/select.h>

#include <atomic>

#include "Logger.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
// RWLock                                                            //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class RWLock
{
public:

    RWLock()
    {
        (void) pthread_rwlock_init(&_lock, NULL);
    }

    ~RWLock()
    {
        (void) pthread_rwlock_destroy(&_lock);
    }

    int rdlock()
    {
        return pthread_rwlock_rdlock(&_lock);
    }

    int wrlock()
    {
        return pthread_rwlock_wrlock(&_lock);
    }

    int unlock()
    {
        return pthread_rwlock_unlock(&_lock);
    }

private:

    pthread_rwlock_t _lock;

public:

    ///////////////////////////////////////////////////////////////////

    class ReaderGuard
    {
    public:

        ReaderGuard(RWLock& lock)
            : _lock(lock)
        {
            (void) _lock.rdlock();
        }

        ~ReaderGuard()
        {
            (void) _lock.unlock();
        }

    private:

        RWLock& _lock;
    };

    ///////////////////////////////////////////////////////////////////

    class WriterGuard
    {
    public:

        WriterGuard(RWLock& lock)
            : _lock(lock)
        {
            (void) _lock.wrlock();
        }

        ~WriterGuard()
        {
            (void) _lock.unlock();
        }

    private:

        RWLock& _lock;
    };
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
// UpgradableRWLock                                                  //
//                                                                   //
///////////////////////////////////////////////////////////////////////

// A simple implementation of an upgradable RWLock
// This implementation favors writers (assuming pthread_mutex_lock is fair)
class UpgradableRWLock
{
public:

    UpgradableRWLock()
        : _readers(0)
    {
        pthread_mutexattr_t attr;
        int r = pthread_mutexattr_init(&attr);
        if (r != 0)
            LOGGER_WARN("pthread_mutexattr_init: %s", strerror(r));

#ifndef NDEBUG
        r = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ERRORCHECK);
        if (r != 0)
            LOGGER_WARN("pthread_mutexattr_settype(PTHREAD_MUTEX_ERRORCHECK): %s", strerror(r));
#else
        r = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
        if (r != 0)
            LOGGER_WARN("pthread_mutexattr_settype(PTHREAD_MUTEX_RECURSIVE): %s", strerror(r));
#endif

        r = pthread_mutex_init(&_mutex, &attr);
        if (r != 0)
            LOGGER_CRITICAL("pthread_mutex_init: %s", strerror(r));

        r = pthread_mutexattr_destroy(&attr);
        if (r != 0)
            LOGGER_WARN("pthread_mutexattr_destroy: %s", strerror(r));

        (void) pthread_cond_init(&_no_readers, NULL);
        if (r != 0)
            LOGGER_CRITICAL("pthread_cond_init: %s", strerror(r));
    }

    ~UpgradableRWLock()
    {
        LOGGER_ASSERT1(_readers == 0, _readers);

        int r = pthread_cond_destroy(&_no_readers);
        if (r != 0)
            LOGGER_WARN("pthread_cond_destroy: %s", strerror(r));
        r = pthread_mutex_destroy(&_mutex);
        if (r != 0)
            LOGGER_WARN("pthread_mutex_destroy: %s", strerror(r));
    }

    int rdlock()
    {
        int r = pthread_mutex_lock(&_mutex);
            if (r != 0)
            {
                LOGGER_ERROR("pthread_mutex_lock: %s", strerror(r));
                return r;
            }

            ++_readers;

        r = pthread_mutex_unlock(&_mutex);
        if (r != 0)
            LOGGER_CRITICAL("pthread_mutex_unlock: %s", strerror(r));
        return r;
    }

    int rdunlock()
    {
        int r = pthread_mutex_lock(&_mutex);
            if (r != 0)
            {
                LOGGER_ERROR("pthread_mutex_lock: %s", strerror(r));
                return r;
            }

            LOGGER_ASSERT(_readers >= 1);

            if (--_readers == 0)
            {
                r = pthread_cond_signal(&_no_readers);
                if (r != 0)
                    LOGGER_WARN("pthread_cond_signal: %s", strerror(r));
            }

        r = pthread_mutex_unlock(&_mutex);
        if (r != 0)
            LOGGER_CRITICAL("pthread_mutex_unlock: %s", strerror(r));
        return r;
    }

    int rdupgrade()
    {
        int r = pthread_mutex_lock(&_mutex);
            if (r != 0)
            {
                LOGGER_ERROR("pthread_mutex_lock: %s", strerror(r));
                return r;
            }

            LOGGER_ASSERT(_readers >= 1);

            _readers -= 1;
            while (_readers >= 1)
            {
                r = pthread_cond_wait(&_no_readers, &_mutex);
                if (r != 0)
                    LOGGER_WARN("pthread_cond_wait: %s", strerror(r));
            }
            LOGGER_ASSERT1(_readers == 0, _readers);

            return 0;
    }

    int wrlock()
    {
        int r = pthread_mutex_lock(&_mutex);
            if (r != 0)
            {
                LOGGER_ERROR("pthread_mutex_lock: %s", strerror(r));
                return r;
            }

            while (_readers >= 1)
            {
                r = pthread_cond_wait(&_no_readers, &_mutex);
                if (r != 0)
                    LOGGER_WARN("pthread_cond_wait: %s", strerror(r));
            }

            LOGGER_ASSERT1(_readers == 0, _readers);

            return 0;
    }

    int wrdowngrade()
    {
            LOGGER_ASSERT1(_readers == 0, _readers);

            ++_readers;

        int r = pthread_mutex_unlock(&_mutex);
        if (r != 0)
            LOGGER_CRITICAL("pthread_mutex_unlock: %s", strerror(r));
        return r;
    }

    int wrunlock()
    {
            LOGGER_ASSERT1(_readers == 0, _readers);

        int r = pthread_mutex_unlock(&_mutex);
        if (r != 0)
            LOGGER_CRITICAL("pthread_mutex_unlock: %s", strerror(r));
        return r;
    }

private:

    pthread_mutex_t _mutex;
    pthread_cond_t _no_readers;
    unsigned _readers;

public:

    ///////////////////////////////////////////////////////////////////

    class ReaderGuard
    {
    public:

        ReaderGuard(UpgradableRWLock& lock)
            : _lock(lock)
        {
            (void) _lock.rdlock();
        }

        ~ReaderGuard()
        {
            (void) _lock.rdunlock();
        }

    private:

        UpgradableRWLock& _lock;
    };

    ///////////////////////////////////////////////////////////////////

    class WriterGuard;

    class ReaderWriterGuard
    {
    public:

        ReaderWriterGuard(UpgradableRWLock& lock, bool writer = false)
            : _lock(lock)
            , _writer(writer ? 1 : 0)
        {
            if (writer)
                (void) _lock.wrlock();
            else
                (void) _lock.rdlock();
        }

        ~ReaderWriterGuard()
        {
            LOGGER_ASSERT1(_writer <= 1, _writer);

            if (_writer == 1)
                (void) _lock.wrunlock();
            else
                (void) _lock.rdunlock();
        }

    protected:

        friend class WriterGuard;

        void upgrade()
        {
            if (_writer++ == 0)
                (void) _lock.rdupgrade();
        }

        void downgrade()
        {
            if (--_writer == 0)
                (void) _lock.wrdowngrade();
        }

    private:

        UpgradableRWLock& _lock;
        std::atomic<unsigned> _writer;
    };

    ///////////////////////////////////////////////////////////////////

    class WriterGuard
    {
    public:

        WriterGuard(ReaderWriterGuard& rwguard)
            : _rwguard(rwguard)
        {
            _rwguard.upgrade();
        }

        ~WriterGuard()
        {
            _rwguard.downgrade();
        }

        operator ReaderWriterGuard& ()
        {
            return _rwguard;
        }

    private:

        ReaderWriterGuard& _rwguard;
    };
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
// Thread                                                            //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class Thread
{
public:

    Thread()
        : _thread(0)
        , _thread_valid(false)
    {
        errno = pthread_attr_init(&_attr);
        if (errno != 0)
        {
            LOGGER_PERROR("pthread_attr_init");
            return;
        }

        errno = pthread_attr_setinheritsched(&_attr, PTHREAD_INHERIT_SCHED);
        if (errno != 0)
            LOGGER_PWARN("pthread_attr_setinheritsched");
    }

    virtual ~Thread()
    {
        (void) pthread_attr_destroy(&_attr);

        (void) cancel();
    }

    int priority() const
    {
        struct sched_param sched;
        errno = pthread_attr_getschedparam(&_attr, &sched);
        if (errno != 0)
        {
            LOGGER_PWARN("pthread_attr_getschedparam");
            return -1;
        }
        return sched.sched_priority;
    }

    int priority(int prio)
    {
        int policy;
        errno = pthread_attr_getschedpolicy(&_attr, &policy);
        if (errno != 0)
        {
            LOGGER_PWARN("pthread_attr_getschedpolicy");
            return -1;
        }

        int prio_min = sched_get_priority_min(policy);
        if (errno != 0)
        {
            LOGGER_PWARN("sched_get_priority_min");
            return -1;
        }

        int prio_max = sched_get_priority_max(policy);
        if (errno != 0)
        {
            LOGGER_PWARN("sched_get_priority_max");
            return -1;
        }

        if (prio < prio_min)
            prio = prio_min;
        else if (prio > prio_max)
            prio = prio_max;

        struct sched_param sched = { prio };
        errno = pthread_attr_setschedparam(&_attr, &sched);
        if (errno != 0)
        {
            LOGGER_PWARN("pthread_attr_setschedparam(%d)", sched.sched_priority);
            return -1;
        }

#ifdef LOGGER_OSTREAM
        if (LOGGER_IS_DEBUG())
        {
            LOGGER_ODEBUG(cdbg) << "scheduling policy ";
            switch (policy)
            {
            case SCHED_OTHER:   cdbg << "SCHED_OTHER"; break;
#  ifdef SCHED_BATCH
            case SCHED_BATCH:   cdbg << "SCHED_BATCH"; break;
#  endif
#  ifdef SCHED_IDLE
            case SCHED_IDLE:    cdbg << "SCHED_IDLE"; break;
#  endif
            case SCHED_FIFO:    cdbg << "SCHED_FIFO"; break;
            case SCHED_RR:      cdbg << "SCHED_RR"; break;
            default:            cdbg << policy; break;
            }
            cdbg << ". scheduling priority = " << sched.sched_priority
                 << " [" << prio_min << '/' << prio_max << ']';
        }
#endif

        return 0;
    }

    int schedpolicy() const
    {
        int policy;
        errno = pthread_attr_getschedpolicy(&_attr, &policy);
        if (errno != 0)
        {
            LOGGER_PWARN("pthread_attr_getschedpolicy");
            return -1;
        }
#ifdef LOGGER_OSTREAM
        if (LOGGER_IS_DEBUG())
        {
            LOGGER_ODEBUG(cdbg) << "scheduling policy ";
            switch (policy)
            {
            case SCHED_OTHER:   cdbg << "SCHED_OTHER"; break;
#  ifdef SCHED_BATCH
            case SCHED_BATCH:   cdbg << "SCHED_BATCH"; break;
#  endif
#  ifdef SCHED_IDLE
            case SCHED_IDLE:    cdbg << "SCHED_IDLE"; break;
#  endif
            case SCHED_FIFO:    cdbg << "SCHED_FIFO"; break;
            case SCHED_RR:      cdbg << "SCHED_RR"; break;
            default:            cdbg << policy; break;
            }
        }
#endif
        return policy;
    }

    int priority_min() const
    {
        int policy;
        errno = pthread_attr_getschedpolicy(&_attr, &policy);
        if (errno != 0)
        {
            LOGGER_PWARN("pthread_attr_getschedpolicy");
            return -1;
        }
        return sched_get_priority_min(policy);
    }

    int priority_max() const
    {
        int policy;
        errno = pthread_attr_getschedpolicy(&_attr, &policy);
        if (errno != 0)
        {
            LOGGER_PWARN("pthread_attr_getschedpolicy");
            return -1;
        }
        return sched_get_priority_max(policy);
    }

    ssize_t stacksize() const
    {
        size_t stacksize;
        errno = pthread_attr_getstacksize(&_attr, &stacksize);
        if (errno != 0)
        {
            LOGGER_PERROR("pthread_attr_getstacksize");
            return -1;
        }
        return (ssize_t) stacksize;
    }

    int stacksize(size_t stacksize)
    {
        if (stacksize < PTHREAD_STACK_MIN)
            stacksize = PTHREAD_STACK_MIN;
        stacksize = round_up(stacksize, getpagesize());

        errno = pthread_attr_setstacksize(&_attr, stacksize);
        if (errno != 0)
        {
            LOGGER_PERROR("pthread_attr_setstacksize(%zd)", stacksize);
            return -1;
        }
        LOGGER_DEBUG("pthread_attr_setstacksize = %.0biB", (float) stacksize);
        return 0;
    }

    bool running() const
    {
        return _thread_valid && pthread_kill(_thread, 0) != ESRCH;
    }

    virtual int start()
    {
        if (running())
        {
            LOGGER_ERROR("already running");
            return EEXIST;
        }

        errno = pthread_create(&_thread, &_attr, start_routine, this);
        if (errno != 0)
        {
            LOGGER_PERROR("pthread_create");
            return -1;
        }
        _thread_valid = true;

        return 0;
    }

    int cancel()
    {
        if (! running())
            return 0;

        errno = pthread_cancel(_thread);
        if (errno != 0)
        {
            LOGGER_PERROR("pthread_cancel");
            return -1;
        }

        return 0;
    }

    int join()
    {
        if (! running())
            return 0;

        errno = pthread_join(_thread, NULL);
        if (errno != 0)
        {
            LOGGER_PERROR("pthread_join");
            return -1;
        }

        return 0;
    }

    static void testcancel()
    {
        int oldstate;
        errno = pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, &oldstate);
        if (errno != 0)
            LOGGER_PWARN("pthread_setcancelstate(PTHREAD_CANCEL_ENABLE)");

        pthread_testcancel();

        errno = pthread_setcancelstate(oldstate, NULL);
        if (errno != 0)
            LOGGER_PWARN("pthread_setcancelstate(%d)", oldstate);
    }

protected:

    virtual void run() =0;

    unsigned int sleep(int secs)
    {
        // sleep(3) uses SIGALRM

        struct timeval timeout = { secs, 0 };
        if (::select(0, NULL, NULL, NULL, &timeout) == -1)
        {
            LOGGER_PERROR("select");
            return timeout.tv_sec == 0 ? 1 : timeout.tv_sec;
        }
        return 0;
    }

    unsigned int usleep(useconds_t usecs)
    {
        // sleep(3) uses SIGALRM

        struct timeval timeout;
        timeout.tv_sec = usecs / (useconds_t)1000000;
        timeout.tv_usec = usecs % (useconds_t)1000000;
        if (::select(0, NULL, NULL, NULL, &timeout) == -1)
        {
            LOGGER_PERROR("select");
            return timeout.tv_sec * 1000000 + timeout.tv_usec;
        }
        return 0;
    }


private:

    static inline int round_up(int x, int n)
    {
        return ((x + n - 1) / n) * n;
    }

    static void* start_routine(void* arg)
    {
        Thread* that = reinterpret_cast<Thread*>(arg);

        if (LOGGER_IS_DEBUG())
        {
            LOGGER_DEBUG("thread started");

            pthread_cleanup_push(cleanup_routine, NULL);

                that->run();

            pthread_cleanup_pop(1);
        }
        else
        {
            that->run();
        }

        return NULL;
    }

    static void cleanup_routine(void* arg)
    {
        LOGGER_DEBUG("thread finished");
    }

private:

    pthread_t _thread;
    bool _thread_valid;
    pthread_attr_t _attr;
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
// TimerTask                                                         //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class TimerTask
    : public Thread
{
public:

    TimerTask(unsigned periodSec)
        : _delay(0)
        , _period(periodSec)
    {}

    TimerTask(unsigned initialDelaySec, unsigned periodSec)
        : _delay(initialDelaySec)
        , _period(periodSec)
    {}

protected:

    virtual void run()
    {
        if (_delay > 0)
            sleep(_delay);

        for (;;)
        {
            errno = pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, NULL);
            if (errno != 0)
                LOGGER_PWARN("pthread_setcancelstate(PTHREAD_CANCEL_DISABLE)");

            execute();

            errno = pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
            if (errno != 0)
                LOGGER_PWARN("pthread_setcancelstate(PTHREAD_CANCEL_ENABLE)");

            if (_period == 0)
                break;

            sleep(_period);
        }
    }

    virtual void execute() =0;

private:

    const unsigned _delay;
    const unsigned _period;
};

///////////////////////////////////////////////////////////////////////
//                                                                   //
// MilliTimerTask                                                    //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class MilliTimerTask
    : public Thread
{
public:

    MilliTimerTask(unsigned periodMilliSec)
        : _delay(0)
        , _period(periodMilliSec)
    {}

    MilliTimerTask(unsigned initialDelayMilliSec, unsigned periodMilliSec)
        : _delay(initialDelayMilliSec * (useconds_t)1000)
        , _period(periodMilliSec * (useconds_t)1000)
    {}

protected:

    virtual void run()
    {
        if (_delay > 0)
            usleep(_delay);

        if (_period == 0)
        {
            execute();
            return;
        }

        for (;;)
        {
            execute();

            usleep(_period);
        }
    }

    virtual void execute() =0;

private:

    const useconds_t _delay;
    const useconds_t _period;
};

#endif
