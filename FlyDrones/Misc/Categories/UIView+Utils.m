//
//  UIView+Utils.m
//  FlyDrones
//
//  Created by Sergey Galagan on 2/5/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "UIView+Utils.h"


@implementation UIView (Utils)

#pragma mark - Frames

- (CGFloat)height
{
    return CGRectGetHeight(self.frame);
}

- (CGFloat)width
{
    return CGRectGetWidth(self.frame);
}

- (void)updateHeight:(CGFloat)height
{
    CGRect frame = self.frame;
    frame.size.height = height;
    self.frame = frame;
}

- (void)updateWidth:(CGFloat)width
{
    CGRect frame = self.frame;
    frame.size.width = width;
    self.frame = frame;
}

- (void)offsetByX:(CGFloat)offsetValue
{
    CGRect frame = self.frame;
    frame.origin.x = offsetValue;
    self.frame = frame;
}

- (void)offsetByY:(CGFloat)offsetValue
{
    CGRect frame = self.frame;
    frame.origin.y = offsetValue;
    self.frame = frame;
}

#pragma mark -

@end
