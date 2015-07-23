//
//  FDVerticalScaleView.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 7/20/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FDControlView.h"

@interface FDVerticalScaleView : FDControlView

@property (nonatomic, copy) IBInspectable UIColor *textColor;
@property (nonatomic, copy) IBInspectable UIColor *labelStrokeColor;
@property (nonatomic, copy) IBInspectable UIColor *labelFillColor;
@property (nonatomic, copy) IBInspectable NSString *title;
@property (nonatomic, assign) IBInspectable NSInteger scale;
@property (nonatomic, assign) IBInspectable CGFloat value;
@property (nonatomic, assign) IBInspectable BOOL showTargetDelta;
@property (nonatomic, assign) IBInspectable float targetDelta;

@end
