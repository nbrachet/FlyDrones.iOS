//
//  FDConnectionManager.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/24/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDConnectionManager;

@protocol FDConnectionManagerDelegate <NSObject>

@optional
- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveData:(NSData *)data;

@end

@interface FDConnectionManager : NSObject

@property (nonatomic, weak) id<FDConnectionManagerDelegate> delegate;

- (BOOL)connectToServer:(NSString *)host portForConnection:(NSUInteger)portForConnection portForReceived:(NSUInteger)portForReceived;
- (void)closeConnection;
- (BOOL)isConnected;

@end
