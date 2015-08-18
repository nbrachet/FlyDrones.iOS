//
//  FDJoystickView2.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/13/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDJoystickView2 : UIView

@property (nonatomic, weak) IBOutlet UIView *touchView;

@property (nonatomic, strong) IBOutlet UIImageView *throttleImageView;
@property (nonatomic, copy) IBInspectable UIColor *color;
@property (nonatomic, assign) IBInspectable CGFloat lineWidth;
@property (nonatomic, copy) IBInspectable UIImage *takeoffImage;
@property (nonatomic, copy) IBInspectable UIImage *landingImage;
@property (nonatomic, copy) IBInspectable UIImage *leftImage;
@property (nonatomic, copy) IBInspectable UIImage *rightImage;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *centerXLayoutConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *centerYLayoutConstraint;

- (CGFloat)stickHorizontalValue;
- (CGFloat)stickVerticalValue;
- (void)resetPosition;

@end
