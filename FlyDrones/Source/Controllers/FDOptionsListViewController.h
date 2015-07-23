//
//  FDOptionsListViewController.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 7/23/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FDOptionsListViewController;

@protocol FDOptionsListViewControllerDelegate <NSObject>

@optional
- (NSArray *)optionsNamesForOptionsListViewController:(FDOptionsListViewController *)optionsListViewController;
- (void)optionsListViewController:(FDOptionsListViewController *)optionsListViewController didSelectOptionForIndex:(NSUInteger)optionIndex;

@end

@interface FDOptionsListViewController : UIViewController

@property (nonatomic, weak) id<FDOptionsListViewControllerDelegate> delegate;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSArray *optionsNames;

- (void)updateOptionsNames;

@end
