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

static NSString * errorMessage (FDMovieDecoderError errorCode) {
    switch (errorCode) {
        case FDMovieDecoderErrorNone:
            return @"";
            
        case FDMovieDecoderErrorOpenFile:
            return NSLocalizedString(@"Unable to open file", nil);
            
        case FDMovieDecoderErrorStreamInfoNotFound:
            return NSLocalizedString(@"Unable to find stream information", nil);
            
        case FDMovieDecoderErrorStreamNotFound:
            return NSLocalizedString(@"Unable to find stream", nil);
            
        case FDMovieDecoderErrorCodecNotFound:
            return NSLocalizedString(@"Unable to find codec", nil);
            
        case FDMovieDecoderErrorOpenCodec:
            return NSLocalizedString(@"Unable to open codec", nil);
            
        case FDMovieDecoderErrorAllocateFrame:
            return NSLocalizedString(@"Unable to allocate frame", nil);
            
        case FDMovieErroSetupScaler:
            return NSLocalizedString(@"Unable to setup scaler", nil);
            
        case FDMovieDecoderErroreSampler:
            return NSLocalizedString(@"Unable to setup resampler", nil);
            
        case FDMovieErroUnsupported:
            return NSLocalizedString(@"The ability is not supported", nil);
    }
}


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

static BOOL isNetworkPath (NSString *path) {
    NSRange range = [path rangeOfString:@":"];
    if (range.location == NSNotFound) {
        return NO;
    }
    NSString *scheme = [path substringToIndex:range.length];
    if ([scheme isEqualToString:@"file"]) {
        return NO;
    }
    return YES;
}

static int interrupt_callback(void *ctx);

@interface FDMovieDecoder () {
    
    AVFormatContext     *_formatCtx;
    AVCodecContext      *_videoCodecCtx;
    AVCodecContext      *_subtitleCodecCtx;
    AVFrame             *_videoFrame;
    NSInteger           _videoStream;
    NSInteger           _subtitleStream;
    AVPicture           _picture;
    BOOL                _pictureValid;
    struct SwsContext   *_swsContext;
    CGFloat             _videoTimeBase;
    CGFloat             _position;
    NSArray             *_videoStreams;
    NSArray             *_subtitleStreams;
    SwrContext          *_swrContext;
    void                *_swrBuffer;
    NSUInteger          _swrBufferSize;
    NSDictionary        *_info;
    FDVideoFrameFormat  _videoFrameFormat;
    NSUInteger          _artworkStream;
    NSInteger           _subtitleASSEvents;
}
@end

@implementation FDMovieDecoder

@dynamic duration;
@dynamic position;
@dynamic frameWidth;
@dynamic frameHeight;
@dynamic sampleRate;
@dynamic subtitleStreamsCount;
@dynamic selectedSubtitleStream;
@dynamic validVideo;
@dynamic validSubtitles;
@dynamic info;
@dynamic videoStreamFormatName;
@dynamic startTime;

#pragma mark - Custom Accessors

- (CGFloat)duration {
    if (!_formatCtx) {
        return 0;
    }
    if (_formatCtx->duration == AV_NOPTS_VALUE) {
        return MAXFLOAT;
    }
    return (CGFloat)_formatCtx->duration / AV_TIME_BASE;
}

- (CGFloat)position {
    return _position;
}

- (void)setPosition: (CGFloat)seconds {
    _position = seconds;
    _isEOF = NO;
	   
    if (_videoStream != -1) {
        int64_t ts = (int64_t)(seconds / _videoTimeBase);
        avformat_seek_file(_formatCtx, _videoStream, ts, ts, ts, AVSEEK_FLAG_FRAME);
        avcodec_flush_buffers(_videoCodecCtx);
    }
}

- (NSUInteger)frameWidth {
    return _videoCodecCtx ? _videoCodecCtx->width : 0;
}

- (NSUInteger)frameHeight {
    return _videoCodecCtx ? _videoCodecCtx->height : 0;
}

- (NSUInteger)subtitleStreamsCount {
    return [_subtitleStreams count];
}

- (NSInteger)selectedSubtitleStream {
    if (_subtitleStream == -1) {
        return -1;
    }
    return [_subtitleStreams indexOfObject:@(_subtitleStream)];
}

- (void)setSelectedSubtitleStream:(NSInteger)selected {
    [self closeSubtitleStream];
    
    if (selected == -1) {
        _subtitleStream = -1;
    } else {
        NSInteger subtitleStream = [_subtitleStreams[selected] integerValue];
        FDMovieDecoderError errCode = [self openSubtitleStream:subtitleStream];
        if (FDMovieDecoderErrorNone != errCode) {
            NSLog(@"%@", errorMessage(errCode));
        }
    }
}

- (BOOL)validVideo {
    return _videoStream != -1;
}

- (BOOL)validSubtitles {
    return _subtitleStream != -1;
}

- (NSDictionary *)info {
    if (!_info) {
        NSMutableDictionary *md = [NSMutableDictionary dictionary];
        
        if (_formatCtx) {
            const char *formatName = _formatCtx->iformat->name;
            [md setValue:[NSString stringWithCString:formatName encoding:NSUTF8StringEncoding] forKey:@"format"];
            
            if (_formatCtx->bit_rate) {
                [md setValue: [NSNumber numberWithInt:_formatCtx->bit_rate] forKey: @"bitrate"];
            }
            
            if (_formatCtx->metadata) {
                
                NSMutableDictionary *md1 = [NSMutableDictionary dictionary];
                
                AVDictionaryEntry *tag = NULL;
                while((tag = av_dict_get(_formatCtx->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
                    
                    [md1 setValue:[NSString stringWithCString:tag->value encoding:NSUTF8StringEncoding]
                           forKey:[NSString stringWithCString:tag->key encoding:NSUTF8StringEncoding]];
                }
                
                [md setValue: [md1 copy] forKey: @"metadata"];
            }
            
            char buf[256];
            
            if (_videoStreams.count) {
                NSMutableArray *ma = [NSMutableArray array];
                for (NSNumber *n in _videoStreams) {
                    AVStream *st = _formatCtx->streams[n.integerValue];
                    avcodec_string(buf, sizeof(buf), st->codec, 1);
                    NSString *s = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
                    if ([s hasPrefix:@"Video: "])
                        s = [s substringFromIndex:@"Video: ".length];
                    [ma addObject:s];
                }
                md[@"video"] = ma.copy;
            }
            
            if (_subtitleStreams.count) {
                NSMutableArray *ma = [NSMutableArray array];
                for (NSNumber *n in _subtitleStreams) {
                    AVStream *st = _formatCtx->streams[n.integerValue];
                    
                    NSMutableString *ms = [NSMutableString string];
                    AVDictionaryEntry *lang = av_dict_get(st->metadata, "language", NULL, 0);
                    if (lang && lang->value) {
                        [ms appendFormat:@"%s ", lang->value];
                    }
                    
                    avcodec_string(buf, sizeof(buf), st->codec, 1);
                    NSString *s = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
                    if ([s hasPrefix:@"Subtitle: "])
                        s = [s substringFromIndex:@"Subtitle: ".length];
                    [ms appendString:s];
                    
                    [ma addObject:ms.copy];
                }
                md[@"subtitles"] = ma.copy;
            }
            
        }
        
        _info = [md copy];
    }
    
    return _info;
}

- (NSString *)videoStreamFormatName {
    if (!_videoCodecCtx) {
        return nil;
    }
    
    if (_videoCodecCtx->pix_fmt == AV_PIX_FMT_NONE) {
        return @"";
    }
    
    const char *name = av_get_pix_fmt_name(_videoCodecCtx->pix_fmt);
    return name ? [NSString stringWithCString:name encoding:NSUTF8StringEncoding] : @"?";
}

- (CGFloat) startTime {
    if (_videoStream != -1) {
        
        AVStream *st = _formatCtx->streams[_videoStream];
        if (AV_NOPTS_VALUE != st->start_time)
            return st->start_time * _videoTimeBase;
        return 0;
    }
    
    return 0;
}

- (BOOL)interruptDecoder {
    if (_interruptCallback) {
        return _interruptCallback();
    }
    return NO;
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
        
        if (av_read_frame(_formatCtx, &packet) < 0) {
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
                        if (decodedDuration > minDuration)
                            finished = YES;
                    }
                }
                
                if (0 == len) {
                    break;
                }
                
                pktSize -= len;
            }
        } else if (packet.stream_index == _artworkStream) {
            
            if (packet.size) {
                
                FDArtworkFrame *frame = [[FDArtworkFrame alloc] init];
                frame.picture = [NSData dataWithBytes:packet.data length:packet.size];
                [result addObject:frame];
            }
            
        } else if (packet.stream_index == _subtitleStream) {
            
            int pktSize = packet.size;
            
            while (pktSize > 0) {
                
                AVSubtitle subtitle;
                int gotsubtitle = 0;
                int len = avcodec_decode_subtitle2(_subtitleCodecCtx, &subtitle, &gotsubtitle, &packet);
                
                if (len < 0) {
                    NSLog(@"decode subtitle error, skip packet");
                    break;
                }
                
                if (gotsubtitle) {
                    
                    FDSubtitleFrame *frame = [self handleSubtitle: &subtitle];
                    if (frame) {
                        [result addObject:frame];
                    }
                    avsubtitle_free(&subtitle);
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

- (BOOL)openFile:(NSString *)path {
    NSAssert(path, @"nil path");
    NSAssert(!_formatCtx, @"already open");
    
    _isNetwork = isNetworkPath(path);
    
    static BOOL needNetworkInit = YES;
    if (needNetworkInit && _isNetwork) {
        needNetworkInit = NO;
        avformat_network_init();
    }
    
    _path = path;
    
    FDMovieDecoderError errCode = [self openInput: path];
    if (errCode == FDMovieDecoderErrorNone) {
        FDMovieDecoderError videoErr = [self openVideoStream];
        _subtitleStream = -1;
        if (videoErr != FDMovieDecoderErrorNone) {
            errCode = videoErr; // both fails
        } else {
            _subtitleStreams = collectStreams(_formatCtx, AVMEDIA_TYPE_SUBTITLE);
        }
    }
    
    if (errCode != FDMovieDecoderErrorNone) {
        [self closeFile];
        NSString *errMsg = errorMessage(errCode);
        NSLog(@"%@, %@", errMsg, path.lastPathComponent);
        return NO;
    }
    
    return YES;
}

#pragma mark - Private

- (FDMovieDecoderError)openInput:(NSString *)path {
    AVFormatContext *formatCtx = NULL;
    
    if (_interruptCallback) {
        
        formatCtx = avformat_alloc_context();
        if (!formatCtx) {
            return FDMovieDecoderErrorOpenFile;
        }
        
        AVIOInterruptCB cb = {interrupt_callback, (__bridge void *)(self)};
        formatCtx->interrupt_callback = cb;
    }
    
    if (avformat_open_input(&formatCtx, [path cStringUsingEncoding: NSUTF8StringEncoding], NULL, NULL) < 0) {
        if (formatCtx) {
            avformat_free_context(formatCtx);
        }
        return FDMovieDecoderErrorOpenFile;
    }
    
    if (avformat_find_stream_info(formatCtx, NULL) < 0) {
        avformat_close_input(&formatCtx);
        return FDMovieDecoderErrorStreamInfoNotFound;
    }
    
    av_dump_format(formatCtx, 0, [path.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], false);
    
    _formatCtx = formatCtx;
    return FDMovieDecoderErrorNone;
}

- (FDMovieDecoderError) openVideoStream {
    FDMovieDecoderError errCode = FDMovieDecoderErrorStreamNotFound;
    _videoStream = -1;
    _artworkStream = -1;
    _videoStreams = collectStreams(_formatCtx, AVMEDIA_TYPE_VIDEO);
    for (NSNumber *n in _videoStreams) {
        const NSUInteger iStream = n.integerValue;
        if (0 == (_formatCtx->streams[iStream]->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
            errCode = [self openVideoStream:iStream];
            if (errCode == FDMovieDecoderErrorNone) {
                break;
            }
        } else {
            _artworkStream = iStream;
        }
    }
    
    return errCode;
}

- (FDMovieDecoderError)openVideoStream:(NSInteger)videoStream {
    // get a pointer to the codec context for the video stream
    AVCodecContext *codecCtx = _formatCtx->streams[videoStream]->codec;
    
    // find the decoder for the video stream
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec) {
        return FDMovieDecoderErrorCodecNotFound;
    }
    
    // inform the codec that we can handle truncated bitstreams -- i.e.,
    // bitstreams where frame boundaries can fall in the middle of packets
    //if(codec->capabilities & CODEC_CAP_TRUNCATED)
    //    _codecCtx->flags |= CODEC_FLAG_TRUNCATED;
    
    // open codec
    if (avcodec_open2(codecCtx, codec, NULL) < 0) {
        return FDMovieDecoderErrorOpenCodec;
    }
    
    _videoFrame = av_frame_alloc();
    
    if (!_videoFrame) {
        avcodec_close(codecCtx);
        return FDMovieDecoderErrorAllocateFrame;
    }
    
    _videoStream = videoStream;
    _videoCodecCtx = codecCtx;
    
    // determine fps
    
    AVStream *st = _formatCtx->streams[_videoStream];
    avStreamFPSTimeBase(st, 0.04, &_fps, &_videoTimeBase);
    
    NSLog(@"video codec size: %d:%d fps: %.3f tb: %f",
                self.frameWidth,
                self.frameHeight,
                _fps,
                _videoTimeBase);
    
    NSLog(@"video start time %f", st->start_time * _videoTimeBase);
    NSLog(@"video disposition %d", st->disposition);
    
    return FDMovieDecoderErrorNone;
}

- (FDMovieDecoderError)openSubtitleStream:(NSInteger)subtitleStream {
    AVCodecContext *codecCtx = _formatCtx->streams[subtitleStream]->codec;
    
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if(!codec) {
        return FDMovieDecoderErrorCodecNotFound;
    }
    
    const AVCodecDescriptor *codecDesc = avcodec_descriptor_get(codecCtx->codec_id);
    if (codecDesc && (codecDesc->props & AV_CODEC_PROP_BITMAP_SUB)) {
        // Only text based subtitles supported
        return FDMovieErroUnsupported;
    }
    
    if (avcodec_open2(codecCtx, codec, NULL) < 0) {
        return FDMovieDecoderErrorOpenCodec;
    }
    
    _subtitleStream = subtitleStream;
    _subtitleCodecCtx = codecCtx;
    
    NSLog(@"subtitle codec: '%s' mode: %d enc: %s", codecDesc->name, codecCtx->sub_charenc_mode, codecCtx->sub_charenc);
    
    _subtitleASSEvents = -1;
    
    if (codecCtx->subtitle_header_size) {
        NSString *s = [[NSString alloc] initWithBytes:codecCtx->subtitle_header
                                               length:codecCtx->subtitle_header_size
                                             encoding:NSASCIIStringEncoding];
        
        if (s.length) {
            NSArray *fields = [FDMovieSubtitleASSParser parseEvents:s];
            if (fields.count && [fields.lastObject isEqualToString:@"Text"]) {
                _subtitleASSEvents = fields.count;
                NSLog(@"subtitle ass events: %@", [fields componentsJoinedByString:@","]);
            }
        }
    }
    
    return FDMovieDecoderErrorNone;
}

- (void)closeFile {
    [self closeVideoStream];
    [self closeSubtitleStream];
    
    _videoStreams = nil;
    _subtitleStreams = nil;
    
    if (_formatCtx) {
        _formatCtx->interrupt_callback.opaque = NULL;
        _formatCtx->interrupt_callback.callback = NULL;
        
        avformat_close_input(&_formatCtx);
        _formatCtx = NULL;
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

- (void) closeSubtitleStream {
    _subtitleStream = -1;
    
    if (_subtitleCodecCtx) {
        avcodec_close(_subtitleCodecCtx);
        _subtitleCodecCtx = NULL;
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
    NSLog(@"Frame: position %.4f duration %.4f | pkt_pos %lld ", frame.position, frame.duration, av_frame_get_pkt_pos(_videoFrame));
    
    return frame;
}

- (FDSubtitleFrame *)handleSubtitle: (AVSubtitle *)pSubtitle {
    NSMutableString *ms = [NSMutableString string];
    for (NSUInteger i = 0; i < pSubtitle->num_rects; ++i) {
        AVSubtitleRect *rect = pSubtitle->rects[i];
        if (rect) {
            if (rect->text) { // rect->type == SUBTITLE_TEXT
                NSString *s = [NSString stringWithUTF8String:rect->text];
                if (s.length) [ms appendString:s];
            } else if (rect->ass && _subtitleASSEvents != -1) {
                NSString *s = [NSString stringWithUTF8String:rect->ass];
                if (s.length) {
                    NSArray *fields = [FDMovieSubtitleASSParser parseDialogue:s numFields:_subtitleASSEvents];
                    if (fields.count && [fields.lastObject length]) {
                        s = [FDMovieSubtitleASSParser removeCommandsFromEventText: fields.lastObject];
                        if (s.length) [ms appendString:s];
                    }
                }
            }
        }
    }
    
    if (!ms.length) {
        return nil;
    }
    
    FDSubtitleFrame *frame = [[FDSubtitleFrame alloc] init];
    frame.text = [ms copy];
    frame.position = pSubtitle->pts / AV_TIME_BASE + pSubtitle->start_display_time;
    frame.duration = (CGFloat)(pSubtitle->end_display_time - pSubtitle->start_display_time) / 1000.f;
    
    return frame;
}

@end


static int interrupt_callback(void *ctx) {
    if (!ctx) {
        return 0;
    }
    __unsafe_unretained FDMovieDecoder *p = (__bridge FDMovieDecoder *)ctx;
    const BOOL r = [p interruptDecoder];
    if (r) {
        NSLog(@"DEBUG: INTERRUPT_CALLBACK!");
    }
    return r;
}


@implementation FDMovieSubtitleASSParser

+ (NSArray *)parseEvents:(NSString *)events {
    NSRange r = [events rangeOfString:@"[Events]"];
    if (r.location != NSNotFound) {
        
        NSUInteger pos = r.location + r.length;
        
        r = [events rangeOfString:@"Format:"
                          options:0
                            range:NSMakeRange(pos, events.length - pos)];
        
        if (r.location != NSNotFound) {
            
            pos = r.location + r.length;
            r = [events rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
                                        options:0
                                          range:NSMakeRange(pos, events.length - pos)];
            
            if (r.location != NSNotFound) {
                
                NSString *format = [events substringWithRange:NSMakeRange(pos, r.location - pos)];
                NSArray *fields = [format componentsSeparatedByString:@","];
                if (fields.count > 0) {
                    
                    NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
                    NSMutableArray *ma = [NSMutableArray array];
                    for (NSString *s in fields) {
                        [ma addObject:[s stringByTrimmingCharactersInSet:ws]];
                    }
                    return ma;
                }
            }
        }
    }
    
    return nil;
}

+ (NSArray *)parseDialogue:(NSString *)dialogue numFields:(NSUInteger)numFields {
    if ([dialogue hasPrefix:@"Dialogue:"]) {
        NSMutableArray *ma = [NSMutableArray array];
        
        NSRange r = {@"Dialogue:".length, 0};
        NSUInteger n = 0;
        
        while (r.location != NSNotFound && n++ < numFields) {
            const NSUInteger pos = r.location + r.length;
            
            r = [dialogue rangeOfString:@","
                                options:0
                                  range:NSMakeRange(pos, dialogue.length - pos)];
            
            const NSUInteger len = r.location == NSNotFound ? dialogue.length - pos : r.location - pos;
            NSString *p = [dialogue substringWithRange:NSMakeRange(pos, len)];
            p = [p stringByReplacingOccurrencesOfString:@"\\N" withString:@"\n"];
            [ma addObject: p];
        }
        
        return ma;
    }
    
    return nil;
}

+ (NSString *)removeCommandsFromEventText:(NSString *)text {
    NSMutableString *ms = [NSMutableString string];
    
    NSScanner *scanner = [NSScanner scannerWithString:text];
    while (!scanner.isAtEnd) {
        NSString *s;
        if ([scanner scanUpToString:@"{\\" intoString:&s]) {
            [ms appendString:s];
        }
        
        if (!([scanner scanString:@"{\\" intoString:nil] &&
              [scanner scanUpToString:@"}" intoString:nil] &&
              [scanner scanString:@"}" intoString:nil])) {
            break;
        }
    }
    
    return ms;
}

@end
