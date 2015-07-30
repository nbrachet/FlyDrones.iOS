//
//  FDMovieDecoder.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDMovieDecoder.h"
#import "FDDroneStatus.h"

static NSUInteger FDMovieDecoderMaxOperationInQueue = 7;
static NSUInteger FDMovieDecoderMaxOperationFromSkipRender = 3;

@interface FDMovieDecoder () {
    struct AVCodec *videoCodec;
    struct AVCodecContext *videoCodecContext;
    struct AVCodecParserContext *videoCodecParserContext;   //parser that is used to decode the h264 bitstream
}

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation FDMovieDecoder

#pragma mark - Lifecycle

+ (void)initialize {
    [super initialize];
    
    av_register_all();
    avcodec_register_all();
}

- (instancetype)init {
    self = [super init];
    if (self) {
        if (![self initializeCodec]) {
            return nil;
        }

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
    
    if ([self isSkipDecode]) {
        return;
    }
    
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

    //we can receive truncated frames
    if (videoCodec->capabilities & CODEC_CAP_TRUNCATED) {
        videoCodecContext->flags |= CODEC_FLAG_TRUNCATED;
    }
    
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

- (void)parseData:(NSData *)data {
    int dataLen = (int)data.length;
    const uint8_t* dataBytes = (const uint8_t*)[data bytes];
    while (dataLen > 0) {
        @autoreleasepool {
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
    
    while(packet.size > 0) {
        @autoreleasepool {
            __block struct AVFrame *decodedFrame = av_frame_alloc();
            int isGotPicture;
            int length = avcodec_decode_video2(videoCodecContext, decodedFrame, &isGotPicture, &packet);
            if (length < 0) {
                av_frame_free(&decodedFrame);
                NSLog(@"Decode video error, skip packet");
                break;
            }
            if (isGotPicture && ![self isSkipRender]) {
                __weak __typeof(self)weakSelf = self;
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    __strong __typeof(weakSelf) strongSelf = weakSelf;
                    if (strongSelf == nil) {
                        return;
                    }

                    [strongSelf.delegate movieDecoder:strongSelf decodedVideoFrame:*decodedFrame];
                    av_frame_free(&decodedFrame);
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

- (BOOL)isSkipDecode {
    BOOL isSkipDecode;
    @synchronized(self) {
        isSkipDecode = self.operationQueue.operationCount > FDMovieDecoderMaxOperationInQueue;
    }
    return isSkipDecode;
}

- (BOOL)isSkipRender {
    BOOL isSkipRender;
    @synchronized(self) {
        isSkipRender = self.operationQueue.operationCount > FDMovieDecoderMaxOperationFromSkipRender;
    }
    return isSkipRender;
}

@end
