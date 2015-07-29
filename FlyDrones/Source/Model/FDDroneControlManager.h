//
//  FDDroneControlManager.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/29/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDDroneStatus.h"

extern NSString * const FDDroneControlManagerDidHandleBatteryStatusNotification;
extern NSString * const FDDroneControlManagerDidHandleScaledPressureInfoNotification;
extern NSString * const FDDroneControlManagerDidHandleVFRInfoNotification;
extern NSString * const FDDroneControlManagerDidHandleLocationCoordinateNotification;
extern NSString * const FDDroneControlManagerDidHandleSystemInfoNotification;

@class FDDroneControlManager;

@protocol FDDroneControlManagerDelegate <NSObject>

@optional
- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didParseMessage:(NSString *)messageDescription;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleBatteryRemaining:(CGFloat)batteryRemaining current:(CGFloat)current voltage:(CGFloat)voltage;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleLocationCoordinate:(CLLocationCoordinate2D)locationCoordinate;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleVFRInfoForHeading:(NSUInteger)heading altitude:(CGFloat)altitude airspeed:(CGFloat)airspeed groundspeed:(CGFloat)groundspeed climbRate:(CGFloat)climbRate throttleSetting:(CGFloat)throttleSetting;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleHeartbeatInfo:(uint32_t)mavCustomMode mavType:(uint8_t)mavType mavAutopilotType:(uint8_t) mavAutopilotType mavBaseMode:(uint8_t)mavBaseMode mavSystemStatus:(uint8_t)mavSystemStatus;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleErrorMessage:(NSString *)errorText;

@end

@interface FDDroneControlManager : NSObject

@property (nonatomic, weak) id<FDDroneControlManagerDelegate> delegate;

- (void)parseLogFile:(NSString *)name ofType:(NSString *)type;
- (void)parseInputData:(NSData *)data;

- (NSData *)messageDataWithPitch:(CGFloat)pitch roll:(CGFloat)roll thrust:(CGFloat)thrust yaw:(CGFloat)yaw sequenceNumber:(uint16_t)sequenceNumber;
- (BOOL)isRCMapDataVilid;
- (NSData *)heartbeatData;
- (NSData *)messageDataWithNewCustomMode:(enum ARDUCOPTER_MODE)mode;
- (NSData *)messageDataWithArmedEnable:(BOOL)armed;
- (NSData *)messageDataWithCaptureSettingsFps:(NSInteger)fps resolution:(CGFloat)resolution bitrate:(CGFloat)bitrate;
- (NSData *)messageDataForCaptureDisableCommand;
- (NSData *)messageDataForParamRequestList;
- (NSData *)messageDataForRequestDataStream:(enum MAV_DATA_STREAM)stream start:(BOOL)start;

@end
