//
//  NSData+MAVLink.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/14/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "NSData+MAVLink.h"
#import "NSString+MAVLink.h"

@implementation NSData (MAVLink)

+ (NSData *)dataWithMAVLinkMessage:(mavlink_message_t *)message {
    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
    uint16_t bufferLength = mavlink_msg_to_send_buffer(buffer, message);
    if (!buffer || bufferLength == 0) {
        return nil;
    }
    NSData *data = [NSData dataWithBytes:buffer length:bufferLength];
    return data;
}

@end
