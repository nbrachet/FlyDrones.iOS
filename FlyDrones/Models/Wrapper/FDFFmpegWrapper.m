//
//  FDFFmpegWrapper.m
//  FlyDrones
//
//  Created by Sergey Galagan on 1/30/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDFFmpegWrapper.h"

#import "FDFFmpegFrameEntity.h"

#import "Constants.h"

#import "avformat.h"
#import "avcodec.h"
#import "swscale.h"
#import <libkern/OSAtomic.h>


#pragma mark - Private interface methods

@interface FDFFmpegWrapper ()

#pragma mark - Properties

@property (nonatomic, assign) AVFormatContext *formatCtx;
@property (nonatomic, assign) AVCodecContext  *codecCtx;
@property (nonatomic, assign) AVCodec         *codec;
@property (nonatomic, assign) AVFrame         *frame;
@property (nonatomic, assign) AVPacket        packet;
@property (nonatomic, assign) AVDictionary    *optionsDict;
@property (nonatomic, assign) int videoStream;

@property (nonatomic) dispatch_semaphore_t outputSinkQueueSema;
@property (nonatomic) dispatch_group_t decode_queue_group;

@property (nonatomic) volatile bool stopDecode;
@property (nonatomic, assign) CFTimeInterval previousDecodedFrameTime;

@end


#pragma mark - Public interface methods

@implementation FDFFmpegWrapper

#pragma mark - Class methods

+ (FDFFmpegWrapper *)sharedInstance
{
    static FDFFmpegWrapper *sharedInstance;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    
    
    return sharedInstance;
}


#pragma mark - Instance methods

- (instancetype)init
{
    self = [super init];

    if(self)
    {
        self.formatCtx = NULL;
        self.codecCtx = NULL;
        self.codec = NULL;
        self.frame = NULL;
        self.optionsDict = NULL;
        
        av_register_all();
        avformat_network_init();
        
        self.outputSinkQueueSema = dispatch_semaphore_create((long)(5));
        self.decode_queue_group = dispatch_group_create();
        
        OSMemoryBarrier();
        self.stopDecode = false;
        self.previousDecodedFrameTime = 0;
    }
    
    
    return self;
}

- (int)openURLPath:(NSString *)urlPath
{
    if (self.formatCtx != NULL || self.codec != NULL)
        return -1;
    
    int open_status = avformat_open_input(&self->_formatCtx, urlPath.UTF8String, NULL, NULL);
    if (open_status != 0)
    {
        NSLog(@"error opening stream");
        [self dealloc_helper];
        return -1;
    }
    
    self.formatCtx->fps_probe_size = -1;
    
    int stream_info_status = avformat_find_stream_info(self.formatCtx, NULL);
    if(stream_info_status < 0)
    {
        [self dealloc_helper];
        return -1;
    }
    
    self.videoStream = -1;
    
    for(int i = 0; i < self.formatCtx->nb_streams; i++)
    {
        if(self.formatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO)
        {
            self.videoStream = i;
            break;
        }
    }
    
    if(self.videoStream == -1)
    {
        [self dealloc_helper];
        return -1;
    }
    
    self.codecCtx = self.formatCtx->streams[self.videoStream]->codec;
    self.codec = avcodec_find_decoder(self.codecCtx->codec_id);

    if(self.codec == NULL)
    {
        NSLog(@"Unsupported codec!\n");
        [self dealloc_helper];
        return -1;
    }
    
    av_dump_format(self.formatCtx, 0, urlPath.UTF8String, 0);
    
    if(avcodec_open2(self.codecCtx, self.codec, &self->_optionsDict) < 0)
    {
        [self dealloc_helper];
        return -1;
    }
    
    self.frame = av_frame_alloc();
    if (!self.frame)
    {
        [self dealloc_helper];
        return -1;
    }
    
    
    return 0;
}


#pragma mark - Start/Stop stream/file

- (int)startDecodingWithCallbackBlock:(void(^)(FDFFmpegFrameEntity *frameEntity))frameCallbackBlock
                      waitForConsumer:(BOOL)wait
                   completionCallback:(void(^)())completion
{
    OSMemoryBarrier();
    self.stopDecode = false;
    dispatch_queue_t decodeQueue = dispatch_queue_create("decodeQueue", NULL);
    
    dispatch_async(decodeQueue, ^{
    
        int frameFinished;
        OSMemoryBarrier();
        
        while (self.stopDecode == false)
        {
            @autoreleasepool
            {
                av_init_packet(&_packet);
                _packet.data = NULL;
                _packet.size = 0;
                
                AVStream *stream = self.formatCtx->streams[0];
                av_stream_set_r_frame_rate(stream, (AVRational){25,1});
                self.formatCtx->streams[0] = stream;
                
                self.codecCtx->framerate = (AVRational){25,1};
                if (av_read_frame(self.formatCtx, &self->_packet) >= 0)
                {
                    if(self.packet.stream_index == self.videoStream)
                    {
                        avcodec_decode_video2(self.codecCtx, self.frame, &frameFinished, &self->_packet);
                        
                        // Setup picture width and height
                        self.frame->width = self.codecCtx->coded_width;
                        self.frame->height = self.codecCtx->coded_height;
                        
                        if(frameFinished)
                        {
                            FDFFmpegFrameEntity *entity = [self createFrameData:self.frame trimPadding:YES];
                            frameCallbackBlock(entity);
                        }
                    }
                    
                    av_free_packet(&_packet);
                }
                else
                {
                    usleep(1000);
                }
            }
        }
        
        completion();
    });
    
    
    return 0;
}

- (void)stopDecoding
{
    self.stopDecode = true;
}

- (FDFFmpegFrameEntity *)createFrameData:(AVFrame *)frame trimPadding:(BOOL)trimState
{
    FDFFmpegFrameEntity *frameData = [[FDFFmpegFrameEntity alloc] init];
    
    if (trimState)
    {
        frameData.colorPlane0 = [NSMutableData new];
        frameData.colorPlane1 = [NSMutableData new];
        frameData.colorPlane2 = [NSMutableData new];
        
        for (int i = 0; i < frame->height; i++)
        {
            [frameData.colorPlane0 appendBytes:(void *)(frame->data[0] + i * frame->linesize[0])
                                        length:frame->width];
        }
        
        for (int i = 0; i < frame->height/2; i++)
        {
            [frameData.colorPlane1 appendBytes:(void *)(frame->data[1] + i * frame->linesize[1])
                                        length:frame->width/2];
            
            [frameData.colorPlane2 appendBytes:(void *)(frame->data[2] + i * frame->linesize[2])
                                        length:frame->width/2];
        }
        
        frameData.lineSize0 = @(frame->width);
        frameData.lineSize1 = @(frame->width/2);
        frameData.lineSize2 = @(frame->width/2);
    }
    else
    {
        frameData.colorPlane0 = [[NSMutableData alloc] initWithBytes:frame->data[0] length:frame->linesize[0] * frame->height];
        frameData.colorPlane1 = [[NSMutableData alloc] initWithBytes:frame->data[1] length:frame->linesize[1] * frame->height/2];
        frameData.colorPlane2 = [[NSMutableData alloc] initWithBytes:frame->data[2] length:frame->linesize[2] * frame->height/2];
        
        frameData.lineSize0 = @(frame->linesize[0]);
        frameData.lineSize1 = @(frame->linesize[1]);
        frameData.lineSize2 = @(frame->linesize[2]);
    }
    
    frameData.width = @(frame->width);
    frameData.height = @(frame->height);
    
    
    return frameData;
}


#pragma mark - Memory management methods

- (void)dealloc_helper
{
    if (self.frame)
        av_free(self.frame);
    
    if (self.codecCtx)
        avcodec_close(self.codecCtx);

    if (self.formatCtx)
        avformat_close_input(&self->_formatCtx);
}

- (void)dealloc
{
    [self stopDecoding];
    sleep(1);
    [self dealloc_helper];
}

#pragma mark -

@end
