//
//  FDMovieDecoder.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDMovieDecoder.h"
#import "libavformat/avformat.h"
#import "libswscale/swscale.h"
#import "libswresample/swresample.h"
#import "libavutil/pixdesc.h"
#import "FDVideoFrame.h"

@interface FDMovieDecoder () {
    struct AVCodec *videoCodec;
    struct AVCodecContext *videoCodecContext;
    struct AVCodecParserContext *videoCodecParserContext;   //parser that is used to decode the h264 bitstream

    struct AVFrame *decodedFrame;
}

@property (nonatomic, strong) dispatch_queue_t parsingQueue;

@end

@implementation FDMovieDecoder

#pragma mark - Lifecycle

+ (void)initialize {
    [super initialize];
    
    av_register_all();
    avcodec_register_all();
}

- (instancetype)initFromReceivedData:(NSData *)data delegate:(id<FDMovieDecoderDelegate>)delegate {
    self = [super init];
    if (self) {
        if (data == nil) {
            self = nil;
            return nil;
        }
    
        self.delegate = delegate;
        
        videoCodec = avcodec_find_decoder(CODEC_ID_H264);
        
        videoCodecContext = avcodec_alloc_context3(videoCodec);
        
        // Note: for H.264 RTSP streams, the width and height are usually not specified (width and height are 0).
        // These fields will become filled in once the first frame is decoded and the SPS is processed.
        videoCodecContext->width = 854;
        videoCodecContext->height = 480;
        
        videoCodecContext->extradata = av_malloc(data.length);
        videoCodecContext->extradata_size = (int)data.length;
        [data getBytes:videoCodecContext->extradata length:videoCodecContext->extradata_size];
        videoCodecContext->pix_fmt = PIX_FMT_YUV420P;
  
        //we can receive truncated frames
        if(videoCodec->capabilities & CODEC_CAP_TRUNCATED) {
            videoCodecContext->flags |= CODEC_FLAG_TRUNCATED;
        }
        
        videoCodecParserContext = av_parser_init(AV_CODEC_ID_H264);

        decodedFrame = av_frame_alloc();
        
        BOOL isInitializedDecoder = (avcodec_open2(videoCodecContext, videoCodec, NULL) < 0) ? NO : YES;
        if (!isInitializedDecoder) {
            NSLog(@"Failed to initialize decoder");
            self = nil;
            return nil;
        }
        
        self.parsingQueue = dispatch_queue_create("Parsing Queue", DISPATCH_QUEUE_SERIAL);
        
    }
    return self;
}

- (void)dealloc {
    if (videoCodecContext) {
        av_free(videoCodecContext->extradata);
        avcodec_close(videoCodecContext);
        av_free(videoCodecContext);
    }
    if (videoCodecParserContext) {
        av_parser_close(videoCodecParserContext);
    }
    if (decodedFrame) {
        av_free(decodedFrame);
    }
}

#pragma mark - Public

- (void)parseAndDecodeInputData:(NSData *)data {
    if (data.length == 0) {
        return;
    }
    
    __weak __typeof(self)weakSelf = self;
    dispatch_async(self.parsingQueue, ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf parseData:data];
    });

}

#pragma mark - Private

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
    packet.pts = 0x8000000000000000;
    packet.dts = 0x8000000000000000;
    //packet.duration=
    
    while(packet.size > 0) {
        int got_picture;
        int length = avcodec_decode_video2(videoCodecContext, decodedFrame, &got_picture, &packet);
        if (length < 0) {
            NSLog(@"Decode video error, skip packet");
            break;
        }
        if (got_picture) {
            if (self.delegate != nil && [self.delegate respondsToSelector:@selector(movieDecoder:decodedVideoFrame:)]) {
                FDVideoFrame *decodedVideoFrame = [[FDVideoFrame alloc] initWithFrame:decodedFrame
                                                                                width:videoCodecContext->width
                                                                               height:videoCodecContext->height];
//
                if (decodedVideoFrame != nil) {
                    [self.delegate movieDecoder:self decodedVideoFrame:decodedVideoFrame];
                }
            }
        }
        packet.size -= length;
        packet.data += length;
    }
    av_free_packet(&packet);
}

@end
