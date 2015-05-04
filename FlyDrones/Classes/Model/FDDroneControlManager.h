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

@end

@interface FDDroneControlManager : NSObject

@property (nonatomic, weak) id<FDDroneControlManagerDelegate> delegate;

- (void)parseLogFile:(NSString *)name ofType:(NSString *)type;

@end
