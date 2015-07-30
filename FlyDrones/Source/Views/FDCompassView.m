//
//  FDCompassView.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDCompassView.h"

@implementation FDCompassView

#pragma mark - Custom Accessors

- (void)setHeading:(CGFloat)heading {
    if (_heading == heading || heading < 0 || heading > 360) {
        return;
    }
    _heading = heading;
    
    if (self.enabled) {
        [self redraw];
    }
}

#pragma mark - Overridden methods

- (void)defaultInitialization {
    [super defaultInitialization];
    
    if (self.numbersColor == nil) {
        self.numbersColor = [UIColor whiteColor];
    }
    
    if (self.lettersColor == nil) {
        self.lettersColor = [UIColor whiteColor];
    }
}

- (UIImage *)backgroundImageWithSize:(CGSize)size {
    const float oneDegX = 1.0f / 75 * size.width;
    CGPoint centerPoint = CGPointMake(size.width / 2.0f, size.height / 2.0f);
    
    const float tickBase = centerPoint.y + size.height / 2.0f - size.height / 20.0f;
    const float tickMajorHeight = size.height / 3.0f;
    const float tickMinorHeight = size.height / 6.0f;
    const float tickWidth = size.width * 0.01f;
    const float chevronSide = size.width * 0.018f;
    const float fontSize = size.height * 0.6f;
    
    UIGraphicsBeginImageContext(size);

    CGContextRef context = UIGraphicsGetCurrentContext();
    //Fill Background
    CGContextClearRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    CGContextSetFillColorWithColor(context, [self.backgroundColor CGColor]);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));

    NSDictionary *numbersTextAttributes = @{NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Medium" size:fontSize - 3],
                                            NSForegroundColorAttributeName: self.numbersColor};
    NSDictionary *lettersTextAttributes = @{NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Medium" size:fontSize],
                                            NSForegroundColorAttributeName: self.lettersColor};
    CGContextSetLineWidth(context, tickWidth);
    
    CGFloat startAngle = ((NSInteger)self.heading - 180) /5 * 5;
    const float startX = centerPoint.x + (startAngle - self.heading) * oneDegX;
    NSInteger angle = (startAngle < 0) ? startAngle += 360 : startAngle;
    
    for (int i = 0; i < 360; i += 5, angle = (angle + 5) % 360) {
        CGContextSetStrokeColorWithColor(context, [self.numbersColor CGColor]);
        CGContextSetFillColorWithColor(context, [self.numbersColor CGColor]);
        // Find the x position of this tick
        const float x = startX + i * oneDegX;
        if (x < -20 || x > size.width + 20) {
            continue;
        }
        
        // Draw the tick
        CGContextBeginPath(context);
        const float y = (angle % 10 == 0) ? tickBase - tickMajorHeight : tickBase - tickMinorHeight;
        CGContextMoveToPoint(context, x, y);
        CGContextAddLineToPoint (context, x, tickBase);
        CGContextStrokePath(context);
        CGContextBeginPath(context);
        CGContextAddArc(context, x, y, tickWidth / 2.0f, 0, M_PI * 2.0f, 1);
        CGContextFillPath(context);
        
        // Draw the "numbers"
        if (angle % 30 == 0) {
            NSMutableAttributedString *attributedText;
            CGSize textSize;
            if (angle % 90 == 0) {
                // Compass points
                NSArray *array = @[@"N", @"E", @"S", @"W"];
                attributedText = [[NSMutableAttributedString alloc] initWithString:array[angle / 90] attributes:lettersTextAttributes];
                textSize = [attributedText size];
            } else {
                // Plain old number
                NSString *numberString = [NSString stringWithFormat:@"%ld", (long)angle];
                attributedText = [[NSMutableAttributedString alloc] initWithString:numberString attributes:numbersTextAttributes];
                textSize = [attributedText size];
                [attributedText appendAttributedString:[[NSAttributedString alloc] initWithString:@"°" attributes:numbersTextAttributes]];
            }
            
            [attributedText drawAtPoint:CGPointMake(x - textSize.width / 2.0f, 0)];
        }
    }

    CGRect gaugeBoundary = CGRectMake(centerPoint.x - size.width / 2.0f,
                                      centerPoint.y - size.height / 2.0f,
                                      size.width,
                                      size.height);
    
    // Draw bearing chevron
    if (self.bearingChevronColor != nil) {
        float chevronX = centerPoint.x;
        if (chevronX > centerPoint.x + size.width / 2.0f) {
            chevronX = centerPoint.x + size.width / 2.0f;
        }
        if (chevronX < centerPoint.x - size.width / 2.0f) {
            chevronX = centerPoint.x - size.width / 2.0f;
        }
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, chevronX, centerPoint.y + size.height / 2.0f - chevronSide);
        CGContextAddLineToPoint(context, chevronX + chevronSide, centerPoint.y + size.height / 2.0f);
        CGContextAddLineToPoint(context, chevronX - chevronSide, centerPoint.y + size.height / 2.0f);
        CGContextAddLineToPoint(context, chevronX, centerPoint.y + size.height / 2.0f - chevronSide);
        CGContextSetLineWidth(context, tickWidth / 9.0f);
        CGContextSetFillColorWithColor(context, self.bearingChevronColor.CGColor);
        CGContextSetStrokeColorWithColor(context, ((self.bearingChevronBorderColor != nil) ? self.bearingChevronBorderColor.CGColor : self.bearingChevronColor.CGColor));
        CGContextDrawPath(context, kCGPathFillStroke);
    }
    
    // Draw black over entire rect, clipping inside of the gauge boundary
    // http://cocoawithlove.com/2010/05/5-ways-to-draw-2d-shape-with-hole-in.html
    CGContextSaveGState(context);
    CGContextAddRect(context, CGContextGetClipBoundingBox(context));
    CGContextAddRect(context, gaugeBoundary);
    CGContextClosePath(context);
    CGContextEOClip(context);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddRect(context, CGContextGetClipBoundingBox(context));
    CGContextSetFillColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
    
    // Draw gauge boundary
    if (self.borderColor != nil && self.borderWidth > 0) {
        CGContextBeginPath(context);
        CGContextAddRect(context, gaugeBoundary);
        CGContextSetStrokeColorWithColor(context, [[UIColor grayColor] CGColor]);
        CGContextSetLineWidth(context, self.borderWidth);
        CGContextStrokePath(context);
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
