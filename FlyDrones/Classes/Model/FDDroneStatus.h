//
//  FDDroneStatus.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDDroneStatus : NSObject

@property (nonatomic, assign) CGFloat batteryRemaining;
@property (nonatomic, assign) CGFloat batteryVoltage;
@property (nonatomic, assign) CGFloat batteryAmperage;

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
