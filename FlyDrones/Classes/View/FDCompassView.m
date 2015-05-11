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
    [self redraw];
}

- (void)setNavigationBearing:(CGFloat)navigationBearing {
    if (_navigationBearing == navigationBearing  || navigationBearing < 0 || navigationBearing > 360) {
        return;
    }
    
    _navigationBearing = navigationBearing;
    [self redraw];
}

#pragma mark - Lifecycle

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    const float oneDegX = 1.0f / 75 * CGRectGetWidth(rect);
    CGPoint centerPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    
    const float tickBase = centerPoint.y + CGRectGetHeight(rect) / 2.0f - CGRectGetHeight(rect) / 20.0f;
    const float tickMajorHeight = CGRectGetHeight(rect) / 3.0f;
    const float tickMinorHeight = CGRectGetHeight(rect) / 6.0f;
    const float tickWidth = CGRectGetWidth(rect) * 0.01f;
    const float chevronSide = CGRectGetWidth(rect) * 0.018f;
    const float fontSize = CGRectGetHeight(rect) * 0.6f;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //Fill Background
    CGContextClearRect(context, rect);
    CGContextSetFillColorWithColor(context, [self.backgroundColor CGColor]);
    CGContextFillRect(context, rect);
    
    // Draw text and tick lines
    // Draw 360 degrees, centered on current position.
    // An aircraft compass has:
    //   * small tick every 5 deg
    //   * large tick every 10 deg
    //   * number every 30 deg, with N/S/W/E replacing their respective numbers
    
    if (self.numbersColor == nil) {
        self.numbersColor = [UIColor blackColor];
    }
    
    if (self.lettersColor == nil) {
        self.lettersColor = [UIColor blackColor];
    }
    
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
        if (x < -20 || x > CGRectGetWidth(rect) + 20) {
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
    
    // Draw centre pointer
    CGContextSaveGState(context);
    CGContextSetShadow (context, CGSizeMake (tickWidth, tickWidth), 2.5f);
    for (NSUInteger i = 0; i < 2; i++) {
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, centerPoint.x, centerPoint.y - CGRectGetHeight(rect) / 2.0f);
        CGContextAddLineToPoint(context, centerPoint.x, centerPoint.y + CGRectGetHeight(rect) / 2.0f);
        if (i == 0) {
            CGContextSetLineWidth(context, tickWidth);
            CGContextSetStrokeColorWithColor(context, self.centerPointerBorderColor.CGColor);
        } else {
            CGContextSetLineWidth(context, tickWidth / 3.0f);
            CGContextSetStrokeColorWithColor(context, self.centerPointerColor.CGColor);
        }
        CGContextStrokePath(context);
    }
    CGContextRestoreGState(context);
    
    
    //Draw gradient
    if (self.firstGradientColor != nil || self.secondGradientColor != nil) {
        NSArray *colors;
        if (self.firstGradientColor != nil && self.secondGradientColor != nil) {
            colors = @[(__bridge id)self.firstGradientColor.CGColor,
                      (__bridge id)self.secondGradientColor.CGColor];
        } else if (self.firstGradientColor != nil) {
            colors = @[(__bridge id)self.firstGradientColor.CGColor,
                      (__bridge id)[UIColor clearColor].CGColor];
        } else {
            colors = @[(__bridge id)[UIColor clearColor].CGColor,
                      (__bridge id)self.secondGradientColor.CGColor];
        }
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGFloat locations[] = {0.0, 1.0};
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef) colors, locations);
        for (int i = 0; i < 2; i++) {
            CGRect subRect = CGRectMake(((i == 0) ? centerPoint.x - CGRectGetWidth(rect)/2 : centerPoint.x + CGRectGetWidth(rect)/6),
                                        centerPoint.y - CGRectGetHeight(rect)/2,
                                        CGRectGetWidth(rect)/3,
                                        CGRectGetHeight(rect));
            CGPoint startPoint = CGPointMake(CGRectGetMinX(subRect), CGRectGetMinY(subRect));
            CGPoint endPoint = CGPointMake(CGRectGetMaxX(subRect), CGRectGetMinY(subRect));
            if (i == 0) {
                CGPoint tmp = startPoint;
                startPoint = endPoint;
                endPoint = tmp;
            }
            CGContextSaveGState(context);
            CGContextAddRect(context, subRect);
            CGContextClip(context);
            CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
            CGContextRestoreGState(context);
        }
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
    }
    
    CGRect gaugeBoundary = CGRectMake(centerPoint.x - CGRectGetWidth(rect) / 2.0f,
                                      centerPoint.y - CGRectGetHeight(rect) / 2.0f,
                                      CGRectGetWidth(rect),
                                      CGRectGetHeight(rect));
    
    // Draw bearing chevron
    if (self.bearingChevronColor != nil) {
        float bearingError = (self.navigationBearing - self.heading);
        if (bearingError > 180) {
            bearingError -= 360;
        }
        if (bearingError < -180) {
            bearingError += 360;
        }
        
        float chevronX = centerPoint.x + bearingError * oneDegX;
        if (chevronX > centerPoint.x + CGRectGetWidth(rect) / 2.0f) {
            chevronX = centerPoint.x + CGRectGetWidth(rect) / 2.0f;
        }
        if (chevronX < centerPoint.x - CGRectGetWidth(rect) / 2.0f) {
            chevronX = centerPoint.x - CGRectGetWidth(rect) / 2.0f;
        }
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, chevronX, centerPoint.y + CGRectGetHeight(rect) / 2.0f - chevronSide);
        CGContextAddLineToPoint(context, chevronX + chevronSide, centerPoint.y + CGRectGetHeight(rect) / 2.0f);
        CGContextAddLineToPoint(context, chevronX - chevronSide, centerPoint.y + CGRectGetHeight(rect) / 2.0f);
        CGContextAddLineToPoint(context, chevronX, centerPoint.y + CGRectGetHeight(rect) / 2.0f - chevronSide);
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
}

#pragma mark - Private

- (void)redraw {
    [self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:YES];
}
//
//- (float)getTextWidth:(NSString *)text withContext:(CGContextRef)ctx {
//    CGContextSetTextDrawingMode(ctx, kCGTextInvisible);
//    CGContextSetTextPosition(ctx, 0, 0);
//    CGContextShowText(ctx, [text cStringUsingEncoding:NSASCIIStringEncoding], text.length);
//    CGPoint newPos = CGContextGetTextPosition(ctx);
//    return newPos.x;
//}
@end
