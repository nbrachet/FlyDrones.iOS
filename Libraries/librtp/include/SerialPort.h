
#ifndef _SERIAL_PORT_H_
#define _SERIAL_PORT_H_

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
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

    static speed_t parseSpeed(int speed)
    {
        switch (speed)
        {
        case 0:         return B0;
        case 50:        return B50;
        case 75:        return B75;
        case 110:       return B110;
        case 134:       return B134;
        case 150:       return B150;
        case 200:       return B200;
        case 300:       return B300;
        case 600:       return B600;
        case 1200:      return B1200;
        case 1800:      return B1800;
        case 2400:      return B2400;
        case 4800:      return B4800;
#ifdef B7200
        case 7200:      return B7200;
#endif
        case 9600:      return B9600;
#ifdef B14400
        case 14400:     return B14400;
#endif
        case 19200:     return B19200;
#ifdef B28800
        case 28800:     return B28800;
#endif
        case 38400:     return B38400;
        case 57600:     return B57600;
#ifdef B76800
        case 76800:     return B76800;
#endif
        case 115200:    return B115200;
        case 230400:    return B230400;
#ifdef B460800
        case 460800:    return B460800;
#endif
#ifdef B500000
        case 500000:    return B500000;
#endif
#ifdef B576000
        case 576000:    return B576000;
#endif
#ifdef B921600
        case 921600:    return B921600;
#endif
#ifdef B1000000
        case 1000000:   return B1000000;
#endif
#ifdef B1152000
        case 1152000:   return B1152000;
#endif
#ifdef B1500000
        case 1500000:   return B1500000;
#endif
#ifdef B2000000
        case 2000000:   return B2000000;
#endif
#ifdef B2500000
        case 2500000:   return B2500000;
#endif
#ifdef B3000000
        case 3000000:   return B3000000;
#endif
#ifdef B3500000
        case 3500000:   return B3500000;
#endif
#ifdef B4000000
        case 4000000:   return B4000000;
#endif
        default:        return -1;
        }
    }

    static speed_t parseSpeed(const char* speed)
    {
        return parseSpeed(atoi(speed));
    }

    // put the port in raw mode, no flow-control (hard or soft)
    int configure(speed_t baud, char data_bits, char parity_bits, char stop_bits)
    {
        if (! isatty() || baud == B0)
            return 0;

#ifndef NDEBUG
        switch (baud)
        {
        case B0:
        case B50:
        case B75:
        case B110:
        case B134:
        case B150:
        case B200:
        case B300:
        case B600:
        case B1200:
        case B1800:
        case B2400:
        case B4800:
        case B9600:
        case B19200:
        case B38400:
        case B57600:
        case B115200:
        case B230400:
            break;
        default:
            LOGGER_ASSERT1(! "Invalid baud: ", baud);
        }
#endif

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

        // data bits
        switch (data_bits)
        {
        case 5:
            BITMASK_CLEAR(termios.c_cflag, CSIZE);
            BITMASK_SET(termios.c_cflag, CS5);
            break;

        case 6:
            BITMASK_CLEAR(termios.c_cflag, CSIZE);
            BITMASK_SET(termios.c_cflag, CS6);
            break;

        case 7:
            BITMASK_CLEAR(termios.c_cflag, CSIZE);
            BITMASK_SET(termios.c_cflag, CS7);
            break;

        case 8:
            BITMASK_CLEAR(termios.c_cflag, CSIZE);
            BITMASK_SET(termios.c_cflag, CS8);
            break;
        }

        // parity bits
        switch (parity_bits)
        {
        case 'O': case 'o': // odd
            BITMASK_SET(termios.c_cflag, PARENB);
            BITMASK_SET(termios.c_cflag, PARODD);
            break;

        case 'E': case 'e': // even
            BITMASK_SET(termios.c_cflag, PARENB);
            BITMASK_CLEAR(termios.c_cflag, PARODD);
            break;

        case 'N': case 'n': // none
            BITMASK_CLEAR(termios.c_cflag, PARENB);
            break;
        }

        // stop bits
        if (stop_bits == 1)
            BITMASK_CLEAR(termios.c_cflag, CSTOPB);
        else if (stop_bits == 2)
            BITMASK_SET(termios.c_cflag, CSTOPB);

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
