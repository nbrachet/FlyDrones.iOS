//
//  FDMovieDecoder.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDMovieDecoder.h"
#import "FDDroneStatus.h"

#include <sys/types.h>
#include <sys/sysctl.h>

static NSUInteger FDMovieDecoderMaxOperationInQueue = 5;
static NSUInteger FDMovieDecoderMaxOperationFromSkipRender = 3;

@interface FDMovieDecoder () {
    struct AVCodec *videoCodec;
    struct AVCodecContext *videoCodecContext;
    struct AVCodecParserContext *videoCodecParserContext;   //parser that is used to decode the h264 bitstream
}

@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (atomic) NSUInteger operationCountOnMainThread;
@property (atomic, readonly, getter=operationCount) NSUInteger operationCount;

@end

static void FFLog(void* context, int level, const char* format, va_list args) {
    NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
    NSLog(@"FFmpeg: %@", [message stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]);
}

@implementation FDMovieDecoder

#pragma mark - Lifecycle

+ (void)initialize {
    [super initialize];

#ifdef DEBUG
    av_log_set_level(AV_LOG_VERBOSE);
#else
    av_log_set_level(AV_LOG_INFO);
#endif
    av_log_set_callback(FFLog);

    av_register_all();
    avcodec_register_all();
}

- (instancetype)init {
    self = [super init];
    if (self) {
        if (![self initializeCodec]) {
            return nil;
        }

        self.operationCountOnMainThread = 0;

        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.name = @"Movie decode queue";
        self.operationQueue.maxConcurrentOperationCount = 1;
        if ([self.operationQueue respondsToSelector:@selector(qualityOfService)]) {
            self.operationQueue.qualityOfService = NSQualityOfServiceUserInitiated;
        }
    }
    return self;
}

- (void)dealloc {
    [self stopDecode];
    [self deinitializeCodec];
}

#pragma mark - Public

- (void)parseAndDecodeInputData:(NSData *)data {
    if (data.length == 0) {
        return;
    }
    
    if (self.operationCount > FDMovieDecoderMaxOperationInQueue) {
        NSLog(@"Tasks count:%lu", (unsigned long)self.operationCount);
//        [self.operationQueue cancelAllOperations];
//        [self.operationQueue waitUntilAllOperationsAreFinished];
        return;
    }
#ifdef DEBUG
    if (self.operationCount > FDMovieDecoderMaxOperationFromSkipRender || self.operationCountOnMainThread > 1) {
        NSLog(@"Tasks count:%lu %lu", (unsigned long)self.operationCount, (unsigned long)self.operationCountOnMainThread);
    }
#endif

    __weak __typeof(self)weakSelf = self;
    [self.operationQueue addOperationWithBlock:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf parseData:data];
    }];

//    NSLog(@"Tasks count:%lu", (unsigned long)self.operationQueue.operationCount);
}

- (void)stopDecode {
    [self.operationQueue cancelAllOperations];
}

#pragma mark - Private

- (BOOL)isCodecInitialized {
    return videoCodecContext && videoCodecParserContext;
}

- (BOOL)initializeCodec {
    videoCodec = avcodec_find_decoder(CODEC_ID_H264);
    
    videoCodecContext = avcodec_alloc_context3(videoCodec);
    videoCodecContext->pix_fmt = PIX_FMT_YUV420P;

    videoCodecContext->flags |= CODEC_FLAG_LOW_DELAY;

    //we can receive truncated frames
//    if (videoCodec->capabilities & CODEC_CAP_TRUNCATED) {
//        videoCodecContext->flags |= CODEC_FLAG_TRUNCATED;
//    }

    if ((videoCodec->capabilities & CODEC_CAP_AUTO_THREADS) == 0) {

        unsigned int ncpu;
        size_t len = sizeof(ncpu);
        if (sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0) != 0)
        {
            NSLog(@"sysctlbyname(hw.ncpu): %s", strerror(errno));
            ncpu = 1;
        }
        if (ncpu > 2)
            videoCodecContext->thread_count = ncpu - 2;
        else
            videoCodecContext->thread_count = ncpu;
    }
    videoCodecContext->thread_type &= ~FF_THREAD_FRAME;

    videoCodecParserContext = av_parser_init(AV_CODEC_ID_H264);
    
    BOOL isInitializedDecoder = (avcodec_open2(videoCodecContext, videoCodec, NULL) < 0) ? NO : YES;
    if (isInitializedDecoder == NO) {
        NSLog(@"Failed to initialize decoder");
        [self deinitializeCodec];
    }
    return isInitializedDecoder;
}

- (void)deinitializeCodec {
    if (videoCodecContext) {
        av_free(videoCodecContext->extradata);
        avcodec_close(videoCodecContext);
        av_free(videoCodecContext);
        videoCodecContext = NULL;
    }
    
    if (videoCodecParserContext) {
        av_parser_close(videoCodecParserContext);
        videoCodecParserContext = NULL;
    }
}

- (BOOL)isCancelled {
    return [self.operationQueue.operations.firstObject isCancelled];
}

- (void)parseData:(NSData *)data {
    int dataLen = (int)data.length;
    const uint8_t* dataBytes = (const uint8_t*)[data bytes];
    while (dataLen > 0) {
        /* @autoreleasepool */ {
//            if ([self isCancelled])
//                break;

            uint8_t* parsedData = NULL;
            int parsedDataSize = 0;
            int length = av_parser_parse2(videoCodecParserContext,
                                          videoCodecContext,
                                          &parsedData,                 //output data
                                          &parsedDataSize,             //output data size
                                          dataBytes,                   //input data
                                          dataLen,                     //input data size
                                          0,                           //pts
                                          0,                           //dts
                                          AV_NOPTS_VALUE);             //pos
            if (parsedDataSize > 0) {
                _width = videoCodecContext->width;
                _height = videoCodecContext->height;

                [self decodeFrameData:parsedData size:parsedDataSize];
            }
            if (length > 0) {
                dataLen -= length;
                dataBytes += length;
            }
        }
    }
}

- (void)decodeFrameData:(uint8_t *)data size:(int)size {
    if (!data || size == 0) {
        return;
    }
    
    AVPacket packet;
    av_init_packet(&packet);

    packet.data = data;
    packet.size = size;
    packet.stream_index = 0;
    packet.pts = AV_NOPTS_VALUE;
    packet.dts = AV_NOPTS_VALUE;

    NSOperationQueue* mainQueue = [NSOperationQueue mainQueue];
    while (packet.size > 0) {
        /* @autoreleasepool */ {
            __block struct AVFrame *decodedFrame = av_frame_alloc();
            int gotPicture;
            int length = avcodec_decode_video2(videoCodecContext, decodedFrame, &gotPicture, &packet);
            if (length < 0) {
                av_frame_free(&decodedFrame);
                NSLog(@"Decode video error, skip packet");
                break;
            }
            if (length > 0 && gotPicture && self.operationCount <= FDMovieDecoderMaxOperationFromSkipRender) {
                __weak __typeof(self)weakSelf = self;
                [mainQueue addOperationWithBlock:^{
                    __strong __typeof(weakSelf) strongSelf = weakSelf;
                    if (strongSelf == nil) {
                        return;
                    }

                    @try {
                        strongSelf.operationCountOnMainThread += 1;
                        [strongSelf.delegate movieDecoder:strongSelf decodedVideoFrame:*decodedFrame];
                    }
                    @finally {
                        av_frame_free(&decodedFrame);
                        strongSelf.operationCountOnMainThread -= 1;
                    }
                }];
            } else {
                av_frame_free(&decodedFrame);
            }

            packet.size -= length;
            packet.data += length;
        }
    }

    av_free_packet(&packet);
}

- (NSUInteger)operationCount {
    @synchronized(self) {
        return self.operationQueue.operationCount + self.operationCountOnMainThread;
    }
}

@end
