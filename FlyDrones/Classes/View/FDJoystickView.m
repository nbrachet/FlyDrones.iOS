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
@property (nonatomic, assign) BOOL isTracking;
@property (nonatomic, strong) NSTimer *timer;

@end

@implementation FDJoystickView

#pragma mark - Lifecycle

- (void)dealloc {
    [self stopObeserveControlStates];
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    
    [self resetTouchViewPosition];
}

#pragma mark - Public

- (void)startObeserveControlStatesWithTimeInterval:(NSTimeInterval)timeInterval {
    [self stopObeserveControlStates];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:timeInterval
                                                  target:self
                                                selector:@selector(onTick:)
                                                userInfo:nil
                                                 repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)stopObeserveControlStates {
    [self.timer invalidate];
    self.timer = nil;
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
            self.state = FDJoystickViewStateNone;
            return;
        }
        
        CGPoint touchPoint = [touch locationInView:self];
        CGPoint viewMidlePoint = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        
        CGPoint touchViewMidlePoint = CGPointMake(CGRectGetMidX(self.touchImageView.bounds), CGRectGetMidY(self.touchImageView.bounds));
        CGSize firstTouchDelta = CGSizeMake(self.firstTouchPoint.x - touchViewMidlePoint.x,
                                            self.firstTouchPoint.y - touchViewMidlePoint.y);

        CGPoint touchViewCenterPoint = CGPointMake(viewMidlePoint.x - touchPoint.x + firstTouchDelta.width,
                                                   viewMidlePoint.y - touchPoint.y + firstTouchDelta.height);
        
        CGPoint convertedTouchViewCenterPoint = CGPointMake(touchViewCenterPoint.x + viewMidlePoint.x, touchViewCenterPoint.y + viewMidlePoint.y);
        CGFloat distance = [self distanceBetweenPoint:viewMidlePoint andPoint:convertedTouchViewCenterPoint];
        CGFloat angle = -atan2f(-touchViewCenterPoint.x, -touchViewCenterPoint.y) - M_PI_2;
        [self updateCurrentStateFromAngle:angle + M_PI_2];

        if (distance > viewMidlePoint.x - touchViewMidlePoint.x) {
            float radius = viewMidlePoint.x - touchViewMidlePoint.x;
            touchViewCenterPoint = CGPointMake(cos(angle) * radius , sin(angle) * radius);
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
    self.state = FDJoystickViewStateNone;
    [self updateTouchViewPosition:CGPointZero animated:YES];
}

- (void)updateTouchViewPosition:(CGPoint)center animated:(BOOL)animated {
    static CGPoint prevPosition;
    if (CGPointEqualToPoint(prevPosition, center)) {
        return;
    }
    prevPosition = center;
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

- (void)updateCurrentStateFromAngle:(CGFloat)angle {
    if (angle < M_PI_4 && angle > -M_PI_4) {
        self.state = FDJoystickViewStateDown;
    } else if (angle < M_PI_2 + M_PI_4 && angle > M_PI_4) {
        self.state = FDJoystickViewStateLeft;
    } else if (angle < -M_PI_4 && angle > -M_PI_2 - M_PI_4) {
        self.state = FDJoystickViewStateRight;
    } else {
        self.state = FDJoystickViewStateUp ;
    }
}

- (CGFloat)distanceBetweenPoint:(CGPoint)pointA andPoint:(CGPoint)pointB {
    CGFloat dx = pointA.x - pointB.x;
    CGFloat dy = pointA.y - pointB.y;
    return sqrtf(dx*dx + dy*dy);
}

- (void)onTick:(NSTimer *)timer {
    if ([self.delegate respondsToSelector:@selector(joystickViewNoticedCurrentState:)]) {
        [self.delegate joystickViewNoticedCurrentState:self.state];
    }
}
                  
@end
