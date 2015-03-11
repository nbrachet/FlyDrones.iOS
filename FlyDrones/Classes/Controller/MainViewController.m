//
//  MainViewController.m
//  FlyDrones
//
//  Created by Sergey Galagan on 1/27/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "MainViewController.h"
#import "FDVideoStreamingController.h"

#import "FDDisplayInfoView.h"

#import "FDFFmpegWrapper.h"

#import "NSBundle+Utils.h"


#pragma mark - Static

static NSString * const kFDNetworkPort = @"5555";



#pragma mark - Private interface methods

@interface MainViewController ()

#pragma mark - Properties

@property (nonatomic, strong) FDFFmpegWrapper *h264Wrapper;

@property (nonatomic, strong) FDVideoStreamingController *videoStreamingController;
@property (nonatomic, weak) IBOutlet UIView *playerView;
@property (nonatomic, weak) IBOutlet FDDisplayInfoView *backgroundView;

@end


#pragma mark - Public interface methods

@implementation MainViewController

@synthesize h264Wrapper = _h264Wrapper;

#pragma mark - Instance methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self interfaceInitialization];
}


#pragma mark - Interface initialization methods

- (void)interfaceInitialization
{
    [self performVideoController];
    [self showDisplayInfo];
}

- (void)performVideoController
{
    self.videoStreamingController = [self.storyboard instantiateViewControllerWithIdentifier:NSStringFromClass([FDVideoStreamingController class])];
    [self.videoStreamingController resizeToFrame:self.playerView.frame];
    [self.playerView addSubview:self.videoStreamingController.view];
}

- (void)showDisplayInfo
{
    [self.backgroundView showDisplayInfo];
}


#pragma mark - Getter/Setter methods

- (void)setH264Wrapper:(FDFFmpegWrapper *)h264Wrapper
{
    if(h264Wrapper != _h264Wrapper)
    {
        [_h264Wrapper stopDecoding];
        _h264Wrapper = h264Wrapper;
    }
}

- (FDFFmpegWrapper *)h264Wrapper
{
    if(!_h264Wrapper)
    {
        _h264Wrapper = [[FDFFmpegWrapper alloc] init];
    }
    
    
    return _h264Wrapper;
}


#pragma mark - Misc methods

- (void)startDecoding
{
    self.h264Wrapper = nil;
    NSString *path = [[NSBundle mainBundle] pathToFile:@"2014-12-19.h264"];
//    NSString *path = [NSString stringWithFormat:@"udp://%@:%@", [NSString getIPAddress], kFDNetworkPort];
    
    int status = [self.h264Wrapper openURLPath:path];
    
    if (status == 0)
    {
        [self.h264Wrapper startDecodingWithCallbackBlock:^(FDFFmpegFrameEntity *frameEntity) {
            [self.videoStreamingController loadVideoEntity:frameEntity];
        } waitForConsumer:NO completionCallback:^{
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
