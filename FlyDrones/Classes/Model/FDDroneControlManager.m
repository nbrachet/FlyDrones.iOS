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

@property (nonatomic, strong) dispatch_queue_t parsingQueue;

@end

@implementation FDDroneControlManager

#pragma mark - Public

- (instancetype)init {
    self = [super init];
    if (self) {
        self.parsingQueue = dispatch_queue_create("FDDroneControlManagerParsingQueue", DISPATCH_QUEUE_SERIAL);

    }
    return self;
}

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

- (void)parseInputData:(NSData *)data {
    if (data.length == 0) {
        return;
    }
    
    __weak __typeof(self)weakSelf = self;
    dispatch_async(self.parsingQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf parseData:data];
    });
}

- (void)parseData:(NSData *)data {
    const char *bytes = (const char *) [data bytes];
    for (int i = 0; i < data.length; i++) {
        [self parseMessageChar:bytes[i]];
    }
}

- (BOOL)parseMessageChar:(uint8_t)messageChar {
    if (mavlink_parse_char(MAVLINK_COMM_0, messageChar, &msg, &status)) {
        NSString *messageDescription = [NSString stringWithMAVLinkMessage:&msg];
        [self handleMessage:&msg];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(droneControlManager:didParseMessage:)]) {
                [self.delegate droneControlManager:self didParseMessage:messageDescription];
            }
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
            if (![self.delegate respondsToSelector:@selector(droneControlManager:didHandleBatteryRemaining:current:voltage:)]) {
                break;
            }
            
            mavlink_battery_status_t batteryStatus;
            mavlink_msg_battery_status_decode(message, &batteryStatus);

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate droneControlManager:self didHandleBatteryRemaining:batteryStatus.battery_remaining current:batteryStatus.current_battery voltage:-1];
            });
            
            break;
        }
            
        case MAVLINK_MSG_ID_SYS_STATUS: {
            if (![self.delegate respondsToSelector:@selector(droneControlManager:didHandleBatteryRemaining:current:voltage:)]) {
                break;
            }

            mavlink_sys_status_t sysStatus;
            mavlink_msg_sys_status_decode(message, &sysStatus);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate droneControlManager:self didHandleBatteryRemaining:sysStatus.battery_remaining current:sysStatus.current_battery/100.0f voltage:sysStatus.voltage_battery/1000.0f];
            });
        }

        case MAVLINK_MSG_ID_GPS_RAW_INT: {
            if (![self.delegate respondsToSelector:@selector(droneControlManager:didHandleLocationCoordinate:)]) {
                break;
            }
            
            mavlink_gps_raw_int_t gpsRawIntPkt;
            mavlink_msg_gps_raw_int_decode(message, &gpsRawIntPkt);
            CLLocationCoordinate2D locationCoordinate = CLLocationCoordinate2DMake(gpsRawIntPkt.lat/10000000.0f,
                                                                                   gpsRawIntPkt.lon/10000000.0f);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate droneControlManager:self didHandleLocationCoordinate:locationCoordinate];
            });
            
            break;
        }
            
        case MAVLINK_MSG_ID_VFR_HUD: {
            if (![self.delegate respondsToSelector:@selector(droneControlManager:didHandleVFRInfoForHeading:airspeed:altitude:)]) {
                break;
            }
            
            mavlink_vfr_hud_t  vfrHudPkt;
            mavlink_msg_vfr_hud_decode(message, &vfrHudPkt);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate droneControlManager:self didHandleVFRInfoForHeading:vfrHudPkt.heading airspeed:vfrHudPkt.airspeed altitude:vfrHudPkt.alt];
            });
            
            break;
        }
        case MAVLINK_MSG_ID_ATTITUDE: {
            if (![self.delegate respondsToSelector:@selector(droneControlManager:didHandleAttitudeRoll:pitch:yaw:rollspeed:pitchspeed:yawspeed:)]) {
                break;
            }
            
            mavlink_attitude_t attitude;
            mavlink_msg_attitude_decode(message, &attitude);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate droneControlManager:self didHandleAttitudeRoll:attitude.roll pitch:attitude.pitch yaw:attitude.yaw rollspeed:attitude.rollspeed pitchspeed:attitude.pitchspeed yawspeed:attitude.yawspeed];
            });
            
            break;
        }
            
        
//        case MAVLINK_MSG_ID_PARAM_VALUE:
//            NSLog(@"MAVLINK_MSG_ID_PARAM_VALUE");
// 
//            break;
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
