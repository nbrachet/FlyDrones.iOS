//
//  FDMovieDecoder.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "FDMovieFrame.h"

@interface FDMovieDecoder : NSObject

@property (nonatomic, readonly) BOOL isEOF;
@property (readwrite, nonatomic) CGFloat position;
@property (nonatomic, readonly) CGFloat duration;
@property (nonatomic, readonly) CGFloat fps;
@property (nonatomic, readonly) CGFloat sampleRate;
@property (nonatomic, readonly) NSUInteger frameWidth;
@property (nonatomic, readonly) NSUInteger frameHeight;
@property (nonatomic, readonly) BOOL validVideo;
@property (nonatomic, readonly, strong) NSDictionary *info;
@property (nonatomic, readonly) CGFloat startTime;
@property (nonatomic) BOOL disableDeinterlacing;

- (BOOL)openFile:(NSString *)urlPath;
- (void)closeFile;
- (BOOL)setupVideoFrameFormat:(FDVideoFrameFormat)format;
- (NSArray *)decodeFrames:(CGFloat) minDuration;

@end
