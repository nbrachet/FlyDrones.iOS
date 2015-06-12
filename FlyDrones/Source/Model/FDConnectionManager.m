//
//  FDConnectionManager.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/24/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDConnectionManager.h"
#import "FDRTPConnectionOperation.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "NSData+RTCP.h"

@interface FDConnectionManager () <FDRTPConnectionOperationDelegate>

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@property (nonatomic, strong) GCDAsyncSocket *controlAsyncSocket;
@property (nonatomic, strong) dispatch_queue_t controlSocketQueue;
@property (nonatomic, strong) dispatch_queue_t controlSocketDelegateQueue;

@end

@implementation FDConnectionManager

- (instancetype)init {
    self = [super init];
    if (self) {
        [self basicInitialization];
    }
    return self;
}

- (void)closeConnections {
    [self.operationQueue cancelAllOperations];
    self.operationQueue = nil;
    
    [self.controlAsyncSocket disconnect];
    self.controlAsyncSocket.delegate = nil;
    self.controlAsyncSocket = nil;
}

- (BOOL)isConnectedToVideoHost {
    NSOperation *operation = [[self.operationQueue operations] firstObject];
    return (operation != nil) && ![operation isCancelled] && ![operation isFinished];
}

- (BOOL)connectToVideoHost:(NSString *)host port:(NSUInteger)port {
    if (host.length == 0 || port == 0) {
        return NO;
    }
    FDRTPConnectionOperation *connectionOperation = [[FDRTPConnectionOperation alloc] init];
    connectionOperation.host = host;
    connectionOperation.port = port;
    connectionOperation.delegate = self;
    [self.operationQueue cancelAllOperations];
    [self.operationQueue addOperation:connectionOperation];
    return YES;
}

- (BOOL)isConnectedToControlHost {
    return self.controlAsyncSocket.isConnected;
}

- (BOOL)connectToControlHost:(NSString *)host port:(NSUInteger)port {
    if (host.length == 0 || port == 0) {
        return NO;
    }
    self.controlAsyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                         delegateQueue:self.controlSocketQueue
                                                           socketQueue:self.controlSocketDelegateQueue];
    NSError *error = nil;
    BOOL success = [self.controlAsyncSocket connectToHost:host onPort:port error:&error];
    
    if (!success || error != nil) {
        NSLog(@"%@", error.localizedDescription);
        return NO;
    }
    [self.controlAsyncSocket readDataWithTimeout:-1 tag:10];
    
    return YES;
}

- (BOOL)sendDataToControlServer:(NSData *)data {
    if (data.length == 0) {
        return NO;
    }
    
    [self.controlAsyncSocket writeData:data withTimeout:-1 tag:11];
    return YES;
}

#pragma mark - Private

- (void)dealloc {
    [self closeConnections];
}

- (void)basicInitialization {
    [self.operationQueue cancelAllOperations];
    self.operationQueue = [[NSOperationQueue alloc] init];
    
    self.controlSocketQueue = dispatch_queue_create("controlSocketQueue", DISPATCH_QUEUE_SERIAL);
    self.controlSocketDelegateQueue = dispatch_queue_create("controlSocketDelegateQueue", DISPATCH_QUEUE_SERIAL);
}

#pragma mark - FDRTPConnectionOperationDelegate

- (void)rtpConnectionOperation:(FDRTPConnectionOperation *)rtpConnectionOperation didReceiveData:(NSData *)data {
    if (data.length == 0) {
        return;
    }
    
    if (self.delegate == nil) {
        return;
    }
    
    if (![self.delegate respondsToSelector:@selector(connectionManager:didReceiveVideoData:)]) {
        return;
    }
    
    [self.delegate connectionManager:self didReceiveVideoData:data];
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    //    NSLog(@"%s", __FUNCTION__);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    [self.controlAsyncSocket readDataWithTimeout:-1 tag:10];
    
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(connectionManager:didReceiveControlData:)]) {
        [self.delegate connectionManager:self didReceiveControlData:data];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    //    NSLog(@"Did send control data");
}

@end
