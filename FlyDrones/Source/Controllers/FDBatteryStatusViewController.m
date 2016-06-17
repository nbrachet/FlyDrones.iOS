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

    if (currentDroneStatus.batteryRemaining == -1) {
        self.batteryRemainingLabel.text = @"N/A";
    } else {
        self.batteryRemainingLabel.text = [NSString stringWithFormat:@"%d%%", (int)(currentDroneStatus.batteryRemaining * 100.0f)];
    }

    if (currentDroneStatus.batteryVoltage == UINT16_MAX) {
        self.batteryVoltageLabel.text = @"N/A";
    } else {
        self.batteryVoltageLabel.text = [NSString stringWithFormat:@"%0.1fV", currentDroneStatus.batteryVoltage];
    }

    if (currentDroneStatus.batteryAmperage == -1) {
        self.batteryAmperageLabel.text = @"N/A";
    } else {
        self.batteryAmperageLabel.text = [NSString stringWithFormat:@"%0.1fA", currentDroneStatus.batteryAmperage];
    }
}

@end
