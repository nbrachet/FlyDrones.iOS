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

- (void)parseAndDecodeInputData:(NSData *)data;
- (void)stopDecode;

@end
