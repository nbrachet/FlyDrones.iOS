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

NSString * const FDDroneControlManagerDidHandleBatteryStatusNotification = @"didHandleBatteryStatusNotification";
NSString * const FDDroneControlManagerDidHandleScaledPressureInfoNotification = @"didHandleScaledPressureInfoNotification";
NSString * const FDDroneControlManagerDidHandleVFRInfoNotification = @"didHandleVFRInfoNotification";
NSString * const FDDroneControlManagerDidHandleLocationCoordinateNotification = @"didHandleLocationCoordinate";

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
    FDDroneStatus *droneStatus = [FDDroneStatus currentStatus];
    switch (message->msgid) {
        case MAVLINK_MSG_ID_NAV_CONTROLLER_OUTPUT: {
            mavlink_nav_controller_output_t navControllerOutput;
            mavlink_msg_nav_controller_output_decode(message, &navControllerOutput);
            droneStatus.navigationBearing = navControllerOutput.nav_bearing;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(droneControlManager:didHandleNavigationInfo:)]) {
                    [self.delegate droneControlManager:self didHandleNavigationInfo:droneStatus.navigationBearing];
                }
            });
            break;
        }
            
        case MAVLINK_MSG_ID_SCALED_PRESSURE: {
            mavlink_scaled_pressure_t scaledPressure;
            mavlink_msg_scaled_pressure_decode(message, &scaledPressure);
            droneStatus.temperature = scaledPressure.temperature / 100.0f;
            droneStatus.absolutePressure = scaledPressure.press_abs;
            droneStatus.differentialPressure = scaledPressure.press_diff;
            
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:FDDroneControlManagerDidHandleScaledPressureInfoNotification object:self];
                
                if ([self.delegate respondsToSelector:@selector(droneControlManager:didHandleScaledPressureInfo:absolutePressure:differentialPressure:)]) {
                    [self.delegate droneControlManager:self didHandleScaledPressureInfo:droneStatus.temperature absolutePressure:droneStatus.absolutePressure differentialPressure:droneStatus.differentialPressure];
                }
            });
        }
            
        case MAVLINK_MSG_ID_BATTERY_STATUS: {
            mavlink_battery_status_t batteryStatus;
            mavlink_msg_battery_status_decode(message, &batteryStatus);
            droneStatus.batteryRemaining = batteryStatus.battery_remaining / 100.0f;
            droneStatus.batteryAmperage = batteryStatus.current_battery / 100.0f;
                
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:FDDroneControlManagerDidHandleBatteryStatusNotification object:self];
                
                if ([self.delegate respondsToSelector:@selector(droneControlManager:didHandleBatteryRemaining:current:voltage:)]) {
                    [self.delegate droneControlManager:self
                             didHandleBatteryRemaining:droneStatus.batteryRemaining
                                               current:droneStatus.batteryAmperage
                                               voltage:-1];
                }
            });
            
            break;
        }
            
        case MAVLINK_MSG_ID_SYS_STATUS: {
            mavlink_sys_status_t sysStatus;
            mavlink_msg_sys_status_decode(message, &sysStatus);
            droneStatus.batteryRemaining = sysStatus.battery_remaining / 100.0f;
            droneStatus.batteryAmperage = sysStatus.current_battery / 100.0f;
            droneStatus.batteryVoltage = sysStatus.voltage_battery / 1000.0f;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:FDDroneControlManagerDidHandleBatteryStatusNotification object:self];
                
                if ([self.delegate respondsToSelector:@selector(droneControlManager:didHandleBatteryRemaining:current:voltage:)]) {
                    [self.delegate droneControlManager:self
                             didHandleBatteryRemaining:droneStatus.batteryRemaining
                                               current:droneStatus.batteryAmperage
                                               voltage:droneStatus.batteryVoltage];
                }
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
            droneStatus.locationCoordinate = locationCoordinate;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:FDDroneControlManagerDidHandleLocationCoordinateNotification object:self];
                
                [self.delegate droneControlManager:self didHandleLocationCoordinate:locationCoordinate];
            });
            
            break;
        }
            
        case MAVLINK_MSG_ID_VFR_HUD: {
            mavlink_vfr_hud_t  vfrHudPkt;
            mavlink_msg_vfr_hud_decode(message, &vfrHudPkt);
            
            droneStatus.altitude = vfrHudPkt.alt;
            droneStatus.airspeed = vfrHudPkt.airspeed;
            droneStatus.groundspeed = vfrHudPkt.groundspeed;
            droneStatus.climbRate = vfrHudPkt.climb;
            droneStatus.heading = vfrHudPkt.heading;
            droneStatus.throttleSetting = vfrHudPkt.throttle;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:FDDroneControlManagerDidHandleVFRInfoNotification object:self];
                
                if ([self.delegate respondsToSelector:@selector(droneControlManager:didHandleVFRInfoForHeading:altitude:airspeed:groundspeed:climbRate:throttleSetting:)]) {
                    [self.delegate droneControlManager:self
                            didHandleVFRInfoForHeading:droneStatus.heading
                                              altitude:droneStatus.altitude
                                              airspeed:droneStatus.airspeed
                                           groundspeed:droneStatus.groundspeed
                                             climbRate:droneStatus.climbRate
                                       throttleSetting:droneStatus.throttleSetting];
                }
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
                if ([self.delegate respondsToSelector:@selector(droneControlManager:didHandleAttitudeRoll:pitch:yaw:rollspeed:pitchspeed:yawspeed:)]) {
                    [self.delegate droneControlManager:self didHandleAttitudeRoll:attitude.roll pitch:attitude.pitch yaw:attitude.yaw rollspeed:attitude.rollspeed pitchspeed:attitude.pitchspeed yawspeed:attitude.yawspeed];
                }
            });
            
            break;
        }
//        case MAVLINK_MSG_ID_HEARTBEAT:
//            NSLog(@"%@", [NSString stringWithMAVLinkMessage:message]);
//
//        break;
    }
}

@end
