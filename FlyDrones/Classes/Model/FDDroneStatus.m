//
//  FDDroneStatus.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDDroneStatus.h"

@implementation FDDroneStatus

#pragma mark - Public

+ (instancetype)currentStatus {
    static id currentStatus = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        currentStatus = [[super alloc] initInstance];
        [currentStatus clearStatus];
    });
    return currentStatus;
}

#pragma mark - Lifecycle

- (void)dealloc {
    [self clearStatus];
}

#pragma mark - Private

- (instancetype)initInstance {
    return [super init];
}

- (void)clearStatus {
    self.batteryRemaining = 0;
    self.batteryVoltage = 0;
    self.batteryAmperage = 0;
}

@end
