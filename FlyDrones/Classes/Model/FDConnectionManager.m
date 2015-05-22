//
//  FDConnectionManager.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/24/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDConnectionManager.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>
#import "NSData+RTCP.h"

static NSUInteger const FDConnectionManagerStandardRTPHeaderLength = 12;

@interface FDConnectionManager () <GCDAsyncUdpSocketDelegate, GCDAsyncSocketDelegate>

@property (nonatomic, strong) GCDAsyncUdpSocket *videoAsyncUdpSocket;
@property (nonatomic, strong) dispatch_queue_t videoSocketQueue;
@property (nonatomic, strong) dispatch_queue_t videoSocketDelegateQueue;

@property (nonatomic, strong) GCDAsyncSocket *controlAsyncSocket;
@property (nonatomic, strong) dispatch_queue_t controlSocketQueue;
@property (nonatomic, strong) dispatch_queue_t controlSocketDelegateQueue;

@property (nonatomic, strong) NSTimer *connectingTimer;

@end

@implementation FDConnectionManager

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        self.videoSocketQueue = dispatch_queue_create("videoSocketQueue", DISPATCH_QUEUE_SERIAL);
        self.videoSocketDelegateQueue = dispatch_queue_create("videoSocketDelegateQueue", DISPATCH_QUEUE_SERIAL);
        self.controlSocketQueue = dispatch_queue_create("controlSocketQueue", DISPATCH_QUEUE_SERIAL);
        self.controlSocketDelegateQueue = dispatch_queue_create("controlSocketDelegateQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [self closeConnection];
}

#pragma mark - Public

- (BOOL)connectToServer:(NSString *)hostForConnection portForConnection:(NSUInteger)portForConnection portForReceived:(NSUInteger)portForReceived {

    [self closeConnection];

    self.videoAsyncUdpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:self.videoSocketDelegateQueue socketQueue:self.videoSocketQueue];

    NSError *error = nil;
    
    BOOL isBinded = [self.videoAsyncUdpSocket bindToPort:portForReceived error:&error];
    if (!isBinded || error != nil) {
        NSLog(@"%@", error.localizedDescription);
        return NO;
    }

    BOOL isReceiving = [self.videoAsyncUdpSocket beginReceiving:&error];
    if (!isReceiving || error != nil) {
        NSLog(@"%@", error.localizedDescription);
        return NO;
    }
    
    //start receiving
    [self startConnectingToHost:hostForConnection port:portForConnection];  //start connecting

    return YES;
}

- (BOOL)isTCPConnected {
    return !self.controlAsyncSocket.isDisconnected;
}

- (BOOL)isUDPConnected {
    return !self.videoAsyncUdpSocket.isClosed;
}


- (BOOL)receiveTCPServer:(NSString *)host port:(NSUInteger)port {
    self.controlAsyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.controlSocketQueue socketQueue:self.controlSocketDelegateQueue];
    NSError *error = nil;
    BOOL success = [self.controlAsyncSocket connectToHost:host onPort:port error:&error];
    
    if (!success || error != nil) {
        NSLog(@"%@", error.localizedDescription);
        return NO;
    }
    [self.controlAsyncSocket readDataWithTimeout:-1 tag:10];

    return YES;
}

- (BOOL)sendDataFromTCPConnection:(NSData *)data {
    if (data.length == 0) {
        return NO;
    }
    [self.controlAsyncSocket writeData:data withTimeout:-1 tag:11];
    return YES;
}

#pragma mark - Private

- (void)startConnectingToHost:(NSString *)host port:(NSUInteger)port {
    [self stopConnecting];
    NSLog(@"Start connecting");

    NSDictionary *serverInfo = @{@"host": host, @"port": @(port)};

    self.connectingTimer = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(sendEmptyData:) userInfo:serverInfo repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.connectingTimer forMode:NSDefaultRunLoopMode];
}

- (void)stopConnecting {
    NSLog(@"Stop connecting");

    @synchronized(self) {
        [self.connectingTimer invalidate];
        self.connectingTimer = nil;
    }
}

- (void)sendEmptyData:(NSTimer *)timer {
    NSDictionary *serverInfo = [timer userInfo];

    NSData *packetData = [NSData RTCPDataWithVersion:2 packetType:RTCPPacketTypeRR];
    NSLog(@"Send data: %@", [packetData hexadecimalString]);

    [self.videoAsyncUdpSocket sendData:packetData
                                toHost:serverInfo[@"host"]
                                  port:[serverInfo[@"port"] intValue]
                                     withTimeout:-1
                                             tag:0];
}

- (void)closeConnection {
    [self stopConnecting];

    NSLog(@"Close connection");
    [self.videoAsyncUdpSocket close];
    self.videoAsyncUdpSocket.delegate = nil;
    self.videoAsyncUdpSocket = nil;
    
    [self.controlAsyncSocket disconnect];
    self.controlAsyncSocket.delegate = nil;
    self.controlAsyncSocket = nil;
}

- (NSInteger)rtpHeaderLength:(NSData *)data {
    const char *bytes = (const char *) [data bytes];
    int rtpHeaderLength = (bytes[0] & 0xF) * 4 + FDConnectionManagerStandardRTPHeaderLength;    /*( <star>p & 0xF ) * 4 + 12 -- where p is a pointer to the RTP header*/
    return rtpHeaderLength;
}

- (BOOL)isSRData:(NSData *)data {
    const char *bytes = (const char *) [data bytes];
    return (bytes[1] & 0xFF) == 200;                    /*that would ignore RTCP SR packets*/
}

#pragma mark - GCDAsyncUdpSocketDelegate

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    NSLog(@"%s", __FUNCTION__);
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {

    if ([self.connectingTimer isValid]) {
        [self stopConnecting];
    }

    if (data.length < FDConnectionManagerStandardRTPHeaderLength) {
        return;
    }

    NSInteger rtpHeaderLength = [self rtpHeaderLength:data];
    if (data.length <= rtpHeaderLength) {
        return;
    }

    BOOL isSRData = [self isSRData:data];
    if (isSRData) {
        return;
    }

    NSData *frameData = [data subdataWithRange:NSMakeRange(rtpHeaderLength, data.length - rtpHeaderLength)];

    if (frameData.length == 0) {
        return;
    }

    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(connectionManager:didReceiveUDPData:)]) {
        [self.delegate connectionManager:self didReceiveUDPData:frameData];
    }

    return;
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    NSLog(@"%s", __FUNCTION__);
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    NSLog(@"%s", __FUNCTION__);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"%s", __FUNCTION__);

    [self.controlAsyncSocket readDataWithTimeout:-1 tag:10];


    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(connectionManager:didReceiveTCPData:)]) {
        [self.delegate connectionManager:self didReceiveTCPData:data];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"Did send control data");
}

@end
