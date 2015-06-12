//
//  FDBatteryStatusViewController.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDBatteryStatusViewController : UIViewController

@property (nonatomic, weak) IBOutlet UILabel *batteryRemainingLabel;
@property (nonatomic, weak) IBOutlet UILabel *batteryVoltageLabel;
@property (nonatomic, weak) IBOutlet UILabel *batteryAmperageLabel;

@end
