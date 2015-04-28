//
//  FDConnectionManager.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/24/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDConnectionManager.h"
#import <CocoaAsyncSocket/AsyncUdpSocket.h>
#import "NSData+RTCP.h"

static NSUInteger const FDConnectionManagerStandardRTPHeaderLength = 12;

@interface FDConnectionManager () <AsyncUdpSocketDelegate>

@property(nonatomic, strong) AsyncUdpSocket *asyncUdpSocket;
@property(nonatomic, strong) NSTimer *connectingTimer;

@end

@implementation FDConnectionManager

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {

    }
    return self;
}

- (void)dealloc {
    [self closeConnection];
}

#pragma mark - Public

- (BOOL)connectToServer:(NSString *)hostForConnection portForConnection:(NSUInteger)portForConnection portForReceived:(NSUInteger)portForReceived {
    [self closeConnection];

    self.asyncUdpSocket = [[AsyncUdpSocket alloc] initWithDelegate:self];

    NSError *error = nil;
    
    BOOL success = [self.asyncUdpSocket bindToPort:portForReceived error:&error];
    if (!success || error != nil) {
        NSLog(@"%@", error.localizedDescription);
        return NO;
    }

    [self.asyncUdpSocket receiveWithTimeout:-1 tag:0];                      //start receiving
    [self startConnectingToHost:hostForConnection port:portForConnection];  //start connecting

    return YES;
}

- (BOOL)isConnected {
    return self.asyncUdpSocket.isConnected;
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

    BOOL success = [self.asyncUdpSocket sendData:packetData
                                          toHost:serverInfo[@"host"]
                                            port:[serverInfo[@"port"] intValue]
                                     withTimeout:-1
                                             tag:0];

    if (!success) {
        NSLog(@"Error while sending data");
    }
}

- (void)closeConnection {
    [self stopConnecting];

    NSLog(@"Close connection");
    [self.asyncUdpSocket close];
    self.asyncUdpSocket.delegate = nil;
    self.asyncUdpSocket = nil;
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

#pragma mark - AsyncSocketDelegate

- (void)onUdpSocket:(AsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    NSLog(@"Data sending");
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {

}

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port {
    [self.asyncUdpSocket receiveWithTimeout:-1 tag:2];

    if ([self.connectingTimer isValid]) {
        [self stopConnecting];
    }

    if (data.length < FDConnectionManagerStandardRTPHeaderLength) {
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

    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(connectionManager:didReceiveData:)]) {
        [self.delegate connectionManager:self didReceiveData:frameData];
    }

    return YES;
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error {
    NSLog(@"%@", error);
}

- (void)onUdpSocketDidClose:(AsyncUdpSocket *)sock {

}

@end
