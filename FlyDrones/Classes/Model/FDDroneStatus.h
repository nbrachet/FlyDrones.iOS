//
//  FDDroneStatus.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>

#define FDNotAvailable NSIntegerMin

@interface FDDroneStatus : NSObject

@property (nonatomic, assign) CGFloat batteryRemaining;
@property (nonatomic, assign) CGFloat batteryVoltage;
@property (nonatomic, assign) CGFloat batteryAmperage;

@property (nonatomic, assign) CGFloat altitude;
@property (nonatomic, assign) CGFloat airspeed;
@property (nonatomic, assign) CGFloat groundspeed;
@property (nonatomic, assign) CGFloat climbRate;
@property (nonatomic, assign) NSInteger heading;
@property (nonatomic, assign) NSInteger throttleSetting;

@property (nonatomic, assign) CGFloat navigationBearing;

@property (nonatomic, assign) CGFloat temperature;
@property (nonatomic, assign) CGFloat absolutePressure;
@property (nonatomic, assign) CGFloat differentialPressure;

@property (nonatomic, assign) CLLocationCoordinate2D locationCoordinate;

//temponary
@property (nonatomic, copy) NSString *pathForUDPConnection;
@property (nonatomic, assign) NSInteger portForUDPConnection;
@property (nonatomic, copy) NSString *pathForTCPConnection;
@property (nonatomic, assign) NSInteger portForTCPConnection;

+ (instancetype)alloc __attribute__((unavailable("alloc not available")));
+ (instancetype)allocWithZone __attribute__((unavailable("allocWithZone not available")));
- (instancetype)init __attribute__((unavailable("init not available")));
- (instancetype)copy __attribute__((unavailable("copy not available")));
+ (instancetype)copyWithZone __attribute__((unavailable("copyWithZone not available")));
- (instancetype)mutableCopy __attribute__((unavailable("mutableCopy not available")));
+ (instancetype)new __attribute__((unavailable("new not available")));

+ (instancetype)currentStatus;
- (void)clearStatus;

@end
