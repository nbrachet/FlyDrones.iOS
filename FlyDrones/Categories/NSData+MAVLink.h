//
//  NSData+MAVLink.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/14/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (MAVLink)

+ (NSData *)dataWithManualControlsPitch:(int16_t)pitch
                                   roll:(int16_t)roll
                                 thrust:(int16_t)thrust
                                    yaw:(int16_t)yaw
                         sequenceNumber:(uint16_t)sequenceNumber;

@end
