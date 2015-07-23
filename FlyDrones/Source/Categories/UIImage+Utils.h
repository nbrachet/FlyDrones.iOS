//
//  UIImage+Utils.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/27/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Utils)

- (UIImage *)convertToGrayscale;

- (UIImage *)maskedWithImage:(CGImageRef)maskImageRef;

@end
