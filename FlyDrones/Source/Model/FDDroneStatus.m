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

+ (NSString *)nameFromMode:(FDAutoPilotMode)mode {
    NSString *name;
    switch (mode) {
        case FDAutoPilotModeStabilize:
            name = @"STABILIZE";
            break;
        case FDAutoPilotModeAltHold:
            name = @"ALT_HOLD";
            break;
        case FDAutoPilotModeLoiter:
            name = @"LOITER";
            break;
        case FDAutoPilotModeRTL:
            name = @"RTL";
            break;
        case FDAutoPilotModeLand:
            name = @"LAND";
            break;
        case FDAutoPilotModeDrift:
            name = @"DRIFT";
            break;
        case FDAutoPilotModePoshold:
            name = @"POSHOLD";
            break;
        default:
            name = @"N/A";
            break;
    }
    return name;
}

+ (FDAutoPilotMode)modeFromName:(NSString *)name {
    if ([name isEqualToString:@"STABILIZE"]) {
        return FDAutoPilotModeStabilize;
    } else if ([name isEqualToString:@"ALT_HOLD"]) {
        return FDAutoPilotModeAltHold;
    } else if ([name isEqualToString:@"LOITER"]) {
        return FDAutoPilotModeLoiter;
    } else if ([name isEqualToString:@"RTL"]) {
        return FDAutoPilotModeRTL;
    } else if ([name isEqualToString:@"LAND"]) {
        return FDAutoPilotModeLand;
    } else if ([name isEqualToString:@"DRIFT"]) {
        return FDAutoPilotModeDrift;
    } else if ([name isEqualToString:@"POSHOLD"]) {
        return FDAutoPilotModePoshold;
    } else {
        return FDAutoPilotModeNA;
    }
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
    self.batteryRemaining = FDNotAvailable;
    self.batteryVoltage = FDNotAvailable;
    self.batteryAmperage = FDNotAvailable;
    
    self.altitude = FDNotAvailable;
    self.airspeed = FDNotAvailable;
    self.groundspeed = FDNotAvailable;
    self.climbRate = FDNotAvailable;
    self.heading = FDNotAvailable;
    self.throttleSetting = FDNotAvailable;
    
    self.navigationBearing = FDNotAvailable;
    self.altitudeError = FDNotAvailable;
    self.temperature = FDNotAvailable;
    self.absolutePressure = FDNotAvailable;
    self.differentialPressure = FDNotAvailable;
    
    self.gpsInfo = [[FDGPSInfo alloc] init];
    self.gpsInfo.locationCoordinate = kCLLocationCoordinate2DInvalid;
}

@end
