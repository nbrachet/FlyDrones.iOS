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

static NSUInteger const StandardRTPHheaderLength = 12;

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

- (BOOL)startDataReceiving {
    [self stopDataReceiving];
    
    self.asyncUdpSocket = [[AsyncUdpSocket alloc] initWithDelegate:self];
    NSError *error = nil;
    
    NSURL *url = [NSURL URLWithString:self.path];
    if (url == nil) {
        return NO;
    }
    
    BOOL success = [self.asyncUdpSocket bindToAddress:url.host port:[url.port integerValue] error:&error];
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

- (NSInteger)rtpHeaderLength:(NSData *)data {
    const char* bytes = (const char*)[data bytes];
    int rtpHeaderLength = (bytes[0] & 0xF) * 4 + StandardRTPHheaderLength;    /*( <star>p & 0xF ) * 4 + 12 -- where p is a pointer to the RTP header*/
    return rtpHeaderLength;
}

- (BOOL)isSRData:(NSData *)data {
    const char* bytes = (const char*)[data bytes];
    return (bytes[1] & 0xFF) == 200;                    /*that would ignore RTCP SR packets*/
}

#pragma mark - AsyncSocketDelegate

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port {
    [self.asyncUdpSocket receiveWithTimeout:-1 tag:2];
    
    if (data.length < StandardRTPHheaderLength) {
        return YES;
    }
    
    NSInteger rtpHeaderLength = [self rtpHeaderLength:data];
    if (data.length <= rtpHeaderLength) {
        return YES;
    }
    
    BOOL isSRData = [self isSRData:data];
    if (isSRData) {
        return YES;
    }
    
    NSData *frameData = [data subdataWithRange:NSMakeRange(rtpHeaderLength, data.length - rtpHeaderLength)];
    
    if (frameData.length == 0) {
        return YES;
    }
    
    if (self.movieDecoder == nil) {
        self.movieDecoder = [[FDMovieDecoder alloc] initFromReceivedData:frameData delegate:self];
    }
    
    [self.movieDecoder parseAndDecodeInputData:frameData];
    
    return YES;
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error {
    NSLog(@"%@", error);
}

- (void)onUdpSocketDidClose:(AsyncUdpSocket *)sock {
    NSLog(@"%s", __func__);
}

#pragma mark - FDMovieDecoderDelegate

- (void)movieDecoder:(FDMovieDecoder *)movieDecoder decodedVideoFrame:(FDVideoFrame *)videoFrame {
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf.movieGLView renderVideoFrame:videoFrame];
    });
}

@end

