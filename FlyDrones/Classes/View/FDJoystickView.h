//
//  FDJoystickView.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/13/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, FDJoystickViewState) {
    FDJoystickViewStateNone = 0,
    FDJoystickViewStateUp,
    FDJoystickViewStateLeft,
    FDJoystickViewStateRight,
    FDJoystickViewStateDown
};

@protocol FDJoystickViewDelegate <NSObject>

@optional
- (void)joystickViewNoticedCurrentState:(FDJoystickViewState)state;

@end

@interface FDJoystickView : UIView

@property (nonatomic, weak) IBOutlet UIImageView *backgroundImageView;
@property (nonatomic, weak) IBOutlet UIImageView *touchImageView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *touchImageViewCenterXLayoutConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *touchImageViewCenterYLayoutConstraint;
@property (nonatomic, weak) IBOutlet id<FDJoystickViewDelegate> delegate;
@property (nonatomic, assign) FDJoystickViewState state;

- (void)startObeserveControlStatesWithTimeInterval:(NSTimeInterval)timeInterval;
- (void)stopObeserveControlStates;

@end
