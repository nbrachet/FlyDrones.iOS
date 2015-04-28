//
//  RTCPPacket.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/25/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//


typedef NS_ENUM(NSUInteger, RTCPPacketType) {
    RTCPPacketTypeSR = 200,         // Sender Report 
    RTCPPacketTypeRR = 201,         // Receiver Report
    RTCPPacketTypeSDES = 202,       // Source Description 
    RTCPPacketTypeBYE = 203,        // Goodbye 
    RTCPPacketTypeAPP = 204         // Application-Defined 
};

struct RRItem {
    uint32_t ssrc;              // data source being reported 

#ifdef __BIG_ENDIAN__
    unsigned int fraction:8;    // fraction lost since last SR/RR 
    int lost:24;                // cumul. no. pkts lost (signed!) 
#else
    int lost:24;                // cumul. no. pkts lost (signed!) 
    unsigned int fraction:8;    // fraction lost since last SR/RR 
#endif

    uint32_t last_seq;          // extended last seq. no. received 
    uint32_t jitter;            // interarrival jitter 
    uint32_t lsr;               // last SR packet from this source 
    uint32_t dlsr;              // delay since last SR packet  
};

struct RTCPPacket {
    //Header
#ifdef __BIG_ENDIAN__
    uint32_t version:2;         // protocol version
    uint32_t padding:1;         // padding flag
    uint32_t count:5;           // varies by packet type
#else
    uint32_t count:5;           // varies by packet type
    uint32_t padding:1;         // padding flag
    uint32_t version:2;         // protocol version
#endif
    
    uint32_t pt:8;              // RTCP packet type
    uint32_t length:16;

    //Data
    uint32_t ssrc;              // receiver generating this report
    struct RRItem items[0];     // variable-length list 
};
