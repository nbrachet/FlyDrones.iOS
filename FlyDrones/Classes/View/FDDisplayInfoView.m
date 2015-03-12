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

@property (nonatomic, strong) NSTimer *timer;

@end


#pragma mark - Public interface methods

@implementation FDDisplayInfoView

#pragma mark - Instance methods

- (void)showDisplayInfo
{
    __block FDDisplayInfoView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf runTimer];
    });
}

- (void)hideDisplayInfo
{
    self.dateLabel.text = @"";
    self.timeLabel.text = @"";
    
    [self.timer invalidate];
    self.timer = nil;
}

- (void)runTimer
{
    self.timer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                          interval:1
                                            target:self
                                          selector:@selector(updateDateTime)
                                          userInfo:nil
                                           repeats:YES];
    NSRunLoop *runner = [NSRunLoop currentRunLoop];
    [runner addTimer:self.timer forMode: NSDefaultRunLoopMode];
}

- (void)updateDateTime
{
    self.dateLabel.text = [NSString currentDate];
    self.timeLabel.text = [NSString currentTime];
}

#pragma mark -

@end
