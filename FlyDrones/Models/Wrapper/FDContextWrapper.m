//
//  FDContextWrapper.m
//  FlyDrones
//
//  Created by Sergey Galagan on 3/16/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDContextWrapper.h"

#import "avio.h"
#import "stdio.h"

#include "avcodec.h"
#include "avformat.h"
#include "avio.h"
#include "file.h"


#pragma mark - Private interface methods

@interface FDContextWrapper ()

#pragma mark - Properties

@property (nonatomic, assign) FILE *fh;
@property (nonatomic, assign) AVIOContext* ioCtx;

@end


struct buffer_data {
    uint8_t *ptr;
    size_t size; ///< size left in the buffer
};


#pragma mark - Public interface methods

@implementation FDContextWrapper

#pragma mark - Instnce methods

- (instancetype)initWithSourcePath:(NSString *)path
{
    self = [self init];
    if(self)
    {
        uint8_t *buffer = NULL,
        *avio_ctx_buffer = NULL;
        size_t buffer_size, avio_ctx_buffer_size = 4096;
        
        _fh = fopen(path.UTF8String, "rb");
        if (!_fh) {
            NSLog(@"Failed to open file %@\n", path);
        }
        
        fseek (_fh, 0, SEEK_END);
        buffer_size = ftell(_fh);
        fseek(_fh, 0, SEEK_SET);
        buffer = (uint8_t *)av_malloc(buffer_size * sizeof(uint8_t));
//        self.ioCtx = avio_alloc_context(_buffer, _bufferSize, 0, (__bridge void*)self, IOReadFunc, 0, IOSeekFunc);

//        AVFormatContext *fmt_ctx = NULL;
//        AVIOContext *avio_ctx = NULL;
        
        
//        char *input_filename = path.UTF8String;
        
        int ret = 0;
        struct buffer_data bd = { 0 };
        
        
          /* register codecs and formats and other lavf/lavc components*/
          av_register_all();
        
          /* slurp file content into buffer */
          ret = av_file_map(path.UTF8String, &buffer, &buffer_size, 0, NULL);
//          if (ret < 0)
//              goto end;
        
          /* fill opaque structure used by the AVIOContext read callback */
          bd.ptr = buffer;
          bd.size = buffer_size;
        
//          if (!(fmt_ctx = avformat_alloc_context())) {
//              ret = AVERROR(ENOMEM);
//              goto end;
//          }
        
        
          avio_ctx_buffer = av_malloc(avio_ctx_buffer_size);
          if (!avio_ctx_buffer) {
              ret = AVERROR(ENOMEM);
//              goto end;
          }
        
          self.ioCtx = avio_alloc_context(avio_ctx_buffer, avio_ctx_buffer_size, 0, &bd, &read_packet, NULL, NULL);
          if (!self.ioCtx) {
              ret = AVERROR(ENOMEM);
//              goto end;
          }
        
//        fmt_ctx->pb = avio_ctx;
//        
//        
//        ret = avformat_open_input(&fmt_ctx, NULL, NULL, NULL);
//        
//        if (ret < 0) {
//              fprintf(stderr, "Could not open input\n");
//              goto end;
//              }
//        
//          ret = avformat_find_stream_info(fmt_ctx, NULL);
//          if (ret < 0) {
//              fprintf(stderr, "Could not find stream information\n");
//              goto end;
//              }
//        
//          av_dump_format(fmt_ctx, 0, input_filename, 0);
//        
//         end:
//          avformat_close_input(&fmt_ctx);
//          /* note: the internal buffer could have changed, and be != avio_ctx_buffer */
//          if (avio_ctx) {
//              av_freep(&avio_ctx->buffer);
//              av_freep(&avio_ctx);
//              }
//          av_file_unmap(buffer, buffer_size);
    }
    
    
    return self;
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

- (void)initAVFormatContext:(AVFormatContext *)pCtx
{
    pCtx->pb = self.ioCtx;
    pCtx->flags |= AVFMT_FLAG_CUSTOM_IO;
    pCtx->fps_probe_size = 25;
}


/*
 * Methods for reading data
 */
/*
static int IOReadFunc(void *data, uint8_t *buf, int buf_size)
{
    FDContextWrapper *hctx = (__bridge FDContextWrapper*)data;
    size_t len = fread(buf, 1, buf_size, hctx->_fh);
    if (len == 0)
    {
        // Let FFmpeg know that we have reached EOF, or do something else
        return AVERROR_EOF;
    }
    return (int)len;
}

// whence: SEEK_SET, SEEK_CUR, SEEK_END (like fseek) and AVSEEK_SIZE
static int64_t IOSeekFunc(void *data, int64_t pos, int whence)
{
    if (whence == AVSEEK_SIZE) {
        // return the file size if you wish to
    }
    
    FDContextWrapper *hctx = (__bridge FDContextWrapper*)data;
    int rs = fseek(hctx->_fh, (long)pos, whence);
    if (rs != 0) {
        return -1;
    }
    long fpos = ftell(hctx->_fh); // int64_t is usually long long
    return (int64_t)fpos;
}
*/

- (void)dealloc
{
    if(_fh)
        fclose(_fh);
    
    av_free(self.ioCtx->buffer);
    self.ioCtx->buffer = NULL;
    av_free(self.ioCtx);
}

#pragma mark -

@end
