//
//  FDFFmpegWrapper.h
//  FlyDrones
//
//  Created by Sergey Galagan on 1/30/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//


#pragma mark - Class forward

@class FDFFmpegFrameEntity;


@interface FDFFmpegWrapper : NSObject

#pragma mark - Class methods

+ (FDFFmpegWrapper *)sharedInstance;


#pragma mark - Instance methods

- (instancetype)init;
- (int)openURLPath:(NSString *)urlPath;
- (int)startDecodingWithCallbackBlock:(void(^)(FDFFmpegFrameEntity *frameEntity))frameCallbackBlock
                      waitForConsumer:(BOOL)wait
                   completionCallback:(void(^)())completion;
- (void)stopDecoding;

#pragma mark -

@end
