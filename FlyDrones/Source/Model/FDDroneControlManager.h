//
//  FDDroneControlManager.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/29/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>
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

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleAttitudeRoll:(CGFloat)roll pitch:(CGFloat)pitch yaw:(CGFloat)yaw rollspeed:(CGFloat)rollspeed pitchspeed:(CGFloat)pitchspeed yawspeed:(CGFloat)yawspeed;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleNavigationInfo:(CGFloat)navigationBearing;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleScaledPressureInfo:(CGFloat)temperature absolutePressure:(CGFloat)absolutePressure differentialPressure:(CGFloat)differentialPressure;

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
- (NSData *)messageDataWithNewCustomMode:(FDAutoPilotMode)mode;
- (NSData *)messageDataWithArmedEnable:(BOOL)armed;
- (NSData *)messageDataWithCaptureSettingsFps:(NSInteger)fps resolution:(CGFloat)resolution bitrate:(CGFloat)bitrate;
- (NSData *)messageDataForCaptureDisableCommand;
- (NSData *)messageDataForParamRequestList;

@end
