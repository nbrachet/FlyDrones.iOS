//
//  FDConnectionManager.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/24/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDConnectionManager;

@protocol FDConnectionManagerDelegate <NSObject>

@optional
- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveVideoData:(NSData *)data;
- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveControlData:(NSData *)data;

@end

@interface FDConnectionManager : NSObject

@property (nonatomic, weak) id<FDConnectionManagerDelegate> delegate;

- (void)closeConnections;
- (BOOL)isConnectedToVideoHost;
- (BOOL)connectToVideoHost:(NSString *)host port:(NSUInteger)port;
- (BOOL)isConnectedToControlHost;
- (BOOL)connectToControlHost:(NSString *)host port:(NSUInteger)port;
- (BOOL)sendDataToControlServer:(NSData *)data;

@end