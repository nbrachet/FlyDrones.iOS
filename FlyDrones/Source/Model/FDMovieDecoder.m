//
//  FDMovieDecoder.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDMovieDecoder.h"
#import "FDDroneStatus.h"

static NSUInteger FDMovieDecoderMaxOperationInQueue = 5;
static NSUInteger FDMovieDecoderMaxOperationFromSkipRender = 1;

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
        videoCodecContext = NULL;
        videoCodecParserContext = NULL;
        
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
    
    if (![self isCodecInitialized]) {
        [self initializeCodecWith:data];
    }
    
    if ([self isSkipDecode]) {
        [self.operationQueue cancelAllOperations];
    }
    
    __weak __typeof(self)weakSelf = self;
    [self.operationQueue addOperationWithBlock:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf parseData:data];
    }];
    
    NSLog(@"Tasks count:%lu", (unsigned long)self.operationQueue.operationCount);
}

- (void)stopDecode {
    [self.operationQueue cancelAllOperations];
}

#pragma mark - Private

- (BOOL)isCodecInitialized {
    return videoCodecContext && videoCodecParserContext;
}

- (void)initializeCodecWith:(NSData *)data {
    videoCodec = avcodec_find_decoder(CODEC_ID_H264);
    
    videoCodecContext = avcodec_alloc_context3(videoCodec);
    
    // Note: for H.264 RTSP streams, the width and height are usually not specified (width and height are 0).
    // These fields will become filled in once the first frame is decoded and the SPS is processed.
    videoCodecContext->width = (int)[FDDroneStatus currentStatus].videoSize.width;
    videoCodecContext->height = (int)[FDDroneStatus currentStatus].videoSize.height;
    
    videoCodecContext->extradata = av_malloc(data.length);
    videoCodecContext->extradata_size = (int)data.length;
    [data getBytes:videoCodecContext->extradata length:videoCodecContext->extradata_size];
    videoCodecContext->pix_fmt = PIX_FMT_YUV420P;
    
    //we can receive truncated frames
    if(videoCodec->capabilities & CODEC_CAP_TRUNCATED) {
        videoCodecContext->flags |= CODEC_FLAG_TRUNCATED;
    }
    
    videoCodecParserContext = av_parser_init(AV_CODEC_ID_H264);
    
    BOOL isInitializedDecoder = (avcodec_open2(videoCodecContext, videoCodec, NULL) < 0) ? NO : YES;
    if (isInitializedDecoder == NO) {
        NSLog(@"Failed to initialize decoder");
        [self deinitializeCodec];
    }
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
    if (data.length == 0) {
        return;
    }
    
    NSMutableData *parsingData = [NSMutableData dataWithData:data];
    
    while (parsingData.length > 0) {
        @autoreleasepool {
            const uint8_t *parsingDataBytes = (const uint8_t*)[parsingData bytes];
            uint8_t *parsedData = NULL;
            int parsedDataSize = 0;
            int length = av_parser_parse2(videoCodecParserContext,
                                          videoCodecContext,
                                          &parsedData,                 //output data
                                          &parsedDataSize,             //output data size
                                          &parsingDataBytes[0],        //input data
                                          (int)[parsingData length],   //input data size
                                          0,                           //PTS
                                          0,                           //DTS
                                          AV_NOPTS_VALUE);
            if (length > 0) {
                [parsingData replaceBytesInRange:NSMakeRange(0, length) withBytes:NULL length:0];
            }
            if (parsedDataSize > 0) {
                [self decodeFrameData:parsedData size:parsedDataSize];
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
                NSLog(@"Decode video error, skip packet");
                break;
            }
            if (isGotPicture && ![self isSkipRender]) {
                __weak __typeof(self)weakSelf = self;
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    __strong __typeof(weakSelf) strongSelf = weakSelf;
                    if (strongSelf == nil) {
                        return;
                    }

                    [strongSelf.delegate movieDecoder:strongSelf decodedVideoFrame:*decodedFrame];
                    av_frame_free(&decodedFrame);
                });
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
