//
//  FDLeftSideViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/7/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDLeftSideViewController.h"
#import "FDConnectionSettingsViewController.h"

@implementation FDLeftSideViewController

#pragma mark - Lifecycle

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - IBActions

- (IBAction)settings:(id)sender {
    for (UIViewController *viewController in self.navigationController.viewControllers) {
        if ([viewController isKindOfClass:FDConnectionSettingsViewController.class]) {
            [self.navigationController popToViewController:viewController animated:YES];
            return;
        }
    }
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
