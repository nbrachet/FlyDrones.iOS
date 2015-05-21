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
    self.batteryRemaining = FDNotAvailable;
    self.batteryVoltage = FDNotAvailable;
    self.batteryAmperage = FDNotAvailable;
    
    [self.paramValues removeAllObjects];
    self.paramValues = [NSMutableDictionary dictionary];
    
    self.altitude = FDNotAvailable;
    self.airspeed = FDNotAvailable;
    self.groundspeed = FDNotAvailable;
    self.climbRate = FDNotAvailable;
    self.heading = FDNotAvailable;
    self.throttleSetting = FDNotAvailable;
    
    self.navigationBearing = FDNotAvailable;
    
    self.temperature = FDNotAvailable;
    self.absolutePressure = FDNotAvailable;
    self.differentialPressure = FDNotAvailable;
    
    self.locationCoordinate = kCLLocationCoordinate2DInvalid;
}

@end
