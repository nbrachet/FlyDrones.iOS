//
//  FDMovieDecoder.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDMovieDecoder.h"

#import <Accelerate/Accelerate.h>
#import "libavformat/avformat.h"
#import "libswscale/swscale.h"
#import "libswresample/swresample.h"
#import "libavutil/pixdesc.h"

struct BufferData {
    uint8_t *ptr;
    size_t size; ///< size left in the buffer
};

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase) {
    CGFloat fps, timebase;
    
    if (st->time_base.den && st->time_base.num) {
        timebase = av_q2d(st->time_base);
    } else if (st->codec->time_base.den && st->codec->time_base.num) {
        timebase = av_q2d(st->codec->time_base);
    } else {
        timebase = defaultTimeBase;
    }
    if (st->codec->ticks_per_frame != 1) {
        NSLog(@"WARNING: st.codec.ticks_per_frame=%d", st->codec->ticks_per_frame);
        //timebase *= st->codec->ticks_per_frame;
    }
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num) {
        fps = av_q2d(st->avg_frame_rate);
    } else if (st->r_frame_rate.den && st->r_frame_rate.num) {
        fps = av_q2d(st->r_frame_rate);
    } else {
        fps = 1.0 / timebase;
    }
    
    if (pFPS) {
        *pFPS = fps;
    }
    if (pTimeBase) {
        *pTimeBase = timebase;
    }
}

static NSArray *collectStreams(AVFormatContext *formatCtx, enum AVMediaType codecType) {
    NSMutableArray *streams = [NSMutableArray array];
    for (NSUInteger i = 0; i < formatCtx->nb_streams; ++i) {
        if (codecType == formatCtx->streams[i]->codec->codec_type) {
            [streams addObject:@(i)];
        }
    }
    return [streams copy];
}

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
    AVFormatContext     *formatContext;
    AVCodecContext      *_videoCodecCtx;
    AVFrame             *_videoFrame;
    NSInteger           _videoStream;
    AVPicture           _picture;
    BOOL                _pictureValid;
    struct SwsContext   *_swsContext;
    CGFloat             _videoTimeBase;
    CGFloat             _position;
    NSArray             *_videoStreams;
    SwrContext          *_swrContext;
    void                *_swrBuffer;
    NSUInteger          _swrBufferSize;
    NSDictionary        *_info;
    FDVideoFrameFormat  _videoFrameFormat;
}

@end

@implementation FDMovieDecoder

@dynamic duration;
@dynamic position;
@dynamic frameWidth;
@dynamic frameHeight;
@dynamic sampleRate;
@dynamic validVideo;
@dynamic info;
@dynamic startTime;

#pragma mark - Custom Accessors

- (CGFloat)duration {
    if (!formatContext) {
        return 0;
    }
    if (formatContext->duration == AV_NOPTS_VALUE) {
        return MAXFLOAT;
    }
    return (CGFloat)formatContext->duration / AV_TIME_BASE;
}

- (CGFloat)position {
    return _position;
}

- (void)setPosition:(CGFloat)seconds {
    _position = seconds;
    _isEOF = NO;
	   
    if (_videoStream != -1) {
        int64_t ts = (int64_t)(seconds / _videoTimeBase);
        avformat_seek_file(formatContext, _videoStream, ts, ts, ts, AVSEEK_FLAG_FRAME);
        avcodec_flush_buffers(_videoCodecCtx);
    }
}

- (NSUInteger)frameWidth {
    return _videoCodecCtx ? _videoCodecCtx->width : 0;
}

- (NSUInteger)frameHeight {
    return _videoCodecCtx ? _videoCodecCtx->height : 0;
}

- (BOOL)validVideo {
    return _videoStream != -1;
}

- (NSDictionary *)info {
    if (!_info) {
        NSMutableDictionary *md = [NSMutableDictionary dictionary];
        
        if (formatContext) {
            const char *formatName = formatContext->iformat->name;
            [md setValue:[NSString stringWithCString:formatName encoding:NSUTF8StringEncoding] forKey:@"format"];
            
            if (formatContext->bit_rate) {
                [md setValue: [NSNumber numberWithInt:formatContext->bit_rate] forKey: @"bitrate"];
            }
            
            if (formatContext->metadata) {
                
                NSMutableDictionary *md1 = [NSMutableDictionary dictionary];
                
                AVDictionaryEntry *tag = NULL;
                while((tag = av_dict_get(formatContext->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
                    
                    [md1 setValue:[NSString stringWithCString:tag->value encoding:NSUTF8StringEncoding]
                           forKey:[NSString stringWithCString:tag->key encoding:NSUTF8StringEncoding]];
                }
                
                [md setValue: [md1 copy] forKey: @"metadata"];
            }
            
            char buf[256];
            
            if (_videoStreams.count) {
                NSMutableArray *ma = [NSMutableArray array];
                for (NSNumber *n in _videoStreams) {
                    AVStream *st = formatContext->streams[n.integerValue];
                    avcodec_string(buf, sizeof(buf), st->codec, 1);
                    NSString *s = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
                    if ([s hasPrefix:@"Video: "])
                        s = [s substringFromIndex:@"Video: ".length];
                    [ma addObject:s];
                }
                md[@"video"] = ma.copy;
            }
        }
        
        _info = [md copy];
    }
    
    return _info;
}

- (CGFloat)startTime {
    if (_videoStream != -1) {
        
        AVStream *st = formatContext->streams[_videoStream];
        if (AV_NOPTS_VALUE != st->start_time)
            return st->start_time * _videoTimeBase;
        return 0;
    }
    
    return 0;
}

#pragma mark - Lifecycle

+ (void)initialize {
    av_register_all();
    avformat_network_init();
}

- (void)dealloc {
    NSLog(@"%@ dealloc", self);
    [self closeFile];
}

#pragma mark - Public

- (BOOL)openFile:(NSString *)urlPath {
    if (urlPath.length == 0 || formatContext) {
        return NO;
    }
    
    //Open input
    if (avformat_open_input(&formatContext, [urlPath cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL) < 0) {
        if (formatContext) {
            avformat_free_context(formatContext);
        }
        NSLog(@"Failed create format context");
        return NO;
    }
    
    
    //Find stream info
    if (avformat_find_stream_info(formatContext, NULL) < 0) {
        avformat_close_input(&formatContext);
        NSLog(@"Failed find stream info");
        return NO;
    }
    
    av_dump_format(formatContext, 0, [urlPath cStringUsingEncoding: NSUTF8StringEncoding], false);
    
    //Open video stream
    _videoStream = -1;
    _videoStreams = collectStreams(formatContext, AVMEDIA_TYPE_VIDEO);
    BOOL isVideoStreamOpened = NO;
    for (NSNumber *n in _videoStreams) {
        const NSUInteger iStream = n.integerValue;
        if ((formatContext->streams[iStream]->disposition & AV_DISPOSITION_ATTACHED_PIC) == 0) {
            isVideoStreamOpened = [self openVideoStream:iStream];
            if (isVideoStreamOpened) {
                break;
            }
        }
    }
    
    if (!isVideoStreamOpened) {
        [self closeFile];
        NSLog(@"Failed opened , %@", urlPath.lastPathComponent);
        return NO;
    }
    
    return YES;
}

- (BOOL)setupVideoFrameFormat:(FDVideoFrameFormat)format {
    if (format == FDVideoFrameFormatYUV &&
        _videoCodecCtx &&
        (_videoCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P || _videoCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P)) {
        
        _videoFrameFormat = FDVideoFrameFormatYUV;
        return YES;
    }
    
    _videoFrameFormat = FDVideoFrameFormatRGB;
    return _videoFrameFormat == format;
}

- (NSArray *)decodeFrames:(CGFloat)minDuration {
    if (_videoStream == -1) {
        return nil;
    }
    
    NSMutableArray *result = [NSMutableArray array];
    AVPacket packet;
    CGFloat decodedDuration = 0;
    BOOL finished = NO;
    
    while (!finished) {
        
        if (av_read_frame(formatContext, &packet) < 0) {
            _isEOF = YES;
            break;
        }
        
        if (packet.stream_index ==_videoStream) {
            int pktSize = packet.size;
            
            while (pktSize > 0) {
                
                int gotframe = 0;
                int len = avcodec_decode_video2(_videoCodecCtx, _videoFrame, &gotframe, &packet);
                if (len < 0) {
                    NSLog(@"decode video error, skip packet");
                    break;
                }
                
                if (gotframe) {
                    if (!_disableDeinterlacing && _videoFrame->interlaced_frame) {
                        avpicture_deinterlace((AVPicture*)_videoFrame,
                                              (AVPicture*)_videoFrame,
                                              _videoCodecCtx->pix_fmt,
                                              _videoCodecCtx->width,
                                              _videoCodecCtx->height);
                    }
                    
                    FDVideoFrame *frame = [self handleVideoFrame];
                    if (frame) {
                        [result addObject:frame];
                        
                        _position = frame.position;
                        decodedDuration += frame.duration;
                        if (decodedDuration > minDuration) {
                            finished = YES;
                        }
                    }
                }
                
                if (0 == len) {
                    break;
                }
                
                pktSize -= len;
            }
        }
        av_free_packet(&packet);
    }
    
    return result;
}

#pragma mark - Private

//- (FDMovieDecoderError)openInput:(NSString *)path {
//    AVFormatContext *formatCtx = NULL;
//    
//    if (avformat_open_input(&formatCtx, [path cStringUsingEncoding: NSUTF8StringEncoding], NULL, NULL) < 0) {
//        if (formatCtx) {
//            avformat_free_context(formatCtx);
//        }
//        return FDMovieDecoderErrorOpenFile;
//    }
//    
//    if (avformat_find_stream_info(formatCtx, NULL) < 0) {
//        avformat_close_input(&formatCtx);
//        return FDMovieDecoderErrorStreamInfoNotFound;
//    }
//    
//    av_dump_format(formatCtx, 0, [path cStringUsingEncoding: NSUTF8StringEncoding], false);
//    
//    formatContext = formatCtx;
//    return FDMovieDecoderErrorNone;
//}
//
//- (FDMovieDecoderError)openVideoStream {
//    FDMovieDecoderError errCode = FDMovieDecoderErrorStreamNotFound;
//    _videoStream = -1;
//    _artworkStream = -1;
//    _videoStreams = collectStreams(formatContext, AVMEDIA_TYPE_VIDEO);
//    for (NSNumber *n in _videoStreams) {
//        const NSUInteger iStream = n.integerValue;
//        if (0 == (formatContext->streams[iStream]->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
//            errCode = [self openVideoStream:iStream];
//            if (errCode == FDMovieDecoderErrorNone) {
//                break;
//            }
//        } else {
//            _artworkStream = iStream;
//        }
//    }
//    
//    return errCode;
//}

- (BOOL)openVideoStream:(NSInteger)videoStream {
    // get a pointer to the codec context for the video stream
    AVCodecContext *codecCtx = formatContext->streams[videoStream]->codec;
    
    // find the decoder for the video stream
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec) {
        return NO;
    }
    
    // inform the codec that we can handle truncated bitstreams -- i.e.,
    // bitstreams where frame boundaries can fall in the middle of packets
    //if(codec->capabilities & CODEC_CAP_TRUNCATED)
    //    _codecCtx->flags |= CODEC_FLAG_TRUNCATED;
    
    // open codec
    if (avcodec_open2(codecCtx, codec, NULL) < 0) {
        return NO;
    }
    
    _videoFrame = av_frame_alloc();
    
    if (!_videoFrame) {
        avcodec_close(codecCtx);
        return NO;
    }
    
    _videoStream = videoStream;
    _videoCodecCtx = codecCtx;
    
    // determine fps
    
    AVStream *st = formatContext->streams[_videoStream];
    avStreamFPSTimeBase(st, 0.04, &_fps, &_videoTimeBase);
    
    NSLog(@"video codec size: %d:%d fps: %.3f tb: %f",
                self.frameWidth,
                self.frameHeight,
                _fps,
                _videoTimeBase);
    
    NSLog(@"video start time %f", st->start_time * _videoTimeBase);
    NSLog(@"video disposition %d", st->disposition);
    
    return YES;
}

- (void)closeFile {
    [self closeVideoStream];
    
    _videoStreams = nil;
    
    if (formatContext) {
//        formatContext->interrupt_callback.opaque = NULL;
//        formatContext->interrupt_callback.callback = NULL;
        
        avformat_close_input(&formatContext);
        formatContext = NULL;
    }
}

- (void)closeVideoStream {
    _videoStream = -1;
    
    [self closeScaler];
    
    if (_videoFrame) {
        av_free(_videoFrame);
        _videoFrame = NULL;
    }
    
    if (_videoCodecCtx) {
        
        avcodec_close(_videoCodecCtx);
        _videoCodecCtx = NULL;
    }
}

- (void) closeScaler {
    if (_swsContext) {
        sws_freeContext(_swsContext);
        _swsContext = NULL;
    }
    
    if (_pictureValid) {
        avpicture_free(&_picture);
        _pictureValid = NO;
    }
}

- (BOOL) setupScaler {
    [self closeScaler];
    
    _pictureValid = avpicture_alloc(&_picture, PIX_FMT_RGB24, _videoCodecCtx->width, _videoCodecCtx->height) == 0;
    
    if (!_pictureValid) {
        return NO;
    }
    
    _swsContext = sws_getCachedContext(_swsContext,
                                       _videoCodecCtx->width,
                                       _videoCodecCtx->height,
                                       _videoCodecCtx->pix_fmt,
                                       _videoCodecCtx->width,
                                       _videoCodecCtx->height,
                                       PIX_FMT_RGB24,
                                       SWS_FAST_BILINEAR,
                                       NULL, NULL, NULL);
    
    return _swsContext != NULL;
}

- (FDVideoFrame *) handleVideoFrame {
    if (!_videoFrame->data[0]) {
        return nil;
    }
    
    FDVideoFrame *frame;
    
    if (_videoFrameFormat == FDVideoFrameFormatYUV) {
        
        FDVideoFrameYUV * yuvFrame = [[FDVideoFrameYUV alloc] init];
        
        yuvFrame.luma = copyFrameData(_videoFrame->data[0],
                                      _videoFrame->linesize[0],
                                      _videoCodecCtx->width,
                                      _videoCodecCtx->height);
        
        yuvFrame.chromaB = copyFrameData(_videoFrame->data[1],
                                         _videoFrame->linesize[1],
                                         _videoCodecCtx->width / 2,
                                         _videoCodecCtx->height / 2);
        
        yuvFrame.chromaR = copyFrameData(_videoFrame->data[2],
                                         _videoFrame->linesize[2],
                                         _videoCodecCtx->width / 2,
                                         _videoCodecCtx->height / 2);
        
        frame = yuvFrame;
        
    } else {
        if (!_swsContext && ![self setupScaler]) {
            NSLog(@"fail setup video scaler");
            return nil;
        }
        
        sws_scale(_swsContext,
                  (const uint8_t **)_videoFrame->data,
                  _videoFrame->linesize,
                  0,
                  _videoCodecCtx->height,
                  _picture.data,
                  _picture.linesize);
        
        
        FDVideoFrameRGB *rgbFrame = [[FDVideoFrameRGB alloc] init];
        
        rgbFrame.linesize = _picture.linesize[0];
        rgbFrame.rgb = [NSData dataWithBytes:_picture.data[0] length:rgbFrame.linesize * _videoCodecCtx->height];
        frame = rgbFrame;
    }
    
    frame.width = _videoCodecCtx->width;
    frame.height = _videoCodecCtx->height;
    frame.position = av_frame_get_best_effort_timestamp(_videoFrame) * _videoTimeBase;
    
    const int64_t frameDuration = av_frame_get_pkt_duration(_videoFrame);
    if (frameDuration) {
        frame.duration = frameDuration * _videoTimeBase;
        frame.duration += _videoFrame->repeat_pict * _videoTimeBase * 0.5;
        
        //if (_videoFrame->repeat_pict > 0) {
        //    LoggerVideo(0, @"_videoFrame.repeat_pict %d", _videoFrame->repeat_pict);
        //}
        
    } else {
        // sometimes, ffmpeg unable to determine a frame duration
        // as example yuvj420p stream from web camera
        frame.duration = 1.0 / _fps;
    }
//    NSLog(@"Frame: position %.4f duration %.4f | pkt_pos %lld ", frame.position, frame.duration, av_frame_get_pkt_pos(_videoFrame));
    
    return frame;
}

@end
