//
//  NSData+RTCP.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/27/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "RTCPPacket.h"

@interface NSData (RTCP)

+ (NSData *)RTCPDataWithVersion:(uint32_t)version packetType:(RTCPPacketType)packetType;

- (NSString *)hexadecimalString;

- (NSArray *)componentsSeparatedByByte:(Byte)byte;

@end
