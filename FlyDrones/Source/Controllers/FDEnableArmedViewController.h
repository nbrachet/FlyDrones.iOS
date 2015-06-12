//
//  FDEnableArmedViewController.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/28/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol FDEnableArmedViewControllerDelegate <NSObject>

@optional
- (void)didEnableArmedStatus:(BOOL)armed;

@end

@interface FDEnableArmedViewController : UIViewController

@property (nonatomic, weak) id<FDEnableArmedViewControllerDelegate> delegate;

@end
