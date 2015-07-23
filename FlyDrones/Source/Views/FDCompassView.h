//
//  FDCompassView.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FDControlView.h"

@interface FDCompassView : FDControlView

@property (nonatomic, copy) IBInspectable UIColor *numbersColor;
@property (nonatomic, copy) IBInspectable UIColor *lettersColor;
@property (nonatomic, copy) IBInspectable UIColor *centerPointerColor;
@property (nonatomic, copy) IBInspectable UIColor *centerPointerBorderColor;
@property (nonatomic, copy) IBInspectable UIColor *bearingChevronColor;
@property (nonatomic, copy) IBInspectable UIColor *bearingChevronBorderColor;
@property (nonatomic, assign) IBInspectable CGFloat borderWidth;
@property (nonatomic, copy) IBInspectable UIColor *borderColor;

@property (nonatomic, assign) IBInspectable CGFloat heading;
@property (nonatomic, assign) IBInspectable CGFloat navigationBearing;

@end
