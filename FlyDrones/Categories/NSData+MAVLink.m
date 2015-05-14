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

+ (NSData *)dataWithManualControlsPitch:(int16_t)pitch  //forward(1000)/backward(-1000)
                                   roll:(int16_t)roll   //left(-1000)/right(1000)
                                 thrust:(int16_t)thrust //slider movement with maximum being 1000 and minimum being -1000
                                    yaw:(int16_t)yaw    //twisting of the joystick, with counter-clockwise being 1000 and clockwise being -1000,
                         sequenceNumber:(uint16_t)sequenceNumber {

    uint8_t sysid = 20;                   ///< ID 20 for this airplane
    uint8_t compid = MAV_COMP_ID_IMU;     ///< The component sending the message is the IMU, it could be also a Linux process
    
    mavlink_message_t message;
    mavlink_msg_manual_control_pack(sysid, compid, &message, MAV_TYPE_QUADROTOR, pitch, roll, thrust, yaw, sequenceNumber);
    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
    uint16_t bufferLength = mavlink_msg_to_send_buffer(buffer, &message);
    NSLog(@"%@", [NSString stringWithMAVLinkMessage:&message]);
    NSData *messageData = [NSData dataWithBytes:buffer length:bufferLength];
    return messageData;
}

@end
