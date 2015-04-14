//
//  FDDashboardViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDDashboardViewController.h"
#import <CocoaAsyncSocket/AsyncSocket.h>
#import <CocoaAsyncSocket/AsyncUdpSocket.h>
#import "FDMovieDecoder.h"
#import "FDMovieGLView.h"
#import "FDDisplayInfoView.h"

@interface FDDashboardViewController () <FDMovieDecoderDelegate>

@property (nonatomic, weak) IBOutlet FDDisplayInfoView *displayInfoView;
@property (nonatomic, weak) IBOutlet FDMovieGLView *movieGLView;

@property (nonatomic, strong) AsyncUdpSocket *asyncUdpSocket;
@property (nonatomic, strong) FDMovieDecoder *movieDecoder;

@end

@implementation FDDashboardViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.displayInfoView showDisplayInfo];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self startDataReceiving];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self stopDataReceiving];
}


- (void)dealloc {

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

- (BOOL)startDataReceiving {
    [self stopDataReceiving];
    
    self.asyncUdpSocket = [[AsyncUdpSocket alloc] initWithDelegate:self];
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:self.path];
    if (url == nil) {
        return NO;
    }
    
    BOOL success = [self.asyncUdpSocket bindToAddress:url.host port:[url.port integerValue]  error:&error];
    if (!success || error != nil) {
        NSLog(@"%@", error.localizedDescription);
        return NO;
    }
    
    [self.asyncUdpSocket receiveWithTimeout:-1 tag:0];
    
    return YES;
}

- (void)stopDataReceiving {
    [self.asyncUdpSocket close];
    self.asyncUdpSocket.delegate = nil;
    self.asyncUdpSocket = nil;
    
}

#pragma mark - AsyncSocketDelegate

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port {
    [self.asyncUdpSocket receiveWithTimeout:-1 tag:2];
    
    
    NSData *udpData = [data subdataWithRange:NSMakeRange(12, data.length-12)];  //remove first 12 bytes
    if (self.movieDecoder == nil) {
        self.movieDecoder = [[FDMovieDecoder alloc] initFromReceivedData:udpData delegate:self];
    }

    [self.movieDecoder decodeFrame:udpData];

    return YES;
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error {
    NSLog(@"%s %@", __func__, error);
}

- (void)onUdpSocketDidClose:(AsyncUdpSocket *)sock {
    NSLog(@"%s", __func__);
}

#pragma mark - FDMovieDecoderDelegate

- (void)movieDecoder:(FDMovieDecoder *)movieDecoder decodedVideoFrame:(FDVideoFrame *)videoFrame {
    [self.movieGLView render:videoFrame];
}

@end

