//
//  FDMovieDecoder.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDMovieDecoder.h"
#import "libavformat/avformat.h"
#import "libswscale/swscale.h"
#import "libswresample/swresample.h"
#import "libavutil/pixdesc.h"
#import "FDMovieFrame.h"

static NSData * copyFrameData(UInt8 *src, int linesize, int width, int height) {
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return md;
}

@interface FDMovieDecoder () {
    struct AVCodec *videoCodec;
    struct AVCodecContext *videoCodecContext;
    struct AVFrame *videoFrame;
    struct AVFrame *srcFrame;
    struct AVFrame *dstFrame;
    struct SwsContext *convertCtx;
    uint8_t *outputBuf;
}

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
        videoCodecContext->extradata_size = data.length;
        [data getBytes:videoCodecContext->extradata length:videoCodecContext->extradata_size];
        videoCodecContext->pix_fmt = PIX_FMT_YUV420P;
        
        srcFrame = av_frame_alloc();
        dstFrame = av_frame_alloc();
        
        BOOL isInitializedDecoder = (avcodec_open2(videoCodecContext, videoCodec, NULL) < 0) ? NO : YES;
        if (!isInitializedDecoder) {
            NSLog(@"Failed to initialize decoder");
            self = nil;
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    if (videoCodecContext) {
        av_free(videoCodecContext->extradata);
        avcodec_close(videoCodecContext);
        av_free(videoCodecContext);
    }
    if (videoFrame) {
        av_free(videoFrame);
    }
    if (dstFrame) {
        av_free(dstFrame);
    }
    if (outputBuf) {
        av_free(outputBuf);
    }
}

#pragma mark - Public

- (void)decodeFrame:(NSData *)frameData {
    AVPacket packet = {0};
    
    packet.data = (uint8_t *)frameData.bytes;
    packet.size = frameData.length;
    packet.stream_index = 0;
    //    packet.pts = 0x8000000000000000;
    //    packet.dts = 0x8000000000000000;
    //packet.duration=
    
    int packetSize = packet.size;
    while (packetSize > 0) {
        int frameFinished = 0;
        
        int length = avcodec_decode_video2(videoCodecContext, srcFrame, &frameFinished, &packet);
        if (length < 0) {
            NSLog(@"decode video error, skip packet");
            break;
        }
        
        if (frameFinished) {
            if ([self.delegate respondsToSelector:@selector(movieDecoder:decodedVideoFrame:)]) {
                FDVideoFrame *decodedVideoFrame = [self handleVideoFrame];
                if (decodedVideoFrame != nil) {
                    [self.delegate movieDecoder:self decodedVideoFrame:decodedVideoFrame];
                }
            }
        }
        
        if (length == 0) {
            break;
        }
        
        packetSize -= length;
    }
    av_free_packet(&packet);
}

#pragma mark - Private

- (FDVideoFrame *)handleVideoFrame {
    if (!srcFrame->data[0]) {
        return nil;
    }
    
    FDVideoFrameYUV *frame = [[FDVideoFrameYUV alloc] init];
    
    frame.luma = copyFrameData(srcFrame->data[0],
                               srcFrame->linesize[0],
                               videoCodecContext->width,
                               videoCodecContext->height);
    
    frame.chromaB = copyFrameData(srcFrame->data[1],
                                  srcFrame->linesize[1],
                                  videoCodecContext->width / 2.0f,
                                  videoCodecContext->height / 2.0f);
    
    frame.chromaR = copyFrameData(srcFrame->data[2],
                                  srcFrame->linesize[2],
                                  videoCodecContext->width / 2.0f,
                                  videoCodecContext->height / 2.0f);
    
    frame.width = videoCodecContext->width;
    frame.height = videoCodecContext->height;
    return frame;
}

@end
