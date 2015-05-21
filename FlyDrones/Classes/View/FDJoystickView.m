//
//  FDJoystickView.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/13/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDJoystickView.h"

@interface FDJoystickView ()

@property (nonatomic, assign) CGPoint firstTouchPoint;
@property (nonatomic, assign) CGPoint prevTouchViewPosition;
@property (nonatomic, assign) BOOL isTracking;
@property (nonatomic, strong) NSTimer *timer;

@end

@implementation FDJoystickView

#pragma mark - Custom Accessors

- (CGFloat)stickHorisontalValue {
    return -self.prevTouchViewPosition.x / CGRectGetMidX(self.backgroundImageView.bounds);
}

- (CGFloat)stickVerticalValue {
    return self.prevTouchViewPosition.y / CGRectGetMidY(self.backgroundImageView.bounds);
}

#pragma mark - Lifecycle

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    
    [self resetTouchViewPosition];
}

#pragma mark - UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint touchPoint = [touch locationInView:self];
        if (self.isTracking == NO && CGRectContainsPoint(self.touchImageView.frame, touchPoint)) {
            self.isTracking = YES;
            self.firstTouchPoint = [self convertPoint:touchPoint toView:self.touchImageView];
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        if (self.isTracking == NO) {
            return;
        }
        
        CGPoint touchPoint = [touch locationInView:self.backgroundImageView];
        CGPoint viewMidlePoint = CGPointMake(CGRectGetMidX(self.backgroundImageView.bounds), CGRectGetMidY(self.backgroundImageView.bounds));
        
        CGPoint touchViewMidlePoint = CGPointMake(CGRectGetMidX(self.touchImageView.bounds), CGRectGetMidY(self.touchImageView.bounds));
        CGSize firstTouchDelta = CGSizeMake(self.firstTouchPoint.x - touchViewMidlePoint.x,
                                            self.firstTouchPoint.y - touchViewMidlePoint.y);

        CGPoint touchViewCenterPoint = CGPointMake(viewMidlePoint.x - touchPoint.x + firstTouchDelta.width,
                                                   viewMidlePoint.y - touchPoint.y + firstTouchDelta.height);
        
        CGPoint convertedTouchViewCenterPoint = CGPointMake(touchViewCenterPoint.x + viewMidlePoint.x, touchViewCenterPoint.y + viewMidlePoint.y);
        CGFloat distance = [self distanceBetweenPoint:viewMidlePoint andPoint:convertedTouchViewCenterPoint];
        CGFloat angle = -atan2f(-touchViewCenterPoint.x, -touchViewCenterPoint.y) - M_PI_2;
        float radius = viewMidlePoint.x;
        if (distance > radius) {
            touchViewCenterPoint = CGPointMake(cos(angle) * radius ,sin(angle) * radius);
        }
        [self updateTouchViewPosition:touchViewCenterPoint animated:NO];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self resetTouchViewPosition];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self resetTouchViewPosition];
}

#pragma mark - Private

- (void)resetTouchViewPosition {
    self.isTracking = NO;
    
    CGPoint originPoint = CGPointZero;
    if (self.mode == FDJoystickViewModeSavedHorizontalPosition) {
        originPoint.x = self.prevTouchViewPosition.x;
    }
    if (self.mode == FDJoystickViewModeSavedVerticalPosition) {
        originPoint.y = self.prevTouchViewPosition.y;
    }
    [self updateTouchViewPosition:originPoint animated:YES];
}

- (void)updateTouchViewPosition:(CGPoint)center animated:(BOOL)animated {
    if (CGPointEqualToPoint(self.prevTouchViewPosition, center)) {
        return;
    }
    self.prevTouchViewPosition = center;
    
    void(^updateConstraints)() = ^() {
        self.touchImageViewCenterXLayoutConstraint.constant = center.x;
        self.touchImageViewCenterYLayoutConstraint.constant = center.y;
        [self layoutIfNeeded];
    };
    if (animated) {
        [UIView animateWithDuration:0.1f animations:updateConstraints];
    } else {
        updateConstraints();
    }
}

- (CGFloat)distanceBetweenPoint:(CGPoint)pointA andPoint:(CGPoint)pointB {
    CGFloat dx = pointA.x - pointB.x;
    CGFloat dy = pointA.y - pointB.y;
    return sqrtf(dx*dx + dy*dy);
}
                  
@end
