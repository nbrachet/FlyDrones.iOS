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

@class FDDroneControlManager;

@protocol FDDroneControlManagerDelegate <NSObject>

@optional
- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didParseMessage:(NSString *)messageDescription;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleBatteryRemaining:(CGFloat)batteryRemaining current:(CGFloat)current voltage:(CGFloat)voltage;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleLocationCoordinate:(CLLocationCoordinate2D)locationCoordinate;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleVFRInfoForHeading:(NSUInteger)heading airspeed:(CGFloat)airspeed altitude:(CGFloat)altitude;

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleAttitudeRoll:(CGFloat)roll pitch:(CGFloat)pitch yaw:(CGFloat)yaw rollspeed:(CGFloat)rollspeed pitchspeed:(CGFloat)pitchspeed yawspeed:(CGFloat)yawspeed;

@end

@interface FDDroneControlManager : NSObject

@property (nonatomic, weak) id<FDDroneControlManagerDelegate> delegate;

- (void)parseLogFile:(NSString *)name ofType:(NSString *)type;
- (void)parseInputData:(NSData *)data;

@end
