//
//  FDFFmpegWrapper.m
//  FlyDrones
//
//  Created by Sergey Galagan on 1/30/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDFFmpegWrapper.h"

#import "FDFFmpegFrameEntity.h"
#import "FDContextWrapper.h"

#import "Constants.h"

#import "avformat.h"
#import "avcodec.h"
#import <libkern/OSAtomic.h>

#include "avcodec.h"
#include "avformat.h"
#include "avio.h"
#include "file.h"

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

struct buffer_data {
    uint8_t *ptr;
    size_t size; ///< size left in the buffer
};

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
    
    AVIOContext *avio_ctx = NULL;
    uint8_t *buffer = NULL,
    *avio_ctx_buffer = NULL;
    size_t buffer_size,
    avio_ctx_buffer_size = 0;
    FILE *fh = fopen(urlPath.UTF8String, "rb");
    
    if (!fh) {
        NSLog(@"Failed to open file %@\n", urlPath);
    }

    fseek (fh, 0, SEEK_END);
    avio_ctx_buffer_size = ftell(fh);
    fseek(fh, 0, SEEK_SET);
    
    int ret = 0;
    struct buffer_data bd = { 0 };
    
    ret = av_file_map(urlPath.UTF8String, &buffer, &buffer_size, 0, NULL);
    if(ret < 0 ) {
        return -1;
    }
    
    bd.ptr = buffer;
    bd.size = buffer_size;
    
    if (!(_formatCtx = avformat_alloc_context())) {
        return -1;
    }
    
    
    avio_ctx_buffer = av_malloc(avio_ctx_buffer_size*sizeof(uint8_t));
    if (!avio_ctx_buffer) {
        return -1;
    }
    
    avio_ctx = avio_alloc_context(avio_ctx_buffer, avio_ctx_buffer_size, 0, &bd, &read_packet, NULL, NULL);
    if (!avio_ctx) {
        return -1;
    }
    
    _formatCtx->pb = avio_ctx;
    
    ret = avformat_open_input(&_formatCtx, NULL, NULL, NULL);
    if (ret < 0) {
        NSLog(@"Could not open input\n");
        return -1;
    }
    
    ret = avformat_find_stream_info(_formatCtx, NULL);
    if (ret < 0) {
        NSLog(@"Could not find stream information\n");
        return -1;
    }
    
    self.videoStream = -1;
    self.formatCtx->video_codec_id = AV_CODEC_ID_H264;
    self.formatCtx->video_codec = avcodec_find_decoder(AV_CODEC_ID_H264);
    
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
    
    if(avcodec_open2(self.codecCtx, self.codec, NULL) < 0)
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

static int read_packet(void *opaque, uint8_t *buf, int buf_size)
{
    struct buffer_data *bd = (struct buffer_data *)opaque;
    buf_size = FFMIN(buf_size, bd->size);
    
    
    printf("ptr:%p size:%zu\n", bd->ptr, bd->size);
    
    /* copy internal buffer data to buf */
    memcpy(buf, bd->ptr, buf_size);
    bd->ptr += buf_size;
    bd->size -= buf_size;
    
    return buf_size;
}


#pragma mark - Start/Stop stream/file

- (int)startDecodingWithCallbackBlock:(void(^)(FDFFmpegFrameEntity *frameEntity))frameCallbackBlock
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
                int status = -1;
                @try
                {
                    status = av_read_frame(self.formatCtx, &self->_packet);
                }
                @catch(NSException *ex)
                {
                    NSLog(@"%@", ex);
                }
                
                if (status >= 0)
                {
                    if(self.packet.stream_index == self.videoStream)
                    {
                        avcodec_decode_video2(self.codecCtx, self.frame, &frameFinished, &self->_packet);
                        
                        // Setup picture width and height
                        self.frame->width = self.codecCtx->coded_width;
                        self.frame->height = self.codecCtx->coded_height;
                        
                        if(frameFinished)
                        {
                            FDFFmpegFrameEntity *entity = [[FDFFmpegFrameEntity alloc] initEntityFrame:self.frame];
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
