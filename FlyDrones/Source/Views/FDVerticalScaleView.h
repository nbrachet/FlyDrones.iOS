//
//  FDVerticalScaleView.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 7/20/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDVerticalScaleView : UIView

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, copy) IBInspectable UIColor *textColor;
@property (nonatomic, copy) IBInspectable UIColor *labelStrokeColor;
@property (nonatomic, copy) IBInspectable UIColor *labelFillColor;

@property (nonatomic, assign) BOOL enabled;


@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) NSInteger scale;
@property (nonatomic, assign) CGFloat value;

@property (nonatomic, assign) BOOL showTargetDelta;
@property (nonatomic, assign) float targetDelta;

@end
