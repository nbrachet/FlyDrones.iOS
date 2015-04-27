//
//  NSData+RTCP.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/27/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "NSData+RTCP.h"

@implementation NSData (RTCP)

+ (NSData *)RTCPDataWithVersion:(NSUInteger)version packetType:(RTCPPacketType)packetType {
    struct RTCPPacket packet;
    memset(&packet, 0, sizeof(packet));
    packet.version = version;
    packet.pt = packetType;
    packet.length = sizeof(struct RTCPPacket);
    return [NSData dataWithBytes:&packet length:sizeof(packet)];
}

@end
