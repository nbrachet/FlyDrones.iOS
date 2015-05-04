//
//  FDDroneControlManager.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/29/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDDroneControlManager;

@protocol FDDroneControlManagerDelegate <NSObject>

@optional
- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didParseMessage:(NSString *)messageDescription;
- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleBatteryStatus:(NSInteger)batteryRemaining;
- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleLocationCoordinate:(CLLocationCoordinate2D)locationCoordinate;

/**
 * @brief Visual Flight Rules
 * @param heading in degrees, in compass units (0..360, 0=north)
 * @param airspeed in m/s
 * @param altitude (MSL), in meters
 */
- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleVFRInfoForHeading:(NSUInteger)heading airspeed:(CGFloat)airspeed altitude:(CGFloat)altitude;

@end

@interface FDDroneControlManager : NSObject

@property (nonatomic, weak) id<FDDroneControlManagerDelegate> delegate;

- (void)parseLogFile:(NSString *)name ofType:(NSString *)type;
- (void)parseInputData:(NSData *)data;

@end
