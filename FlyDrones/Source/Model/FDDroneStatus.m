//
//  FDDroneStatus.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDDroneStatus.h"

static NSString * const DroneStatusKey = @"DroneStatus";
static NSString * const ParamValuesKey = @"paramValues";

@implementation FDDroneStatus

#pragma mark - Public

+ (instancetype)currentStatus {
    static id currentStatus = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:DroneStatusKey];
        if (data) {
            currentStatus = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        } else {
            currentStatus = [[super alloc] initInstance];
            [currentStatus clearStatus];
            [currentStatus setParamValues:[NSMutableDictionary dictionary]];
        }
    });
    return currentStatus;
}

- (void)synchronize {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:data forKey:DroneStatusKey];
    [userDefaults synchronize];
}

#pragma mark - Lifecycle

- (void)dealloc {
    [self clearStatus];
}

#pragma mark - Private

- (instancetype)initInstance {
    return [super init];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        [self clearStatus];
        self.paramValues = [NSMutableDictionary dictionaryWithDictionary:[coder decodeObjectForKey:ParamValuesKey]];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[self.paramValues copy] forKey:ParamValuesKey];
}

- (void)clearStatus {
    self.batteryRemaining = -1;
    self.batteryVoltage = UINT16_MAX;
    self.batteryAmperage = -1;
    
    self.altitude = FDNotAvailable;
    self.airspeed = FDNotAvailable;
    self.groundspeed = FDNotAvailable;
    self.climbRate = FDNotAvailable;
    self.heading = FDNotAvailable;
    self.throttleSetting = FDNotAvailable;
    
    self.gpsInfo = [[FDGPSInfo alloc] init];
    self.gpsInfo.locationCoordinate = kCLLocationCoordinate2DInvalid;
}

@end
