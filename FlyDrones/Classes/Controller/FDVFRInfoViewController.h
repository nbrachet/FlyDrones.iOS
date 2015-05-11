//
//  FDVFRInfoViewController.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/11/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDVFRInfoViewController : UIViewController

@property (nonatomic, weak) IBOutlet UILabel *airspeedLabel;
@property (nonatomic, weak) IBOutlet UILabel *groundspeedLabel;
@property (nonatomic, weak) IBOutlet UILabel *climbRateLabel;
@property (nonatomic, weak) IBOutlet UILabel *throttleSettingLabel;

@end
