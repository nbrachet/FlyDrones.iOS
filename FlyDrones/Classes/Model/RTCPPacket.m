//
//  RTCPPacket.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/25/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "RTCPPacket.h"

#define RTCP_V(v)	((v >> 30) & 0x03) // rtcp version
#define RTCP_P(v)	((v >> 29) & 0x01) // rtcp padding
#define RTCP_RC(v)	((v >> 24) & 0x1F) // rtcp reception report count
#define RTCP_PT(v)	((v >> 16) & 0xFF) // rtcp packet type
#define RTCP_LEN(v)	(v & 0xFFFF) // rtcp packet length

typedef struct _rtcp_header_t
{
    uint32_t v:2;		// version
    uint32_t p:1;		// padding
    uint32_t rc:5;		// reception report count
    uint32_t pt:8;		// packet type
    uint32_t length:16; /* pkt len in words, w/o this word */
} rtcp_header_t;

@implementation RTCPPacket

@end
