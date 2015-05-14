//
//  FDJoystickView.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/13/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDJoystickView : UIView

@property (nonatomic, weak) IBOutlet UIImageView *backgroundImageView;
@property (nonatomic, weak) IBOutlet UIImageView *touchImageView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *touchImageViewCenterXLayoutConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *touchImageViewCenterYLayoutConstraint;

- (CGFloat)stickHorisontalValue;
- (CGFloat)stickVerticalValue;

@end
