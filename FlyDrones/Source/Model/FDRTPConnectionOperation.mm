//
//  FDRTPConnectionOperation.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 6/11/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import "FDRTPConnectionOperation.h"
#import "RTP.h"

// see FF_INPUT_BUFFER_PADDING_SIZE in libavcodec/avcodec.h
#define FF_INPUT_BUFFER_PADDING_SIZE 32

static size_t roundup(size_t x, size_t y);

@interface FDRTPConnectionOperation ()

@end

@implementation FDRTPConnectionOperation

#pragma mark - Lifecycle

- (void)main {
    @autoreleasepool {
        logger.level(Logger::LEVEL_WARN);
#ifndef NDEBUG
        (void) logger.open("com.flydrones", "app");
        logger.add_log_file(STDERR_FILENO);
#endif

        struct sockaddr_in socketAddress;
        if (UDP::resolve_sockaddr_in(&socketAddress, [self.host UTF8String], (unsigned)self.port) == -1) {
            return;
        }
    
        H264RTPReceiver rtp;
        if (!rtp) {
            return;
        }
        
        size_t bufferSize = roundup(rtp.rcvbufsiz() + sizeof(H264::START_SEQUENCE) + FF_INPUT_BUFFER_PADDING_SIZE, getpagesize());  // ffmpeg requires additionally allocated bytes at the end of the input bitstream for decoding
        LOGGER_DEBUG("bufferSize set to %.1fiB", (float)bufferSize);
        void* buffer = NULL;

        struct timeval tv0 = {0, 0};

        while (!self.isCancelled) {
            @autoreleasepool {
                if (tv0.tv_sec == 0) {
                    (void) rtp.send((void*) NULL, 0, MSG_DONTWAIT, NULL, &socketAddress);
                }

                if (!buffer) {
                    buffer = malloc(bufferSize);
                    if (!buffer) {
                        LOGGER_PERROR("malloc(%zu)", bufferSize);
                        break;
                    }
                }

                struct timeval timeout = {1, 0};
                ssize_t receivedDataSize = rtp.recv(reinterpret_cast<char*>(buffer) + sizeof(H264::START_SEQUENCE),
                                                    bufferSize - sizeof(H264::START_SEQUENCE) - FF_INPUT_BUFFER_PADDING_SIZE,
                                                    &timeout);
                if (receivedDataSize == -1) {
                    if (errno == EINTR) {
                        continue;
                    }
                    if (errno == EWOULDBLOCK) {
                        if (tv0.tv_sec > 0) {
                            tv0.tv_sec = 0;
                        }
                        continue;
                    }
                    LOGGER_PERROR("recv");
                    break;
                }
                
                if (receivedDataSize == 0) {
                    continue;
                }
                
                if (tv0.tv_sec == 0) {
                    if (gettimeofday(&tv0, NULL) == -1) {
                        LOGGER_PERROR("gettimeofday");
                        tv0.tv_sec = 0;
                    }
                }
                
                if ((size_t)receivedDataSize >= bufferSize - sizeof(H264::START_SEQUENCE - FF_INPUT_BUFFER_PADDING_SIZE)) {
                    const size_t newBufferSize = roundup(receivedDataSize + sizeof(H264::START_SEQUENCE) + FF_INPUT_BUFFER_PADDING_SIZE, getpagesize());
                    receivedDataSize = bufferSize - sizeof(H264::START_SEQUENCE) - FF_INPUT_BUFFER_PADDING_SIZE;
                    bufferSize = newBufferSize;
                    LOGGER_DEBUG("Increasing bufferSize to %.1fiB", (float)bufferSize);
                }

                memcpy(buffer, &H264::START_SEQUENCE, sizeof(H264::START_SEQUENCE));
                receivedDataSize += sizeof(H264::START_SEQUENCE);
                memset(reinterpret_cast<char*>(buffer) + receivedDataSize, 0, sizeof(uint32_t));

                NSData *receivedData = [[NSData alloc] initWithBytesNoCopy:buffer
                                                                    length:receivedDataSize
                                                               deallocator:^(void *bytes, NSUInteger length) {
                                                                   free(bytes);
                                                               }];
                buffer = NULL;

                [self notifyOnReceivingData:receivedData];
            }
        }
        rtp.close();
        if (buffer) {
            free(buffer);
        }
    }
}

#pragma mark - Private

- (void)notifyOnReceivingData:(NSData *)data {
    if (self.delegate == nil) {
        return;
    }
    if (![self.delegate respondsToSelector:@selector(rtpConnectionOperation:didReceiveData:)]) {
        return;
    }
    
    [self.delegate rtpConnectionOperation:self didReceiveData:data];
}

#pragma mark - Helpers

static size_t roundup(size_t x, size_t y) {
    return ((x + y - 1) / y) * y;
}

@end
