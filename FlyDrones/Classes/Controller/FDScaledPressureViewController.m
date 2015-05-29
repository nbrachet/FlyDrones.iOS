//
//  FDScaledPressureViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/11/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDScaledPressureViewController.h"
#import "FDDroneControlManager.h"

@implementation FDScaledPressureViewController

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshInfo:)
                                                 name:FDDroneControlManagerDidHandleScaledPressureInfoNotification
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
    self.absolutePressureLabel.text = (currentDroneStatus.absolutePressure != FDNotAvailable) ? [NSString stringWithFormat:@"%0.1f hPa", currentDroneStatus.absolutePressure] : @"N/A";
    self.differentialPressureLabel.text = (currentDroneStatus.differentialPressure != FDNotAvailable) ? [NSString stringWithFormat:@"%0.4f hPa", currentDroneStatus.differentialPressure] : @"N/A";
}

@end
