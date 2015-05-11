//
//  FDVFRInfoViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/11/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDVFRInfoViewController.h"
#import "FDDroneControlManager.h"

@implementation FDVFRInfoViewController

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshInfo:)
                                                 name:FDDroneControlManagerDidHandleVFRInfoNotification
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
    self.airspeedLabel.text = (currentDroneStatus.airspeed != FDNotAvailable) ? [NSString stringWithFormat:@"%0.1f m/s", currentDroneStatus.airspeed] : @"N/A";
    self.groundspeedLabel.text = (currentDroneStatus.groundspeed != FDNotAvailable) ? [NSString stringWithFormat:@"%0.1f m/s", currentDroneStatus.groundspeed] : @"N/A";
    self.climbRateLabel.text = (currentDroneStatus.climbRate != FDNotAvailable) ? [NSString stringWithFormat:@"%0.3f m/s", currentDroneStatus.climbRate] : @"N/A";
    self.throttleSettingLabel.text = (currentDroneStatus.throttleSetting != FDNotAvailable) ? [NSString stringWithFormat:@"%d%%", currentDroneStatus.throttleSetting] : @"N/A";
}

@end
