//
//  FDSystemStatusViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/25/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDSystemStatusViewController.h"
#import "FDDroneControlManager.h"

@interface FDSystemStatusViewController ()

@end

@implementation FDSystemStatusViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshInfo:)
                                                 name:FDDroneControlManagerDidHandleSystemInfoNotification
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

    NSMutableString *sysStatusString = [NSMutableString string];
    [sysStatusString appendString:NSLocalizedString(@"Base Mode:", @"Base Mode:")];
    if (currentDroneStatus.mavBaseMode & (uint8_t)MAV_MODE_FLAG_TEST_ENABLED) {
        [sysStatusString appendString:@"\n - Test Enabled"];
    }
    if (currentDroneStatus.mavBaseMode & (uint8_t)MAV_MODE_FLAG_AUTO_ENABLED) {
        [sysStatusString appendString:@"\n - Auto Enabled"];
    }
    if (currentDroneStatus.mavBaseMode & (uint8_t)MAV_MODE_FLAG_STABILIZE_ENABLED) {
        [sysStatusString appendString:@"\n - Stabilize Enabled"];
    }
    if (currentDroneStatus.mavBaseMode & (uint8_t)MAV_MODE_FLAG_HIL_ENABLED) {
        [sysStatusString appendString:@"\n - HIL Enabled"];
    }
    if (currentDroneStatus.mavBaseMode & (uint8_t)MAV_MODE_FLAG_MANUAL_INPUT_ENABLED) {
        [sysStatusString appendString:@"\n - Manual Input Enabled"];
    }
    if (currentDroneStatus.mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED) {
        [sysStatusString appendString:@"\n - Safety Armed Enabled"];
    }
    if (currentDroneStatus.mavBaseMode & (uint8_t)MAV_MODE_FLAG_CUSTOM_MODE_ENABLED) {
        switch (currentDroneStatus.mavBaseMode) {
            case FDAutoPilotModeAcro:
                [sysStatusString appendString:@" - ACRO"];
                break;
            case FDAutoPilotModeAltHold:
                [sysStatusString appendString:@" - ALT_HOLD"];
                break;
            case FDAutoPilotModeAuto:
                [sysStatusString appendString:@" - AUTO"];
                break;
            case FDAutoPilotModeAutotune:
                [sysStatusString appendString:@" - AUTOTUNE"];
                break;
            case FDAutoPilotModeCircle:
                [sysStatusString appendString:@" - CIRCLE"];
                break;
            case FDAutoPilotModeDrift:
                [sysStatusString appendString:@" - DRIFT"];
                break;
            case FDAutoPilotModeFlip:
                [sysStatusString appendString:@" - FLIP"];
                break;
            case FDAutoPilotModeGuided:
                [sysStatusString appendString:@" - GUIDED"];
                break;
            case FDAutoPilotModeLand:
                [sysStatusString appendString:@" - LAND"];
                break;
            case FDAutoPilotModeLoiter:
                [sysStatusString appendString:@" - LOITER"];
                break;
            case FDAutoPilotModeOfLoiter:
                [sysStatusString appendString:@" - OF_LOITER"];
                break;
            case FDAutoPilotModePoshold:
                [sysStatusString appendString:@" - POSHOLD"];
                break;
            case FDAutoPilotModeRTL:
                [sysStatusString appendString:@" - RTL"];
                break;
            case FDAutoPilotModeSport:
                [sysStatusString appendString:@" - SPORT"];
                break;
            case FDAutoPilotModeStabilize:
                [sysStatusString appendString:@" - STABILIZE"];
                break;
            default:
                [sysStatusString appendFormat:@" (%d)", currentDroneStatus.mavBaseMode];
                break;
        }
        
    }
    self.textView.text = sysStatusString;
}

@end
