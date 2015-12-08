//
//  FDDroneControlManager.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/29/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDDroneControlManager.h"
#import "FDFileReader.h"
#import "NSData+MAVLink.h"
#import "pixhawk.h"

NSString * const FDDroneControlManagerDidHandleBatteryStatusNotification = @"didHandleBatteryStatusNotification";
NSString * const FDDroneControlManagerDidHandleScaledPressureInfoNotification = @"didHandleScaledPressureInfoNotification";
NSString * const FDDroneControlManagerDidHandleVFRInfoNotification = @"didHandleVFRInfoNotification";
NSString * const FDDroneControlManagerDidHandleLocationCoordinateNotification = @"didHandleLocationCoordinate";
NSString * const FDDroneControlManagerDidHandleSystemInfoNotification = @"didHandleSystemInfo";

CGFloat static const FDDroneControlManagerMavLinkDefaultSystemId = 252;
CGFloat static const FDDroneControlManagerMavLinkDefaultComponentId = 0;
CGFloat static const FDDroneControlManagerMavLinkDefaultTargetSystem = 1;

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
        
        const char *bytes = (const char *)[data bytes];
        BOOL isMessageDetected = [self parseMessageChar:bytes[0]];
        if (isMessageDetected) {
            usleep(1000);
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
    @autoreleasepool {
        const char *bytes = (const char *)[data bytes];
        for (int i = 0; i < data.length; i++) {
            [self parseMessageChar:bytes[i]];
        }
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
//    NSLog(@"%@", [NSString stringWithMAVLinkMessage:message]);
    switch (message->msgid) {
        case MAVLINK_MSG_ID_SYS_STATUS: {
            mavlink_sys_status_t sysStatus;
            mavlink_msg_sys_status_decode(message, &sysStatus);
            if ((sysStatus.battery_remaining < 0 && sysStatus.battery_remaining != -1) ||
                (sysStatus.current_battery < 0 && sysStatus.current_battery != -1)) {
                break;
            }
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
            break;
        }

        case MAVLINK_MSG_ID_GPS_RAW_INT: {
            if (![self.delegate respondsToSelector:@selector(droneControlManager:didHandleLocationCoordinate:)]) {
                break;
            }
            mavlink_gps_raw_int_t gpsRawIntPkt;
            mavlink_msg_gps_raw_int_decode(message, &gpsRawIntPkt);
            CLLocationCoordinate2D locationCoordinate = CLLocationCoordinate2DMake(gpsRawIntPkt.lat/10000000.0f,
                                                                                   gpsRawIntPkt.lon/10000000.0f);
            
            if (!CLLocationCoordinate2DIsValid(locationCoordinate)) {
                break;
            }
            droneStatus.gpsInfo.locationCoordinate = locationCoordinate;
            droneStatus.gpsInfo.satelliteCount = gpsRawIntPkt.satellites_visible;
            droneStatus.gpsInfo.hdop = gpsRawIntPkt.eph/100.0f;
            droneStatus.gpsInfo.fixType = gpsRawIntPkt.fix_type;
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
            
        case MAVLINK_MSG_ID_HEARTBEAT: {
            mavlink_heartbeat_t heartbeat;
            mavlink_msg_heartbeat_decode(message, &heartbeat);
            
            droneStatus.mavCustomMode = heartbeat.custom_mode;
            droneStatus.mavType = heartbeat.type;
            droneStatus.mavAutopilotType = heartbeat.autopilot;
            droneStatus.mavBaseMode = heartbeat.base_mode;
            droneStatus.mavSystemStatus = heartbeat.system_status;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:FDDroneControlManagerDidHandleSystemInfoNotification object:self];

                if ([self.delegate respondsToSelector:@selector(droneControlManager:didHandleHeartbeatInfo:mavType:mavAutopilotType:mavBaseMode:mavSystemStatus:)]) {
                    [self.delegate droneControlManager:self
                                didHandleHeartbeatInfo:droneStatus.mavCustomMode
                                               mavType:droneStatus.mavType
                                      mavAutopilotType:droneStatus.mavAutopilotType
                                           mavBaseMode:droneStatus.mavBaseMode
                                       mavSystemStatus:droneStatus.mavSystemStatus];
                }
            });
            break;
        }
            
        case MAVLINK_MSG_ID_PARAM_VALUE: {
            mavlink_param_value_t paramValue;
            mavlink_msg_param_value_decode(message, &paramValue);
            NSString *paramIdString = [NSString stringWithCString:paramValue.param_id encoding:NSASCIIStringEncoding];
            if (paramIdString.length == 0) {
                break;
            }
            CGFloat param_value = paramValue.param_value;
            
            [droneStatus.paramValues setObject:[NSNumber numberWithFloat:param_value] forKey:paramIdString];
            break;
        }
            
        case MAVLINK_MSG_ID_STATUSTEXT: {
            mavlink_statustext_t statusText;
            mavlink_msg_statustext_decode(message, &statusText);
            if (statusText.severity <= MAV_SEVERITY_ERROR) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *marketPacket = [NSString stringWithCString:statusText.text encoding:NSUTF8StringEncoding];
                    if ([self.delegate respondsToSelector:@selector(droneControlManager:didHandleErrorMessage:)]) {
                        [self.delegate droneControlManager:self didHandleErrorMessage:marketPacket];
                    }
                });
            }
            break;
        }
    }
}

- (NSData *)messageDataWithPitch:(CGFloat)pitch
                            roll:(CGFloat)roll
                          thrust:(CGFloat)thrust
                             yaw:(CGFloat)yaw {

//        NSMutableArray *rcChannelsRaw = [NSMutableArray array];
//        for (int i = 0; i < 8; i++) {
//            [rcChannelsRaw addObject:@(0)];
//        }
    NSMutableArray *rcChannelsRaw = [NSMutableArray arrayWithObjects:@(0), @(0), @(0), @(0), @(0), @(0), @(0), @(0), nil];

    FDDroneStatus *currentStatus = [FDDroneStatus currentStatus];
    @synchronized(currentStatus) {
        if (!(currentStatus.mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED)) {
            return nil;
        }

        //pitch
        id obj = [currentStatus.paramValues objectForKey:@"RCMAP_PITCH"];
        if (obj == nil)
            return nil;
        NSInteger pitchRCValueIndex = [obj integerValue];
        NSInteger pitchRCValue = [self rcValueFromManualControlValue:-pitch rcChannelIndex:pitchRCValueIndex]; // pitch is reversed in APMCopter
        [rcChannelsRaw replaceObjectAtIndex:(pitchRCValueIndex - 1) withObject:@(pitchRCValue)];

        //roll
        obj = [currentStatus.paramValues objectForKey:@"RCMAP_ROLL"];
        if (obj == nil)
            return nil;
        NSInteger rollRCValueIndex = [obj integerValue];
        NSInteger rollRCValue = [self rcValueFromManualControlValue:roll rcChannelIndex:rollRCValueIndex];
        [rcChannelsRaw replaceObjectAtIndex:(rollRCValueIndex - 1) withObject:@(rollRCValue)];

        //throttle
        obj = [currentStatus.paramValues objectForKey:@"RCMAP_THROTTLE"];
        if (obj == nil)
            return nil;
        NSInteger throttleRCValueIndex = [obj integerValue];
        NSInteger throttleRCValue = [self rcValueFromManualControlValue:thrust rcChannelIndex:throttleRCValueIndex];
        [rcChannelsRaw replaceObjectAtIndex:(throttleRCValueIndex - 1) withObject:@(throttleRCValue)];

        //yaw
        obj = [currentStatus.paramValues objectForKey:@"RCMAP_YAW"];
        if (obj == nil)
            return nil;
        NSInteger yawRCValueIndex = [obj integerValue];
        NSInteger yawRCValue = [self rcValueFromManualControlValue:yaw rcChannelIndex:yawRCValueIndex];
        [rcChannelsRaw replaceObjectAtIndex:(yawRCValueIndex - 1) withObject:@(yawRCValue)];
    }

    mavlink_message_t message;
    mavlink_msg_rc_channels_override_pack(FDDroneControlManagerMavLinkDefaultSystemId,
                                          FDDroneControlManagerMavLinkDefaultComponentId,
                                          &message,
                                          FDDroneControlManagerMavLinkDefaultTargetSystem,
                                          MAV_COMP_ID_ALL,
                                          [rcChannelsRaw[0] integerValue],
                                          [rcChannelsRaw[1] integerValue],
                                          [rcChannelsRaw[2] integerValue],
                                          [rcChannelsRaw[3] integerValue],
                                          [rcChannelsRaw[4] integerValue],
                                          [rcChannelsRaw[5] integerValue],
                                          [rcChannelsRaw[6] integerValue],
                                          [rcChannelsRaw[7] integerValue]);
    return [NSData dataWithMAVLinkMessage:&message];
}

- (NSData *)heartbeatData {
    mavlink_message_t message;
    mavlink_msg_heartbeat_pack(FDDroneControlManagerMavLinkDefaultSystemId,
                               FDDroneControlManagerMavLinkDefaultComponentId,
                               &message,
                               MAV_TYPE_GCS,
                               MAV_AUTOPILOT_INVALID,
                               MAV_MODE_FLAG_MANUAL_INPUT_ENABLED|MAV_MODE_FLAG_SAFETY_ARMED,
                               0,
                               MAV_STATE_ACTIVE);
    
    return [NSData dataWithMAVLinkMessage:&message];
}

- (NSData *)messageDataWithNewCustomMode:(enum ARDUCOPTER_MODE)mode {
    mavlink_message_t message;
    mavlink_msg_set_mode_pack(FDDroneControlManagerMavLinkDefaultSystemId,
                              FDDroneControlManagerMavLinkDefaultComponentId,
                              &message,
                              FDDroneControlManagerMavLinkDefaultTargetSystem,
                              MAV_MODE_FLAG_CUSTOM_MODE_ENABLED,
                              mode);
    return [NSData dataWithMAVLinkMessage:&message];
}

- (NSData *)messageDataWithArmedEnable:(BOOL)armed {
    mavlink_message_t message;
    mavlink_msg_command_long_pack(FDDroneControlManagerMavLinkDefaultSystemId,
                                  FDDroneControlManagerMavLinkDefaultComponentId,
                                  &message,
                                  FDDroneControlManagerMavLinkDefaultTargetSystem,
                                  MAV_COMP_ID_ALL,
                                  MAV_CMD_COMPONENT_ARM_DISARM,
                                  0,
                                  armed ? 1 : 0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0);
    return [NSData dataWithMAVLinkMessage:&message];
}

- (NSData *)messageDataWithCaptureSettingsFps:(NSInteger)fps resolution:(CGFloat)resolution bitrate:(CGFloat)bitrate {
    mavlink_message_t message;
    mavlink_msg_command_long_pack(FDDroneControlManagerMavLinkDefaultSystemId,
                                  FDDroneControlManagerMavLinkDefaultComponentId,
                                  &message,
                                  FDDroneControlManagerMavLinkDefaultTargetSystem,
                                  MAV_COMP_ID_ALL,
                                  2500, //MAV_CMD_VIDEO_START_CAPTURE
                                  0,
                                  0,    //Camera ID (0 for all cameras)
                                  fps,
                                  resolution,
                                  bitrate,
                                  0,
                                  0,
                                  0);
    return [NSData dataWithMAVLinkMessage:&message];
}

- (NSData *)messageDataForCaptureDisableCommand {
    mavlink_message_t message;
    mavlink_msg_command_long_pack(FDDroneControlManagerMavLinkDefaultSystemId,
                                  FDDroneControlManagerMavLinkDefaultComponentId,
                                  &message,
                                  FDDroneControlManagerMavLinkDefaultTargetSystem,
                                  MAV_COMP_ID_ALL,
                                  2501, //MAV_CMD_VIDEO_STOP_CAPTURE
                                  0,
                                  0,    //Camera ID (0 for all cameras)
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0);
    return [NSData dataWithMAVLinkMessage:&message];
}

- (NSData *)messageDataForParamRequestList {
    mavlink_message_t message;
    mavlink_msg_param_request_list_pack(FDDroneControlManagerMavLinkDefaultSystemId,
                                        FDDroneControlManagerMavLinkDefaultComponentId,
                                        &message,
                                        FDDroneControlManagerMavLinkDefaultTargetSystem,
                                        MAV_COMP_ID_ALL);
    return [NSData dataWithMAVLinkMessage:&message];
}

- (NSData *)messageDataForRequestDataStream:(enum MAV_DATA_STREAM)stream start:(BOOL)start {
    mavlink_message_t message;
    mavlink_msg_request_data_stream_pack(FDDroneControlManagerMavLinkDefaultSystemId,
                                         FDDroneControlManagerMavLinkDefaultComponentId,
                                         &message,
                                         FDDroneControlManagerMavLinkDefaultTargetSystem,
                                         0,
                                         stream,
                                         3,         //requested interval
                                         (int)start);
    return [NSData dataWithMAVLinkMessage:&message];
}

#pragma mark - Private

- (NSInteger)rcValueFromManualControlValue:(CGFloat)value rcChannelIndex:(NSInteger)rcChannelIndex {
    FDDroneStatus *currentStatus = [FDDroneStatus currentStatus];
    
    CGFloat minRCValue = 1000.0f;
    NSString *minValueKey = [NSString stringWithFormat:@"RC%ld_MIN", (long)rcChannelIndex];
    if ([currentStatus.paramValues objectForKey:minValueKey] != nil) {
        minRCValue = [[currentStatus.paramValues objectForKey:minValueKey] floatValue];
    }
    
    CGFloat trimRCValue = 1500.0f;
    NSString *trimValueKey = [NSString stringWithFormat:@"RC%ld_TRIM", (long)rcChannelIndex];
    if ([currentStatus.paramValues objectForKey:trimValueKey] != nil) {
        trimRCValue = [[currentStatus.paramValues objectForKey:trimValueKey] floatValue];
    }
    
    CGFloat maxRCValue = 2000.0f;
    NSString *maxValueKey = [NSString stringWithFormat:@"RC%ld_MAX", (long)rcChannelIndex];
    if ([currentStatus.paramValues objectForKey:maxValueKey] != nil) {
        maxRCValue = [[currentStatus.paramValues objectForKey:maxValueKey] floatValue];
    }
    
    NSString *reverseValueKey = [NSString stringWithFormat:@"RC%ld_REV", (long)rcChannelIndex];
    if ([currentStatus.paramValues objectForKey:reverseValueKey] != nil) {
        NSInteger reverse = [[currentStatus.paramValues objectForKey:reverseValueKey] integerValue];
        if (reverse == -1) {
            value = -value;
        }
    }

    CGFloat epsilon = (maxRCValue - minRCValue) * 0.01f; // 1% of range
    if (trimRCValue <= minRCValue + epsilon || trimRCValue >= maxRCValue - epsilon) {
        trimRCValue = roundf((maxRCValue + minRCValue) / 2); // default to mid trim

        [currentStatus.paramValues setObject:[NSNumber numberWithFloat:trimRCValue] forKey:trimValueKey];

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(droneControlManager:didHandleErrorMessage:)]) {
                [self.delegate droneControlManager:self didHandleErrorMessage:[NSString stringWithFormat:@"invalid value for %@", trimValueKey]];
            }
        });
    }

    NSInteger rcValue = trimRCValue;
    if (value > 0) {
        rcValue += (maxRCValue - trimRCValue) * value;
    } else if (value < 0) {
        rcValue -= (minRCValue - trimRCValue) * value;
    }

    if (rcValue < minRCValue) {
        rcValue = minRCValue;
    }
    if (rcValue > maxRCValue) {
        rcValue = maxRCValue;
    }

    return rcValue;
}

@end
