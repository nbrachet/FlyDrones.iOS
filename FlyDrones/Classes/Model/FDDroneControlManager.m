//
//  FDDroneControlManager.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/29/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDDroneControlManager.h"
#import "FDFileReader.h"
#import "NSString+MAVLink.h"

@interface FDDroneControlManager () {
    mavlink_message_t msg;
    mavlink_status_t status;
}

@end

@implementation FDDroneControlManager

#pragma mark - Public

- (void)parseLogFile:(NSString *)name ofType:(NSString *)type {
    if (name.length == 0) {
        return;
    }
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:name ofType:type];
    if (filePath.length == 0) {
        return;
    }
    
    FDFileReader *fileReader = [[FDFileReader alloc] initWithFilePath:filePath];
    [fileReader asyncEnumerateBytesUsingBlock:^(NSData *data, BOOL *stop) {
        if (data.length == 0) {
            *stop = YES;
            return;
        }
        
        const char *bytes = (const char *) [data bytes];
        BOOL isMessageDetected = [self parseMessageChar:bytes[0]];
        if (isMessageDetected) {
            sleep(1);
        }
    }];
}

- (BOOL)parseMessageChar:(uint8_t)messageChar {
    if (mavlink_parse_char(MAVLINK_COMM_0, messageChar, &msg, &status)) {
//      NSLog(@"%@", [NSString stringWithMAVLinkMessage:&msg]);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(droneControlManager:didParseMessage:)]) {
                [self.delegate droneControlManager:self didParseMessage:[NSString stringWithMAVLinkMessage:&msg]];
            }
            [self handleMessage:&msg];
        });
        return YES;
    }
    return NO;
}

- (void)handleMessage:(mavlink_message_t *)message {
    if (self.delegate == nil) {
        return;
    }
    switch (message->msgid) {
        case MAVLINK_MSG_ID_BATTERY_STATUS: {
            NSLog(@"MAVLINK_MSG_ID_BATTERY_STATUS");
            if (![self.delegate respondsToSelector:@selector(droneControlManager:didHandleBatteryStatus:)]) {
                return;
            }
            NSUInteger batteryRemaining = mavlink_msg_battery_status_get_battery_remaining(message);
            [self.delegate droneControlManager:self didHandleBatteryStatus:batteryRemaining];
            break;
        }
        case MAVLINK_MSG_ID_GPS_RAW_INT: {
            NSLog(@"MAVLINK_MSG_ID_GPS_RAW_INT");
            if (![self.delegate respondsToSelector:@selector(droneControlManager:didHandleLocationCoordinate:)]) {
                return;
            }
            mavlink_gps_raw_int_t gpsRawIntPkt;
            mavlink_msg_gps_raw_int_decode(message, &gpsRawIntPkt);
            CLLocationCoordinate2D locationCoordinate = CLLocationCoordinate2DMake(gpsRawIntPkt.lat/10000000.0f,
                                                                                   gpsRawIntPkt.lon/10000000.0f);
            [self.delegate droneControlManager:self didHandleLocationCoordinate:locationCoordinate];
            break;
        }
        case MAVLINK_MSG_ID_VFR_HUD: {
            NSLog(@"MAVLINK_MSG_ID_VFR_HUD");
            mavlink_vfr_hud_t  vfrHudPkt;
            mavlink_msg_vfr_hud_decode(message, &vfrHudPkt);
            
            
            break;
        }
//
//        case MAVLINK_MSG_ID_HEARTBEAT:
//            NSLog(@"MAVLINK_MSG_ID_HEARTBEAT");
//            break;
//        case MAVLINK_MSG_ID_RADIO_STATUS:
//            NSLog(@"MAVLINK_MSG_ID_RADIO_STATUS");
//            break;
//        case MAVLINK_MSG_ID_RADIO:
//            NSLog(@"MAVLINK_MSG_ID_RADIO");
//            break;
//        case MAVLINK_MSG_ID_STATUSTEXT:
//            NSLog(@"MAVLINK_MSG_ID_STATUSTEXT");
//            break;
//        case MAVLINK_MSG_ID_SYS_STATUS:
//            NSLog(@"MAVLINK_MSG_ID_SYS_STATUS");
//            break;
//        
//        default:
//            NSLog(@"The msg id is %d (0x%x)", msg.msgid, msg.msgid);
//        break;
    }
}

@end
