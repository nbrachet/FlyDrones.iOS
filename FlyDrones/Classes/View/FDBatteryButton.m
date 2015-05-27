    //
//  FDBatteryButton.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDBatteryButton.h"

@implementation FDBatteryButton

#pragma mark - Lifecycle

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self refreshImageViewForce:YES];
}

- (void)prepareForInterfaceBuilder {
    [super prepareForInterfaceBuilder];
    
    [self refreshImageViewForce:YES];
}

#pragma mark - Custom Accessors

- (void)setBatteryRemainingPercent:(CGFloat)batteryRemainingPercent {
    if (_batteryRemainingPercent == batteryRemainingPercent) {
        return;
    }
    
    if (batteryRemainingPercent > 1.0f) {
        batteryRemainingPercent = 1.0f;
    }
    
    if (batteryRemainingPercent < 0.0f && batteryRemainingPercent != -1) {
        batteryRemainingPercent = 0.0f;
    }
    
    _batteryRemainingPercent = batteryRemainingPercent;
    
    [self refreshImageViewForce:NO];
}

- (void)setEnabled:(BOOL)enabled {
    BOOL prevEnabled = self.enabled;
    [super setEnabled:enabled];
    
    if (enabled != prevEnabled) {
        [self refreshImageViewForce:YES];
    }
}

#pragma mark - Private

- (void)refreshImageViewForce:(BOOL)forced {
    if (!self.enabled && !forced) {
        return;
    }
    UIImage *image;
    if (self.batteryRemainingPercent == -1) {
        image = self.notAvailableBatteryImage;
    } else if (self.batteryRemainingPercent <= 0.1f) {
        image = self.emptyBatteryImage;
    } else if (self.batteryRemainingPercent <= 0.35f) {
        image = self.lowBatteryImage;
    } else if (self.batteryRemainingPercent <= 0.6f) {
        image = self.mediumBatteryImage;
    } else if (self.batteryRemainingPercent <= 0.8f) {
        image = self.highBatteryImage;
    } else {
        image = self.fullBatteryImage;
    }
    self.imageView.tintColor = self.enabled ? self.enabledTintColor : self.disabledTintColor;
    [UIView transitionWithView:self duration:0.2f options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        self.imageView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    } completion:nil];
}

@end
