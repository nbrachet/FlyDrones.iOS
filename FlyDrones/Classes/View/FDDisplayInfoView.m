//
//  FDDisplayInfoView.m
//  FlyDrones
//
//  Created by Sergey Galagan on 3/11/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDDisplayInfoView.h"

#import "NSString+Datetime.h"


#pragma mark - Private interface methods

@interface FDDisplayInfoView ()

#pragma mark - Properties

@property (nonatomic, weak) IBOutlet UILabel *dateLabel;
@property (nonatomic, weak) IBOutlet UILabel *timeLabel;

@end


#pragma mark - Public interface methods

@implementation FDDisplayInfoView

#pragma mark - Instance methods

- (void)showDisplayInfo
{
    self.dateLabel.text = [NSString currentDate];
    self.timeLabel.text = [NSString currentTime];
}

#pragma mark -

@end
