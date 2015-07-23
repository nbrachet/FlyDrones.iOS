//
//  FDControlView.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 7/23/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import "FDControlView.h"
#import "UIImage+Utils.h"

@interface FDControlView () {
    CGImageRef _gradientMaskRef;
}

@end

@implementation FDControlView

#pragma mark - Lifecycle

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self redraw];
}

- (void)prepareForInterfaceBuilder {
    [super prepareForInterfaceBuilder];
    
    [self redraw];
}

- (void)dealloc {
    if (_gradientMaskRef) {
        CGImageRelease(_gradientMaskRef);
    }
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    
    [self defaultInitialization];
}

#pragma mark - Custom Accessors

- (void)setEnabled:(BOOL)enabled {
    if (enabled == _enabled) {
        return;
    }
    
    _enabled = enabled;
    self.alpha = enabled ? 1.0f : 0.4f;
    
    if (enabled) {
        [self redraw];
    } else {
        UIImage *grayImage = [self.imageView.image convertToGrayscale];
        self.imageView.image = grayImage;
    }
}

#pragma mark - Public

- (void)defaultInitialization {
}

- (UIImage *)backgroundImageWithSize:(CGSize)size {
    return nil;
}

- (void)redraw {
    if (!self.enabled) {
        return;
    }
    
    CGSize backgroundImageSize = CGSizeMake(self.bounds.size.width * 2.0f,
                                            self.bounds.size.height * 2.0f);
    UIImage *backgroundImage = [self backgroundImageWithSize:backgroundImageSize];
    if (self.isSmoothBoundaries && [self gradientMask]) {
        backgroundImage = [backgroundImage maskedWithImage:[self gradientMask]];
    }
    self.imageView.image = backgroundImage;
}

#pragma mark - Private

- (CGImageRef)gradientMask {
    if (!_gradientMaskRef  && [self maskImage]) {
        CGImageRef maskRef = [[self maskImage] CGImage];
        _gradientMaskRef = CGImageMaskCreate(CGImageGetWidth(maskRef),
                                             CGImageGetHeight(maskRef),
                                             CGImageGetBitsPerComponent(maskRef),
                                             CGImageGetBitsPerPixel(maskRef),
                                             CGImageGetBytesPerRow(maskRef),
                                             CGImageGetDataProvider(maskRef),
                                             NULL,
                                             false);
    }
    return _gradientMaskRef;
}

@end
