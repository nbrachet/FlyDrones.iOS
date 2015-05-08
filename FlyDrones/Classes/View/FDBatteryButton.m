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
    
    [self refreshImageView];
}

- (void)prepareForInterfaceBuilder {
    [super prepareForInterfaceBuilder];
    
    [self refreshImageView];
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
    
    [self refreshImageView];
}

#pragma mark - Private

- (void)refreshImageView {
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
    
    self.imageView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@end
