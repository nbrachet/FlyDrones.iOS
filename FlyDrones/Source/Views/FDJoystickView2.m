//
//  FDJoystickView2.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/13/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDJoystickView2.h"

static CFAbsoluteTime FDJoystickView2DelayBeforeZeroingDirection = 0.5f;

typedef NS_ENUM(NSUInteger, FDJoystickView2Direction) {
    FDJoystickView2DirectionNone,
    FDJoystickView2DirectionHorizontal,
    FDJoystickView2DirectionVertical,
};

@interface FDJoystickView2 ()

@property (nonatomic, assign) CGPoint firstTouchPoint;
@property (nonatomic, assign) CGPoint prevTouchViewPosition;
@property (nonatomic, assign) BOOL isTracking;
@property (nonatomic, assign) FDJoystickView2Direction direction;
@property (nonatomic, assign) CFTimeInterval lastMovedEventTimeInterval;

@end

@implementation FDJoystickView2

#pragma mark - Public

- (void)resetPosition {
    [self resetTouchViewPosition];
}

#pragma mark - Custom Accessors

- (CGFloat)stickHorizontalValue {
    return -self.prevTouchViewPosition.x / CGRectGetMidX(self.bounds);
}

- (CGFloat)stickVerticalValue {
    return self.prevTouchViewPosition.y / CGRectGetMidY(self.bounds);
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
        if (self.isTracking == NO && CGRectContainsPoint(self.touchView.frame, touchPoint)) {
            self.isTracking = YES;
            self.firstTouchPoint = [self convertPoint:touchPoint toView:self.touchView];
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.isTracking == NO) {
        return;
    }
    
    CGPoint viewMiddlePoint = CGPointMake(CGRectGetMidX(self.bounds),
                                          CGRectGetMidY(self.bounds));
    CGPoint touchViewMiddlePoint = CGPointMake(CGRectGetMidX(self.touchView.bounds),
                                              CGRectGetMidY(self.touchView.bounds));
    for (UITouch *touch in touches) {
        CGPoint touchPoint = [touch locationInView:self];
        CGPoint previousTouchPoint = [touch previousLocationInView:self];
        
        CGSize firstTouchDelta = CGSizeMake(self.firstTouchPoint.x - touchViewMiddlePoint.x,
                                            self.firstTouchPoint.y - touchViewMiddlePoint.y);
        CGPoint touchViewCenterPoint = CGPointMake(viewMiddlePoint.x - touchPoint.x + firstTouchDelta.width,
                                                   viewMiddlePoint.y - touchPoint.y + firstTouchDelta.height);
        
        CGPoint convertedTouchViewCenterPoint = CGPointMake(touchViewCenterPoint.x + viewMiddlePoint.x,
                                                            touchViewCenterPoint.y + viewMiddlePoint.y);

        //Limit movement inside view

        CGFloat distance = [self distanceBetweenPoint:viewMiddlePoint
                                             andPoint:convertedTouchViewCenterPoint];
        CGFloat radius = viewMiddlePoint.x - CGRectGetMidX(self.touchView.bounds);
        if (distance > radius) {
            CGFloat angle = -atan2f(-touchViewCenterPoint.x, -touchViewCenterPoint.y) - M_PI_2;
            touchViewCenterPoint = CGPointMake(cos(angle) * radius,
                                               sin(angle) * radius);
        }
        
        //Resetting direction, if the delay is more than X second

        CFTimeInterval currentTime = CACurrentMediaTime();
        CFTimeInterval delay = currentTime - self.lastMovedEventTimeInterval;
        if (delay > FDJoystickView2DelayBeforeZeroingDirection) {
//NSLog(@"delay = %g: reset", delay);
            self.direction = FDJoystickView2DirectionNone;
        }
//        self.lastMovedEventTimeInterval = currentTime;

            CGFloat horizontalDifference = MAX(touchPoint.x, previousTouchPoint.x) - MIN(touchPoint.x, previousTouchPoint.x);
            CGFloat verticalDifference = MAX(touchPoint.y, previousTouchPoint.y) - MIN(touchPoint.y, previousTouchPoint.y);
            FDJoystickView2Direction direction;
            if (horizontalDifference > verticalDifference) {
                direction = FDJoystickView2DirectionHorizontal;
            } else {
                direction = FDJoystickView2DirectionVertical;
            }
            if (self.direction == FDJoystickView2DirectionNone) {
                self.direction = direction;
            }
            if (self.direction != direction) {
//NSLog(@"delay = %g: direction (%d) != self.direction (%d)", delay, direction, self.direction);
            }
            else {
//NSLog(@"delay = %g: self.direction (%d)", delay, self.direction);
                switch (self.direction) {
                    case FDJoystickView2DirectionHorizontal:
                        touchViewCenterPoint.y = self.prevTouchViewPosition.y;
                        break;
                    case FDJoystickView2DirectionVertical:
                        touchViewCenterPoint.x = self.prevTouchViewPosition.x;
                        break;
                    default:
                        break;
                }
                self.lastMovedEventTimeInterval = currentTime;
            }

#if 0
        if (self.direction == FDJoystickView2DirectionNone) {
            CGFloat horizontalDifference = MAX(touchPoint.x, previousTouchPoint.x) - MIN(touchPoint.x, previousTouchPoint.x);
            CGFloat verticalDifference = MAX(touchPoint.y, previousTouchPoint.y) - MIN(touchPoint.y, previousTouchPoint.y);
            if (horizontalDifference > verticalDifference) {
                self.direction = FDJoystickView2DirectionHorizontal;
            } else {
                self.direction = FDJoystickView2DirectionVertical;
            }
        }
#endif


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
    self.direction = FDJoystickView2DirectionNone;
    self.lastMovedEventTimeInterval = 0;
    
    CGPoint originPoint = CGPointZero;
//    originPoint.x = self.prevTouchViewPosition.x;
//    originPoint.y = self.prevTouchViewPosition.y;

    [self updateTouchViewPosition:originPoint animated:YES];
}

- (void)updateTouchViewPosition:(CGPoint)center animated:(BOOL)animated {
    if (CGPointEqualToPoint(self.prevTouchViewPosition, center)) {
        return;
    }
    
    self.prevTouchViewPosition = center;

    void(^updateConstraints)() = ^() {
        self.centerXLayoutConstraint.constant = - center.x;
        self.centerYLayoutConstraint.constant = - center.y;
        [self layoutIfNeeded];
    };
    if (animated) {
        [UIView animateWithDuration:0.1f animations:updateConstraints];
    } else {
        updateConstraints();
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat diameter = self.touchView.bounds.size.width;
    CGFloat radius = diameter / 2.0f;

    CGFloat width = self.throttleImageView.bounds.size.width;
    CGFloat height = self.throttleImageView.bounds.size.height;

    CGFloat centerX = width / 2.0f + self.centerXLayoutConstraint.constant;
    if (centerX > width - diameter)
        centerX = width - diameter;
    else if (centerX < diameter)
        centerX = diameter;
    CGFloat centerY = height / 2.0f + self.centerYLayoutConstraint.constant;
    if (centerY > height - diameter)
        centerY = height - diameter;
    else if (centerY < diameter)
        centerY = diameter;

    UIGraphicsBeginImageContext(self.throttleImageView.bounds.size);
        CGContextRef context = UIGraphicsGetCurrentContext();

        CGContextClearRect(context, self.throttleImageView.bounds);

        CGContextSetLineWidth(context, self.lineWidth);
        CGContextSetStrokeColorWithColor(context, self.color.CGColor);

        CGContextBeginPath(context);
            // bottom
            CGContextMoveToPoint(context, centerX - radius, centerY + radius);
            CGContextAddLineToPoint(context, centerX - radius, height - radius);
            CGContextAddArc(context,
                            centerX, height - radius,   // center
                            radius,                     // radius
                            M_PI,                       // start angle
                            0,                          // end angle
                            1);                         // clockwise
            CGContextAddLineToPoint(context, centerX + radius, centerY + radius);

//            UIImage *landing = [UIImage imageNamed:@"Landing"];
            [self.landingImage drawInRect:CGRectMake(centerX - radius / 2,      // x
                                                     height - 3 * radius / 2,   // y
                                                     radius,                    // width
                                                     radius)];                  // height

            // right
            CGContextAddLineToPoint(context, width - radius, centerY + radius);
            CGContextAddArc(context,
                            width - radius, centerY,    // center
                            radius,                     // radius
                            M_PI_2,                     // start angle
                            -M_PI_2,                    // end angle
                            1);                         // clockwise
            CGContextAddLineToPoint(context, centerX + radius, centerY - radius);

            [self.rightImage drawInRect:CGRectMake(width - 3 * radius / 2,  // x
                                                   centerY - radius / 2,    // y
                                                   radius,                  // width
                                                   radius)];                // height

            // top
            CGContextAddLineToPoint(context, centerX + radius, radius);
            CGContextAddArc(context,
                            centerX, radius,            // center
                            radius,                     // radius
                            0,                          // start angle
                            M_PI,                       // end angle
                            1);                         // clockwise
            CGContextAddLineToPoint(context, centerX - radius, centerY - radius);

//            UIImage *takeoff = [UIImage imageNamed:@"Takeoff"];
            [self.takeoffImage drawInRect:CGRectMake(centerX - radius / 2,  // x
                                                     radius / 2,            // y
                                                     radius,                // width
                                                     radius)];              // height

            // left
            CGContextAddLineToPoint(context, radius, centerY - radius);
            CGContextAddArc(context,
                            radius, centerY,            // center
                            radius,                     // radius
                            -M_PI_2,                    // start angle
                            M_PI_2,                     // end angle
                            1);                         // clockwise
            CGContextClosePath(context);

            [self.leftImage drawInRect:CGRectMake(radius / 2,  // x
                                                   centerY - radius / 2,    // y
                                                   radius,                  // width
                                                   radius)];                // height

        CGContextStrokePath(context);

        self.throttleImageView.image = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();
}

- (CGFloat)distanceBetweenPoint:(CGPoint)pointA andPoint:(CGPoint)pointB {
    CGFloat dx = pointA.x - pointB.x;
    CGFloat dy = pointA.y - pointB.y;
    return sqrtf(dx*dx + dy*dy);
}
                  
@end
