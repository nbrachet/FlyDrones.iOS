//
//  FDRTPConnectionOperation.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 6/11/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import "FDRTPConnectionOperation.h"
#import "RTP.h"

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
        
        size_t bufferSize = rtp.rcvbufsiz() + sizeof(H264::START_SEQUENCE);
        void* buffer = malloc(bufferSize);
        if (!buffer) {
            return;
        }
        memcpy(buffer, &H264::START_SEQUENCE, sizeof(H264::START_SEQUENCE));

        struct timeval tv0 = {0, 0};

        while (!self.isCancelled) {
            @autoreleasepool {
                if (tv0.tv_sec == 0) {
                    if (rtp.send((void*) NULL, 0, MSG_DONTWAIT, NULL, &socketAddress) == -1) {
                        break;
                    }
                }
                
                struct timeval timeout = {1, 0};
                ssize_t receivedDataSize = rtp.recv(reinterpret_cast<char*>(buffer) + sizeof(H264::START_SEQUENCE),
                                                    bufferSize - sizeof(H264::START_SEQUENCE),
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
                
                if ((size_t)receivedDataSize >= bufferSize - sizeof(H264::START_SEQUENCE)) {
                    const size_t newBufferSize = roundup(receivedDataSize + sizeof(H264::START_SEQUENCE), getpagesize());
                    receivedDataSize = bufferSize - sizeof(H264::START_SEQUENCE);
                    bufferSize = newBufferSize;
                    
                    LOGGER_NOTICE("Increasing bufsiz to %.1fiB", (float)bufferSize);
                    
                    buffer = realloc(buffer, bufferSize);
                    if (!buffer) {
                        break;
                    }
                }
                
                if (receivedDataSize == 0) {
                    continue;
                }
                
                if (tv0.tv_sec == 0) {
                    if (gettimeofday(&tv0, NULL) == -1) {
                        LOGGER_PERROR("gettimeofday");
                        break;
                    }
                }
                
                receivedDataSize += sizeof(H264::START_SEQUENCE);
                NSData *receivedData = [NSData dataWithBytes:buffer length:receivedDataSize];
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
    if (data.length == 0) {
        return;
    }
    
    if (self.delegate == nil) {
        return;
    }
    
    if (![self.delegate respondsToSelector:@selector(rtpConnectionOperation:didReceiveData:)]) {
        return;
    }
    
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf.delegate rtpConnectionOperation:strongSelf didReceiveData:data];
    });
}

#pragma mark - Helpers

static size_t roundup(size_t x, size_t y) {
    return ((x + y - 1) / y) * y;
}

@end
