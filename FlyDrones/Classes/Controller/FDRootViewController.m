//
//  FDRootViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/7/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDRootViewController.h"

@implementation FDRootViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.toggleAnimationType = SWRevealToggleAnimationTypeEaseOut;
    self.rearViewRevealWidth = 132.0f;
    self.rearViewRevealDisplacement = 0.0f;
    self.rearViewRevealOverdraw = 0.0f;
}

@end
