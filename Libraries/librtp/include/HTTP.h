
#ifndef _HTTP_H_
#define _HTTP_H_

#include <ctype.h>
#include <string.h>
#include "TCP.h"
#include "Net.h"

///////////////////////////////////////////////////////////////////////
//                                                                   //
//                               HTTP                                //
//                                                                   //
///////////////////////////////////////////////////////////////////////

class HTTPConnection
    : public TCPConnection
{
protected:

    friend class HTTPServer;

    HTTPConnection(int sockfd,
                   const sockaddr_in* peeraddr)
        : TCPConnection(sockfd, peeraddr)
        , _query(NULL)
        , _method(NULL)
        , _url(NULL)
        , _protocol(NULL)
        , _headers(NULL)
    {}

    virtual ~HTTPConnection()
    {
        if (_query) free(_query);
        if (_method) free(_method);
        if (_url) free(_url);
        if (_protocol) free(_protocol);
    }

public:

    ssize_t recv(void* buffer, size_t buflen,
                 int flags,
                 struct timeval* timeout = NULL)
    {
        const ssize_t n = TCPConnection::recv(buffer, buflen - 1, flags, timeout);
        if (n <= 0)
            return n;

        *((char*)buffer + n) = '\0';

        LOGGER_DEBUG("< %*s", n, buffer);

        return n;
    }

    int handle()
    {
        ssize_t query = parse_query();
        if (query <= 0)
            return query;

        if (handle_protocol() == -1)
            return -1;

        if (handle_method() == -1)
            return -1;

        return 1;
    }

    int scan_header(const char* name,
                    const char* fmt,
                    ...)
        __attribute__((__format__(__scanf__, 3, 4)))
    {
        const size_t len = strlen(name);
        for (const char* p = _headers; ; )
        {
            const char* eol = strstr(p, "\r\n");
            if (eol == NULL)
                break;

            if (eol - p > len
                && strncmp(p, name, len) == 0
                && p[len] == ':')
            {
                // bingo!

                p += len + 1;

                // skip spaces
                while (*p && isspace(*p))
                    ++p;

                va_list ap;
                va_start(ap, fmt);
                int s = vsscanf(p, fmt, ap);
                va_end(ap);
                return s;
            }

            p = eol + 2;
        }
        return 0;
    }

protected:

    int parse_query()
    {
        if (_query) { free(_query); _query = NULL; };
        if (_method) { free(_method); _method = NULL; };
        if (_url) { free(_url); _url = NULL; };
        if (_protocol) { free(_protocol); _protocol = NULL; };

        ssize_t recv = recv_until((void**)&_query, 0, 0, "\r\n\r\n", 4);
        if (recv <= 0)
            return recv;

        int headers = 0;
        if (sscanf(_query,
                   "%as%*[ \t]%as%*[ \t]%as\r\n%n",
                   &_method,
                   &_url,
                   &_protocol,
                   &headers) != 3
            || headers == 0)
        {
            LOGGER_ERROR("parse_query: %*s", (int)recv, _query);
            free(_query); _query = NULL;
            return 0;
        }

        _headers = _query + headers;

        return 4;
    }

    virtual int handle_protocol()
    {
        if (strcmp(_protocol, "HTTP/1.0") != 0)
        {
            error_505();
            return -1;
        }
        return 0;
    }

    virtual int handle_method()
    {
        if (strcmp(_method, "GET") == 0)
            return do_get();
        if (strcmp(_method, "POST") == 0)
            return do_post();
        // etc...

        error_405();

        return -1;
    }

    virtual int do_get()
    {
        return error_405();
    }

    virtual int do_post()
    {
        return error_405();
    }

    int error_405()
    {
        LOGGER_WARN("%s: method not allowed!", _method);
        return error(405, "Method Not Allowed");
    }

    int error_500()
    {
        return error(500, "Internal Server Error");
    }

    int error_503()
    {
        return error(503, "Service Unavailable");
    }

    int error_505()
    {
        LOGGER_WARN("%s: invalid protocol!", _protocol);
        return error(505, "Protcol Not Supported");
    }

    int error(int code, const char* fmt, ...)
        __attribute__((__format__(__printf__, 3, 4)))
    {
        va_list ap;
        va_start(ap, fmt);
        ssize_t sent = sendva(MSG_MORE, fmt, ap);
        va_end(ap);
        if (sent == -1)
            return -1;

        ssize_t n = send_extra_headers(MSG_MORE);
        if (n == -1)
            return -1;
        sent += n;

        n = sendv(0, "\r\n\r\n");
        if (n == -1)
            return -1;
        return sent + n;
    }

    int sendv_200(int flags, const char* fmt, ...)
        __attribute__((__format__(__printf__, 3, 4)))
    {
        ssize_t sent = sendv(flags | MSG_MORE, "%s 200\r\n", _protocol);
        if (sent == -1)
            return -1;

        ssize_t n = send_extra_headers(flags | MSG_MORE);
        if (n == -1)
            return -1;
        sent += n;

        if (! BITMASK_ISSET(flags, MSG_MORE))
        {
            n = sendv(MSG_MORE, "Content-Length: 0\r\n");
            if (n == -1)
                return -1;
            sent += n;
        }

        if (fmt != NULL && *fmt != '\0')
        {
            va_list ap;
            va_start(ap, fmt);
            n = sendva(flags | MSG_MORE, fmt, ap);
            va_end(ap);
            if (n == -1)
                return -1;
            sent += n;
        }

        n = sendv(flags, "\r\n");
        if (n == -1)
            return -1;
        return sent + n;
    }

    virtual int send_extra_headers(int flags)
    {
        return 0;
    }

protected:

    char* _query;
    char* _method;
    char* _url;
    char* _protocol;
    const char* _headers;
};

///////////////////////////////////////////////////////////////////////

class HTTPServer
    : public TCPServer
{
public:

    HTTPServer()
        : TCPServer()
    {}

    HTTPConnection* accept()
    {
        return reinterpret_cast<HTTPConnection*>(TCPServer::accept());
    }

protected:

    virtual TCPConnection* newConnection(int sockfd, const struct sockaddr_in* peeraddr) const
    {
        return new HTTPConnection(sockfd, peeraddr);
    }
};

#endif
