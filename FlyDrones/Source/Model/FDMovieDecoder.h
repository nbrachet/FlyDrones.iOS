//
//  FDMovieDecoder.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

@class FDVideoFrame;
@class FDMovieDecoder;

@protocol FDMovieDecoderDelegate <NSObject>

- (void)movieDecoder:(FDMovieDecoder *)movieDecoder decodedVideoFrame:(AVFrame)videoFrame;

@end

@interface FDMovieDecoder : NSObject

@property (nonatomic, weak) id <FDMovieDecoderDelegate> delegate;
@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;

- (void)parseAndDecodeInputData:(NSData *)data;
- (void)stopDecode;

@end
