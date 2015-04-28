//
//  NSData+RTCP.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/27/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "NSData+RTCP.h"

@implementation NSData (RTCP)

+ (NSData *)RTCPDataWithVersion:(uint32_t)version packetType:(RTCPPacketType)packetType {
    struct RTCPPacket packet;
    memset(&packet, 0, sizeof(packet));
    packet.version = version;
    packet.pt = packetType;
    packet.length = CFSwapInt16HostToBig(sizeof(struct RTCPPacket));
    NSData *data = [NSData dataWithBytes:&packet length:sizeof(packet)];
    return data;
}

- (NSString *)hexadecimalString {
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    
    if (!dataBuffer) {
        return [NSString string];
    }
    
    NSUInteger dataLength  = [self length];
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendFormat:@"%02x", (unsigned int)dataBuffer[i]];
        [hexString appendString:@" "];
    }
    
    return [NSString stringWithString:hexString];
}
@end
