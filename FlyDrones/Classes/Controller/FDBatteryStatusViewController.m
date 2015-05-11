//
//  FDBatteryStatusViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDBatteryStatusViewController.h"
#import "FDDroneControlManager.h"

@implementation FDBatteryStatusViewController

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshInfo:)
                                                 name:FDDroneControlManagerDidHandleBatteryStatusNotification
                                               object:nil];
    [self refreshInfo:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private

- (void)refreshInfo:(NSNotification *)notification {
    FDDroneStatus *currentDroneStatus = [FDDroneStatus currentStatus];
    self.batteryRemainingLabel.text = (currentDroneStatus.batteryRemaining != FDNotAvailable) ? [NSString stringWithFormat:@"%d%%", (int)(currentDroneStatus.batteryRemaining * 100.0f)] : @"N/A";
    self.batteryVoltageLabel.text = (currentDroneStatus.batteryVoltage != FDNotAvailable) ? [NSString stringWithFormat:@"%0.3fV", currentDroneStatus.batteryVoltage] : @"N/A";
    self.batteryAmperageLabel.text = (currentDroneStatus.batteryAmperage != FDNotAvailable) ? [NSString stringWithFormat:@"%0.3fA", currentDroneStatus.batteryAmperage] : @"N/A";
}

@end
