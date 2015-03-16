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

#pragma mark - Private interface methods

@interface FDContextWrapper ()
{
    
}
#pragma mark - Properties

@property (nonatomic, weak) NSString *sourcePath;
@property (nonatomic, assign) uint8_t *buffer; // internal buffer for ffmpeg
@property (nonatomic, assign) int bufferSize;
@property (nonatomic, assign) FILE *fh;
@property (nonatomic, assign) AVIOContext* ioCtx;

@end


#pragma mark - Public interface methods

@implementation FDContextWrapper

#pragma mark - Instnce methods

- (instancetype)initWithSourcePath:(NSString *)path
{
    self = [self init];
    if(self)
    {
        _sourcePath = path;
        
        // open file
        _fh = fopen(self.sourcePath.UTF8String, "rb");
        if (!_fh) {
            NSLog(@"Failed to open file %@\n", _sourcePath);
        }
        
        _bufferSize = ftell(_fh);
        _buffer = (uint8_t *)av_malloc(_bufferSize);
        
        // allocate the AVIOContext
        self.ioCtx = avio_alloc_context(
                                   _buffer, _bufferSize, // internal buffer and its size
                                   0,            // write flag (1=true,0=false)
                                   (__bridge void*)self,  // user data, will be passed to our callback functions
                                   IOReadFunc, 
                                   0,            // no writing
                                   IOSeekFunc
                                   );
    }
    
    
    return self;
}

- (void)initAVFormatContext:(AVFormatContext *)pCtx
{
    pCtx->pb = self.ioCtx;
    pCtx->flags |= AVFMT_FLAG_CUSTOM_IO;
    
    // or read some of the file and let ffmpeg do the guessing
    size_t len = fread(_buffer, 1, _bufferSize, _fh);
    if (len == 0) return;
    fseek(_fh, 0, SEEK_SET); // reset to beginning of file
    
    AVProbeData probeData;
    probeData.buf = _buffer;
    probeData.buf_size = _bufferSize - 1;
//    probeData.filename = "";
    pCtx->iformat = av_find_input_format("h264");// av_probe_input_format(&probeData, 1);
}


static int IOReadFunc(void *data, uint8_t *buf, int buf_size)
{
    FDContextWrapper *hctx = (__bridge FDContextWrapper*)data;
    size_t len = fread(buf, 1, buf_size, hctx->_fh);
    if (len == 0) {
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
