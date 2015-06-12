//
//  FDCustomModeViewController.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/28/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FDDroneStatus.h"

@protocol FDCustomModeViewControllerDelegate <NSObject>

@optional
- (void)didSelectNewMode:(FDAutoPilotMode)mode;

@end

@interface FDCustomModeViewController : UIViewController

@property (nonatomic, weak) id<FDCustomModeViewControllerDelegate> delegate;

@end
