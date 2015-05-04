//
//  FDDashboardViewController.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDDashboardViewController : UIViewController

@property (nonatomic, copy) NSString *hostForConnection;
@property (nonatomic, assign) NSUInteger portForConnection;
@property (nonatomic, assign) NSUInteger portForReceived;

@property (nonatomic, copy) NSString *hostForTCPConnection;
@property (nonatomic, assign) NSUInteger portForTCPConnection;

@end
