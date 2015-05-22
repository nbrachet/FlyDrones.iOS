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
- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveUDPData:(NSData *)data;
- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveTCPData:(NSData *)data;

@end

@interface FDConnectionManager : NSObject

@property (nonatomic, weak) id <FDConnectionManagerDelegate> delegate;

- (BOOL)connectToServer:(NSString *)host portForConnection:(NSUInteger)portForConnection portForReceived:(NSUInteger)portForReceived;

- (void)closeConnection;

- (BOOL)isTCPConnected;
- (BOOL)isUDPConnected;

- (BOOL)receiveTCPServer:(NSString *)host port:(NSUInteger)port;

- (BOOL)sendDataFromTCPConnection:(NSData *)data;

@end
