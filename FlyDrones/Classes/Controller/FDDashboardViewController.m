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
    
    if(CFByteOrderGetCurrent() == CFByteOrderLittleEndian) {
        NSLog(@"BYTEORDER: Little Endian");
    } else {
        NSLog(@"BYTEORDER: Big Endian");
    }
    
//#if __LITTLE_ENDIAN__
//    return CFByteOrderLittleEndian;
//#elif __BIG_ENDIAN__
//    return CFByteOrderBigEndian;
//#else

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.displayInfoView showDisplayInfo];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self.connectionManager connectToServer:self.hostForConnection portForConnection:self.portForConnection portForReceived:self.portForReceived];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.connectionManager closeConnection];
    self.connectionManager = nil;
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

