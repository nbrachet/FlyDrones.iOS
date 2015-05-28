//
//  FDCustomModeViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/28/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDCustomModeViewController.h"

@interface FDCustomModeViewController ()

@end

@implementation FDCustomModeViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBActions

- (IBAction)selectMode:(id)sender {
    UIButton *button = (UIButton *)sender;
    NSString *title = [button titleForState:UIControlStateNormal];
    
    FDAutoPilotMode newMode = FDAutoPilotModeNA;
    if ([title isEqualToString:@"STABILIZE"]) {
        newMode = FDAutoPilotModeStabilize;
    } else if ([title isEqualToString:@"ALT_HOLD"]) {
        newMode = FDAutoPilotModeAltHold;
    } else if ([title isEqualToString:@"LOITER"]) {
        newMode = FDAutoPilotModeLoiter;
    } else if ([title isEqualToString:@"RTL"]) {
        newMode = FDAutoPilotModeRTL;
    } else if ([title isEqualToString:@"LAND"]) {
        newMode = FDAutoPilotModeLand;
    } else if ([title isEqualToString:@"DRIFT"]) {
        newMode = FDAutoPilotModeDrift;
    } else if ([title isEqualToString:@"POSHOLD"]) {
        newMode = FDAutoPilotModePoshold;
    }
    if (newMode != FDAutoPilotModeNA) {
        [self changeModeTo:newMode];
    }
}

#pragma mark - Private

- (void)changeModeTo:(FDAutoPilotMode)mode {
    if (self.delegate == nil) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(didSelectNewMode:)]) {
        [self.delegate didSelectNewMode:mode];
    }
}

@end
