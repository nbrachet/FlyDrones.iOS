//
//  FDDashboardViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDDashboardViewController.h"
#import "FDMovieDecoder.h"
#import "FDMovieGLView.h"
#import "FDDisplayInfoView.h"
#import "FDConnectionManager.h"

@interface FDDashboardViewController () <FDConnectionManagerDelegate, FDMovieDecoderDelegate>

@property(nonatomic, weak) IBOutlet FDDisplayInfoView *displayInfoView;
@property(nonatomic, weak) IBOutlet FDMovieGLView *movieGLView;

@property(nonatomic, strong) FDConnectionManager *connectionManager;
@property(nonatomic, strong) FDMovieDecoder *movieDecoder;

@end

@implementation FDDashboardViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.connectionManager = [[FDConnectionManager alloc] init];
    self.connectionManager.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.displayInfoView showDisplayInfo];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

//    [self.connectionManager connectToServer:self.path];
    [self.connectionManager connectToServer:self.hostForConnection portForConnection:self.portForConnection portForReceived:self.portForReceived];

}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.connectionManager closeConnection];
    self.movieDecoder = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - Public


#pragma mark - IBActions

- (IBAction)back:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Private


//- (int)isH264iFrame:(NSData *)data {
//    const char* bytes = (const char*)[data bytes];
//    char firstByte = bytes[0];
//    char secondByte = bytes[1];
//
//    int fragment_type = firstByte & 0x1F;
//    int nal_type = secondByte & 0x1F;
//    int start_bit = secondByte & 0x80;
//    int end_bit = secondByte & 0x40;
//    
//    NSLog(@"Fragment type:%d NAL type:%d Start bit:%d End bit:%d", fragment_type, nal_type, start_bit, end_bit);
//    
//    if (((fragment_type == 28 || fragment_type == 29) && nal_type == 5 && start_bit == 128) || fragment_type == 5) {
//        return YES;
//    }
//    return NO;
//}

#pragma mark - FDConnectionManagerDelegate

- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveData:(NSData *)data {
    if (data.length == 0) {
        return;
    }

    if (self.movieDecoder == nil) {
        self.movieDecoder = [[FDMovieDecoder alloc] initFromReceivedData:data delegate:self];
    }

    [self.movieDecoder parseAndDecodeInputData:data];
}

#pragma mark - FDMovieDecoderDelegate

- (void)movieDecoder:(FDMovieDecoder *)movieDecoder decodedVideoFrame:(FDVideoFrame *)videoFrame {
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        [strongSelf.movieGLView renderVideoFrame:videoFrame];
    });
}

@end

