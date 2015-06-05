
#ifndef _UML295_H_
#define _UML295_H_

#include "TCP.h"

class UML295Stats
{
public:

    UML295Stats()
        : _condata(NULL)
        , _gps(NULL)
    {}

    ~UML295Stats()
    {
        if (_condata)
            free(_condata);
        if (_gps)
            free(_gps);
    }

    int snapshot(const char* interface = NULL)
    {
        if (condata(interface) == -1 || gps(interface) == -1)
            return -1;

        return 0;
    }

    static bool is_running()
    {
        struct ifaddrs* ifa;
        if (getifaddrs(&ifa) == -1)
        {
            LOGGER_PERROR("getifaddrs");
            return false;
        }

        for (struct ifaddrs* p = ifa; p; p = p->ifa_next)
        {
            if (is_uml295(p))
            {
                LOGGER_DEBUG("Interface %s is up", p->ifa_name);
                freeifaddrs(ifa);
                return true;
            }
        }

        freeifaddrs(ifa);
        return false;
    }

    static bool is_uml295(const struct ifaddrs* ifa)
    {
        if (BITMASK_ISSET(ifa->ifa_flags, IFF_LOOPBACK))
            return false;
        if (! BITMASK_ARESET(ifa->ifa_flags, IFF_UP | IFF_RUNNING))
            return false;
        if (ifa->ifa_addr == NULL || ifa->ifa_addr->sa_family != AF_INET)
            return false;

        INet::Addr addr(reinterpret_cast<struct sockaddr_in*>(ifa->ifa_addr)->sin_addr);
        return addr.matches(MBB_VZW_NET);
    }

    static int is_connected(const struct ifaddrs* ifa)
    {
        UML295Stats stats;
        if (stats.condata(ifa->ifa_name) == -1)
            return -1;

        return (strcmp(stats.state, "connected") == 0
                    || strcmp(stats.state, "dormant") == 0)
                && strcmp(stats.ip4, "0.0.0.0") != 0;
    }

private:

    int condata(const char* interface = NULL);

    int gps(const char* interface = NULL);

    static void* get(const char* url, const char* interface = NULL);

    static char* parse_time(time_t* var, char* buf);

    static char* parsef(char* buf,
                        const char* start_token,
                        size_t start_token_len,
                        const char* end_token,
                        size_t end_token_len,
                        const char* format,
                        ...);

    static char* parse_string(const char** var,
                              char* buf,
                              const char* start_token,
                              size_t start_token_len,
                              const char* end_token,
                              size_t end_token_len);

    static const char* strestr(const char* haystack, const char* needle);

public:

    // condata

    const char* time;
    const char* id;
    const char* power;
    const char* state;
    const char* bars;
    const char* rssi;
    const char* snr;
    const char* netname;
    const char* nettype;
    const char* netencr;
    const char* netid;
    const char* ip4;
    const char* gw4;
    const char* dns4;
    const char* dhcp4;
    long rx_bytes;
    long rx_pkts;
    long rx_byterate;
    long rx_errors;
    long rx_discards;
    long tx_bytes;
    long tx_pkts;
    long tx_byterate;
    long tx_errors;
    long tx_discards;
    const char* uptime;
    const char* activation;

    // gps

    const char* gps_time;
    const char* gps_state;
    float latitude;
    float longitude;
    float altitude; // meters
    float speed; // km/h
    int sats;
    float hepe;

private:

    void* _condata;
    void* _gps;

    const char* hepe_s;

private:

    static const INet::SockAddr MBB_VZW_COM;
    static const INet::Addr MBB_VZW_NET;
};

#endif
