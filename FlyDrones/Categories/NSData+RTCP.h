//
//  NSData+RTCP.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/27/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RTCPPacket.h"

@interface NSData (RTCP)

+ (NSData *)RTCPDataWithVersion:(NSUInteger)version packetType:(RTCPPacketType)packetType;

@end
