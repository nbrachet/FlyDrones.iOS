//
//  FDVerticalScaleView.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 7/20/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import "FDVerticalScaleView.h"

@implementation FDVerticalScaleView

#pragma mark - Custom Accessors

- (void)setValue:(CGFloat)value {
    if (_value == value) {
        return;
    }
    _value = value;
    
    if (self.enabled) {
        [self redraw];
    }
}

- (void)setTargetDelta:(float)targetDelta {
    if (_targetDelta == targetDelta) {
        return;
    }
    _targetDelta = targetDelta;
    
    if (self.enabled) {
        [self redraw];
    }
}

#pragma mark - Overridden methods

- (void)defaultInitialization {
    [super defaultInitialization];
    
    if (self.textColor == nil) {
        self.textColor = [UIColor whiteColor];
    }
    
    if (self.labelFillColor == nil) {
        self.labelFillColor = [UIColor lightGrayColor];
    }
    
    if (self.labelStrokeColor == nil) {
        self.labelStrokeColor = [UIColor darkGrayColor];
    }
    
    if (self.targetDeltaChevronColor == nil) {
        self.targetDeltaChevronColor = [UIColor orangeColor];
    }
}

- (UIImage *)backgroundImageWithSize:(CGSize)size {
    const CGRect bounds = CGRectMake(0.0f, 0.0f, size.width, size.height);
    const float horizontalInsetPercent = 0.0f;
    const float verticalInsetPercent = 0.0f;
    
    const float w = (1.0f - 2 * horizontalInsetPercent) * size.width;
    const float h = (1.0f - 2 * verticalInsetPercent) * size.height;
    const float oneScaleY = h/_scale;
    
    const CGPoint c = CGPointMake(CGRectGetMidX(bounds) , CGRectGetMidY(bounds));
    
    const float tickMajorWidth = w/4;
    const float tickMinorWidth = w/6;
    const float tickHeight = roundf(0.005 * h);
    const float tickBase = c.x - w/2 + tickHeight/2;
    const float targetChevronSide = 0.018 * h;
    const float fontSizeSmall = 0.28 * w;
    const float fontSizeLarge = 1.16 * fontSizeSmall;
    
    UIGraphicsBeginImageContext(size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    //Fill Background
    CGContextClearRect(context, bounds);
    CGContextSetFillColorWithColor(context, [self.backgroundColor CGColor]);
    CGContextFillRect(context, bounds);

    NSDictionary *smallTextAttributes = @{NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Medium" size:fontSizeSmall],
                                          NSForegroundColorAttributeName: self.textColor};
    NSDictionary *largeTextAttributes = @{NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Medium" size:fontSizeLarge],
                                          NSForegroundColorAttributeName: self.textColor};
    
    CGContextSetStrokeColorWithColor(context, [self.textColor CGColor]);
    CGContextSetFillColorWithColor(context, [self.textColor CGColor]);
    CGContextSetLineWidth(context, tickHeight);
    
    // Draw scale centred on current point
    const float step = self.scale/10;
    const float startValue = floor((self.value - self.scale)/step) * step;
    float tickVal = startValue;
    for (NSUInteger i = 0; i < 40; i++, tickVal = startValue + i*step/2) {
        // Find the y position of this tick
        const float y = c.y - (tickVal - self.value) * oneScaleY;
        if (y < -20 || y > h + 20) {
            continue;
        }
        
        if (ABS(self.value - tickVal) < step / 3.0f) {
            continue;
        }
        
        // Draw the tick
        CGContextBeginPath(context);
        const float x = (i % 2 == 0) ? tickBase+tickMajorWidth : tickBase+tickMinorWidth;
        CGContextMoveToPoint(context, x, y);
        CGContextAddLineToPoint (context, tickBase, y);
        CGContextStrokePath(context);
        CGContextBeginPath(context);
        CGContextAddArc(context, x, y, tickHeight/2, 0, 2*M_PI, 1);
        CGContextFillPath(context);
        
        // Draw the "numbers"
        if (i % 2 == 0) {
            NSString *labelString = [NSString stringWithFormat:@"%.0f", tickVal];
            NSAttributedString *labelAttributedString = [[NSAttributedString alloc] initWithString:labelString
                                                                                        attributes:smallTextAttributes];
            CGSize labelAttributedStringSize = [labelAttributedString size];

            [labelAttributedString drawAtPoint:CGPointMake(x + tickMinorWidth/2,
                                                           y - labelAttributedStringSize.height / 2.0f - tickHeight / 2.0f)];
        }
    }

    
    // Draw centre pointer over the top
    CGContextSetFillColorWithColor(context, [self.labelFillColor CGColor]);
    CGContextSetStrokeColorWithColor(context, [self.labelStrokeColor CGColor]);
    
    CGContextBeginPath(context);
    CGContextAddRect(context, CGRectMake(c.x-w/2, c.y-fontSizeLarge / 2, w, fontSizeLarge));
    CGContextDrawPath(context, kCGPathFillStroke);

    NSString *valueString;
    if (self.value >= 30) {
        valueString = [NSString stringWithFormat:@"%.0f%@", self.value, self.title];
    } else {
        valueString = [NSString stringWithFormat:@"%.1f%@", self.value, self.title];
    }
    NSAttributedString *valueAttributedString = [[NSAttributedString alloc] initWithString:valueString
                                                                                attributes:largeTextAttributes];
    CGSize labelAttributedStringSize = [valueAttributedString size];
    [valueAttributedString drawAtPoint:CGPointMake((size.width - labelAttributedStringSize.width) / 2,
                                                   c.y - labelAttributedStringSize.height / 2.0f - tickHeight / 2.0f)];
    
    // Draw target chevron
    if (self.showTargetDelta && (self.targetDeltaChevronColor != nil)) {
        float targetChevronY = c.y - self.targetDelta * oneScaleY;
        if (targetChevronY > c.y + h/2) {
            targetChevronY = c.y + h/2;
        }
        if (targetChevronY < c.y - h/2) {
            targetChevronY = c.y - h/2;
        }
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, c.x + w/2 - targetChevronSide, targetChevronY);
        CGContextAddLineToPoint(context, c.x + w/2, targetChevronY + targetChevronSide);
        CGContextAddLineToPoint(context, c.x + w/2, targetChevronY - targetChevronSide);
        CGContextAddLineToPoint(context, c.x + w/2 - targetChevronSide, targetChevronY);
        CGContextSetLineWidth(context, tickHeight/3);
        CGContextSetFillColorWithColor(context, [self.targetDeltaChevronColor CGColor]);
        CGContextSetStrokeColorWithColor(context, [self.targetDeltaChevronColor CGColor]);
        CGContextDrawPath(context, kCGPathFillStroke);
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
