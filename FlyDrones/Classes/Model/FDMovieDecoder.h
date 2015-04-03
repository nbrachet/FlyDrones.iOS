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

typedef NS_ENUM(NSUInteger, FDMovieDecoderError) {
    FDMovieDecoderErrorNone,
    FDMovieDecoderErrorOpenFile,
    FDMovieDecoderErrorStreamInfoNotFound,
    FDMovieDecoderErrorStreamNotFound,
    FDMovieDecoderErrorCodecNotFound,
    FDMovieDecoderErrorOpenCodec,
    FDMovieDecoderErrorAllocateFrame,
    FDMovieErroSetupScaler,
    FDMovieDecoderErroreSampler,
    FDMovieErroUnsupported,
};

typedef BOOL(^FDMovieDecoderInterruptCallback)();

@interface FDMovieDecoder : NSObject

@property (nonatomic, readonly, strong) NSString *path;
@property (nonatomic, readonly) BOOL isEOF;
@property (readwrite, nonatomic) CGFloat position;
@property (nonatomic, readonly) CGFloat duration;
@property (nonatomic, readonly) CGFloat fps;
@property (nonatomic, readonly) CGFloat sampleRate;
@property (nonatomic, readonly) NSUInteger frameWidth;
@property (nonatomic, readonly) NSUInteger frameHeight;
@property (nonatomic, readonly) NSUInteger subtitleStreamsCount;
@property (nonatomic, readonly) NSInteger selectedSubtitleStream;
@property (nonatomic, readonly) BOOL validVideo;
@property (nonatomic, readonly) BOOL validSubtitles;
@property (nonatomic, readonly, strong) NSDictionary *info;
@property (nonatomic, readonly, strong) NSString *videoStreamFormatName;
@property (nonatomic, readonly) BOOL isNetwork;
@property (nonatomic, readonly) CGFloat startTime;
@property (nonatomic) BOOL disableDeinterlacing;
@property (nonatomic, strong) FDMovieDecoderInterruptCallback interruptCallback;

- (BOOL)openFile:(NSString *)path;
- (void) closeFile;
- (BOOL)setupVideoFrameFormat:(FDVideoFrameFormat)format;
- (NSArray *)decodeFrames:(CGFloat) minDuration;

@end

@interface FDMovieSubtitleASSParser : NSObject

+ (NSArray *)parseEvents:(NSString *)events;
+ (NSArray *)parseDialogue:(NSString *)dialogue numFields:(NSUInteger)numFields;
+ (NSString *)removeCommandsFromEventText:(NSString *)text;

@end