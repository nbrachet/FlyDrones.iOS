
#ifndef _SERIAL_PORT_H_
#define _SERIAL_PORT_H_

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>

#include "Net.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                            SerialPort                             //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class SerialPort
    : public Socket
{
public:

    SerialPort()
        : Socket()
    {}

    explicit SerialPort(int fd)
        : Socket(fd)
    {}

    int open(const char* dev, int flags)
    {
        LOGGER_ASSERT(_sockfd == -1);

        // clear every flags except for O_RDWR, O_NONBLOCK and O_CLOEXEC
        BITMASK_MASK(flags, O_RDONLY | O_WRONLY | O_RDWR | O_NONBLOCK | O_CLOEXEC);

        BITMASK_SET(flags, O_NOCTTY);

        int fd = ::open(dev, flags);
        if (fd == -1)
        {
            LOGGER_PERROR("open(%s)", dev);
            return -1;
        }

        return open(fd);
    }

    int open(int fd)
    {
        LOGGER_ASSERT(_sockfd == -1);

        _sockfd = fd;

        if (_sockfd > STDERR_FILENO && isatty())
        {
            if (ioctl(_sockfd, TIOCEXCL) == -1)
                LOGGER_PWARN("ioctl(TIOCEXCL)");

            if (tcgetattr(_sockfd, &_termios0) < 0)
            {
                int saved_errno = errno;
                LOGGER_PERROR("tcgetattr");
                (void) close();
                errno = saved_errno;
                return -1;
            }
        }

        return 0;
    }

    virtual int close()
    {
        if (_sockfd == -1)
            return 0;

        if (_sockfd > STDERR_FILENO && isatty())
        {
            if (tcsetattr(_sockfd, TCSANOW, &_termios0) != -1)
                (void) usleep(100000);

            if (ioctl(_sockfd, TIOCNXCL) == -1)
                LOGGER_PWARN("ioctl(TIOCNXCL)");
        }

        return Socket::close();
    }

    bool isatty()
    {
        return ::isatty(_sockfd);
    }

    // put the port in raw mode, no flow-control (hard or soft)
    int configure_8n1(speed_t baud)
    {
        if (! isatty())
            return 0;

        struct termios termios;
        memcpy(&termios, &_termios0, sizeof(struct termios));

        // raw
        cfmakeraw(&termios);

        // baud rate
        if (cfsetspeed(&termios, baud) == -1)
        {
            LOGGER_PERROR("cfsetspeed(%u)", (unsigned) baud);
            return -1;
        }

        // 8N1
        BITMASK_CLEAR(termios.c_cflag, CSIZE);
        BITMASK_SET(termios.c_cflag, CS8);
        BITMASK_CLEAR(termios.c_cflag, PARENB | CSTOPB);

        // no flow control
        BITMASK_CLEAR(termios.c_cflag, CRTSCTS);
#ifdef MDMBUF
        BITMASK_CLEAR(termios.c_cflag, MDMBUF);
#endif
#if defined(CDSR_OFLOW) && defined(CDSR_IFLOW)
        BITMASK_CLEAR(termios.c_cflag, CDSR_OFLOW | CDTR_IFLOW);
#endif
        BITMASK_CLEAR(termios.c_iflag, IXON | IXOFF);

        // enable
        BITMASK_SET(termios.c_cflag, CREAD | CLOCAL);

        // 1 char enough for a read, no timeout
        termios.c_cc[VMIN] = 1;
        termios.c_cc[VTIME] = 0;

        // flush I/O buffers

#ifdef __APPLE__
        // Don't issue TCIFLUSH: it hangs the PL2303 driver (on OSX)
        if (tcflush(TCOFLUSH) == -1)
        {
            LOGGER_PERROR("tcflush(TCOFLUSH)");
            return -1;
        }
#else
        if (tcflush(TCIOFLUSH) == -1)
        {
            LOGGER_PERROR("tcflush(TCIOFLUSH)");
            return -1;
        }
#endif

        // commit

        if (memcmp(&termios, &_termios0, sizeof(struct termios)) != 0)
        {
            if (tcsetattr(_sockfd, TCSANOW, &termios) == -1)
            {
                LOGGER_PERROR("tcsetattr(TCSANOW)");
                return -1;
            }

//            (void) usleep(100000);

            // flush input (which may have arrived between
            // the previous flush and tcsetattr())

#ifndef __APPLE__
            // Don't issue TCIFLUSH: it hangs the PL2303 driver (on OSX)
            (void) tcflush(TCIFLUSH);
#endif
        }

        return 0;
    }

    int tcflush(int queue_selector)
    {
        if (! isatty())
            return 0;
        if (::tcflush(_sockfd, queue_selector) == -1)
        {
            LOGGER_PERROR("tcflush");
            return -1;
        }
        return 0;
    }

    virtual ssize_t /*Socket::*/ writev(struct iovec* iov, unsigned iovcnt,
                                        struct timeval* timeout = NULL)
    {
        const ssize_t n = Socket::writev(iov, iovcnt, timeout);
        if (n > 0 && isatty())
        {
            if (tcdrain(_sockfd) != 0)
                LOGGER_PWARN("tcdrain");
        }
        return n;
    }

private:

    struct termios _termios0;
};

#endif
