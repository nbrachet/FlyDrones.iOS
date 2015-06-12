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

- (NSArray *)componentsSeparatedByByte:(Byte)byte {
    unsigned long len, index, last_sep_index;
    NSData *line;
    NSMutableArray *lines = nil;
    
    len = [self length];
    Byte buffer[len];
    
    [self getBytes:buffer length:len];
    
    index = last_sep_index = 0;
    
    lines = [[NSMutableArray alloc] init];
    
    do {
        if (buffer[index] == byte) {
            NSRange startEndRange = NSMakeRange(last_sep_index, index - last_sep_index);
            line = [self subdataWithRange:startEndRange];
            
            [lines addObject:line];
            
            last_sep_index = index + 1;
            
            continue;
        }
    } while (index++ < len);
    return lines;
}

@end
