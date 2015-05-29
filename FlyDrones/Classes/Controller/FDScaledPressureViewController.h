//
//  FDScaledPressureViewController.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/11/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDScaledPressureViewController : UIViewController

@property (nonatomic, weak) IBOutlet UILabel *absolutePressureLabel;
@property (nonatomic, weak) IBOutlet UILabel *differentialPressureLabel;

@end
