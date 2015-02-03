//
//  MainViewController.m
//  FlyDrones
//
//  Created by Sergey Galagan on 1/27/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "MainViewController.h"
#import "FDVideoStreamingController.h"

#import "FDFFmpegWrapper.h"

#import "NSBundle+Utils.h"


#pragma mark - Private interface methods

@interface MainViewController ()

#pragma mark - Properties

@property (nonatomic, strong) FDFFmpegWrapper *h264Wrapper;
@property (nonatomic, strong) FDVideoStreamingController *videoStreamingController;

@end


#pragma mark - Public interface methods

@implementation MainViewController

#pragma mark - Instance methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self performVideoController];
}


#pragma mark - Interface initialization methods

- (void)performVideoController
{
    self.videoStreamingController = [self.storyboard instantiateViewControllerWithIdentifier:NSStringFromClass([FDVideoStreamingController class])];
    self.videoStreamingController.view.frame = CGRectMake(20, 50, 600, 600);
    [self.view addSubview:self.videoStreamingController.view];
}


#pragma mark - Misc methods

- (void)startDecoding
{
    self.h264Wrapper = [FDFFmpegWrapper sharedInstance];
    int status = [self.h264Wrapper openURLPath:[[NSBundle mainBundle] pathOfVideoFile]];
    
    if (status == 0)
    {
        [self.h264Wrapper startDecodingWithCallbackBlock:^(FDFFmpegFrameEntity *frameEntity) {
            [self.videoStreamingController loadVideoEntity:frameEntity];
        } waitForConsumer:YES completionCallback:^{
            NSLog(@"Decode complete.");
        }];
    }
    else
    {
        NSLog(@"Failed");
        self.h264Wrapper = nil;
    }
}

- (void)stopDecoding
{
    [self.h264Wrapper stopDecoding];
    self.h264Wrapper = nil;
}


#pragma mark - IBAction methods

- (IBAction)onPlayButtonTap:(id)sender
{
    [self startDecoding];
}

- (IBAction)onStopButtonTap:(id)sender
{
    [self stopDecoding];
}

#pragma mark - 

@end
