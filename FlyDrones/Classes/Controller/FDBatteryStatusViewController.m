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
    self.batteryRemainingLabel.text = (currentDroneStatus.batteryRemaining > 0) ? [NSString stringWithFormat:@"%d%%", (int)(currentDroneStatus.batteryRemaining * 100.0f)] : @"n/a";
    self.batteryVoltageLabel.text = (currentDroneStatus.batteryVoltage > 0) ? [NSString stringWithFormat:@"%0.3fV", currentDroneStatus.batteryVoltage] : @"n/a";
    self.batteryAmperageLabel.text = (currentDroneStatus.batteryAmperage > 0) ? [NSString stringWithFormat:@"%0.3fA", currentDroneStatus.batteryAmperage] : @"n/a";
}

@end
