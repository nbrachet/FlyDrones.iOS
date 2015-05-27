//
//  FDCompassView.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDCompassView : UIView

@property (nonatomic, copy) IBInspectable UIColor *numbersColor;
@property (nonatomic, copy) IBInspectable UIColor *lettersColor;
@property (nonatomic, copy) IBInspectable UIColor *centerPointerColor;
@property (nonatomic, copy) IBInspectable UIColor *centerPointerBorderColor;
@property (nonatomic, copy) IBInspectable UIColor *bearingChevronColor;
@property (nonatomic, copy) IBInspectable UIColor *bearingChevronBorderColor;
@property (nonatomic, copy) IBInspectable UIColor *firstGradientColor;
@property (nonatomic, copy) IBInspectable UIColor *secondGradientColor;
@property (nonatomic, assign) IBInspectable CGFloat borderWidth;
@property (nonatomic, copy) IBInspectable UIColor *borderColor;

@property (nonatomic, assign) IBInspectable CGFloat heading;
@property (nonatomic, assign) IBInspectable CGFloat navigationBearing;
@property (nonatomic, assign) BOOL enabled;

@end
