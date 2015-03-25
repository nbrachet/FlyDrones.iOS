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
#import "FDFFmpegFrameEntity.h"

#import "NSBundle+Utils.h"
#import "NSString+Network.h"


#pragma mark - Static

static NSString * const kFDNetworkPort = @"5555";



#pragma mark - Private interface methods

@interface MainViewController ()

#pragma mark - Properties

@property (nonatomic, strong) FDFFmpegWrapper *h264Wrapper;

@property (nonatomic, strong) FDVideoStreamingController *videoStreamingController;
@property (nonatomic, weak) IBOutlet FDDisplayInfoView *infoView;
@property (nonatomic, weak) IBOutlet UIView *playerView;

@property (nonatomic, assign) BOOL isNeedToChange;

@end


#pragma mark - Public interface methods

@implementation MainViewController

@synthesize h264Wrapper = _h264Wrapper;

#pragma mark - Instance methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self interfaceInitialization];
    self.isNeedToChange = YES;
}


#pragma mark - Interface initialization methods

- (void)interfaceInitialization
{
    [self performVideoController];
}

- (void)performVideoController
{
    self.videoStreamingController = [self.storyboard instantiateViewControllerWithIdentifier:NSStringFromClass([FDVideoStreamingController class])];
    [self.videoStreamingController resizeToFrame:self.playerView.frame];
    [self.playerView addSubview:self.videoStreamingController.view];
    [self.playerView bringSubviewToFront:self.infoView];
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
        [self.infoView showDisplayInfo];
        
        [self.h264Wrapper startDecodingWithCallbackBlock:^(FDFFmpegFrameEntity *frameEntity) {
            [self.videoStreamingController loadVideoEntity:frameEntity];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self calculateBounds:frameEntity];
            });
            
        } waitForConsumer:NO completionCallback:^{
            [self.infoView hideDisplayInfo];
        }];
    }
    else
    {
        self.h264Wrapper = nil;
    }
}

- (void)calculateBounds:(FDFFmpegFrameEntity *)entity
{
    CGFloat scaleFactor = [UIScreen mainScreen].scale;
    if (entity.width != 0 && entity.height != 0)
    {
        float targetRatio = entity.width.floatValue/(entity.height.floatValue*1.0);
        float viewRatio = self.playerView.bounds.size.width/(self.playerView.bounds.size.height*1.0);
        uint16_t x, y, width, height;
        
        if (targetRatio > viewRatio)
        {
            width = self.playerView.bounds.size.width * scaleFactor;
            height = width/targetRatio;
            x = 0;
            y = (self.playerView.bounds.size.height * scaleFactor - height)/2;
            
        }
        else
        {
            height = self.playerView.bounds.size.height * scaleFactor;
            width = height * targetRatio;
            y = 20;
            x = (self.playerView.bounds.size.width * scaleFactor - width)/2;
        }
        
        self.infoView.frame = CGRectMake(x, y/2, width/2, height/2);
    }
}

- (void)stopDecoding
{
    [self.infoView hideDisplayInfo];
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
