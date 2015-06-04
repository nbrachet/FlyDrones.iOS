//
//  FDBatteryButton.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDBatteryButton : UIControl

@property (nonatomic, weak) IBOutlet UIImageView *imageView;

@property (nonatomic, copy) IBInspectable UIImage *notAvailableBatteryImage;    //  -1
@property (nonatomic, copy) IBInspectable UIImage *fullBatteryImage;            //  > 0.8f
@property (nonatomic, copy) IBInspectable UIImage *highBatteryImage;            //  <= 0.8f
@property (nonatomic, copy) IBInspectable UIImage *mediumBatteryImage;          //  <= 0.6f
@property (nonatomic, copy) IBInspectable UIImage *lowBatteryImage;             //  <= 0.35f
@property (nonatomic, copy) IBInspectable UIImage *emptyBatteryImage;           //  <= 0.1f
@property (nonatomic, assign) IBInspectable CGFloat batteryRemainingPercent;    //  0..1 or -1

@end
