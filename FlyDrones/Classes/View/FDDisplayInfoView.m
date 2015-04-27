//
//  FDDisplayInfoView.m
//  FlyDrones
//
//  Created by Sergey Galagan on 3/11/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDDisplayInfoView.h"
#import "NSString+Datetime.h"

#pragma mark - Private interface methods

@interface FDDisplayInfoView ()

@property (nonatomic, weak) IBOutlet UILabel *dateLabel;
@property (nonatomic, weak) IBOutlet UILabel *timeLabel;
@property (nonatomic, strong) NSTimer *timer;

@end

@implementation FDDisplayInfoView

#pragma mark - Public

- (void)showDisplayInfo {
    [self runTimer];
}

- (void)hideDisplayInfo {
    self.dateLabel.text = @"";
    self.timeLabel.text = @"";
    
    [self.timer invalidate];
    self.timer = nil;
}

#pragma mark - Private

- (void)runTimer {
    if (self.timer != nil) {
        [self.timer invalidate];
    }
    self.timer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                          interval:1.0f
                                            target:self
                                          selector:@selector(updateDateTime)
                                          userInfo:nil
                                           repeats:YES];
    NSRunLoop *runner = [NSRunLoop currentRunLoop];
    [runner addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)updateDateTime {
    self.dateLabel.text = [NSString currentDate];
    self.timeLabel.text = [NSString currentTime];
}

@end
