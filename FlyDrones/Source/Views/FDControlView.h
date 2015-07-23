//
//  FDControlView.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 7/23/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDControlView : UIView

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, assign) IBInspectable BOOL enabled;
@property (nonatomic, assign,  getter=isSmoothBoundaries) IBInspectable BOOL smoothBoundaries;
@property (nonatomic, copy) IBInspectable UIImage *maskImage;

- (UIImage *)backgroundImageWithSize:(CGSize)size;
- (void)redraw;

@end
