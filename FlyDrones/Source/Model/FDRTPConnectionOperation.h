//
//  FDRTPConnectionOperation.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 6/11/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDRTPConnectionOperation;

@protocol FDRTPConnectionOperationDelegate <NSObject>

@optional
- (void)rtpConnectionOperation:(FDRTPConnectionOperation *)rtpConnectionOperation didReceiveData:(NSData *)data;

@end

@interface FDRTPConnectionOperation : NSOperation

@property (nonatomic, weak) id<FDRTPConnectionOperationDelegate> delegate;
@property (atomic, strong) NSString *host;
@property (atomic, assign) NSUInteger port;

- (void)notifyOnReceivingData:(NSData *)data;

@end
