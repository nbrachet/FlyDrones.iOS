//
//  UIView+Utils.h
//  FlyDrones
//
//  Created by Sergey Galagan on 2/5/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//


@interface UIView (Utils)

#pragma mark - Frames

- (CGFloat)width;
- (CGFloat)height;
- (void)updateHeight:(CGFloat)height;
- (void)updateWidth:(CGFloat)width;
- (void)offsetByX:(CGFloat)offsetValue;
- (void)offsetByY:(CGFloat)offsetValue;

#pragma mark -

@end
