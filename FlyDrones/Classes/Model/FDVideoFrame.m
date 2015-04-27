//
//  FDVideoFrame.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/22/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDVideoFrame.h"

@implementation FDVideoFrame

- (instancetype)initWithFrame:(AVFrame *)frame width:(NSUInteger)width height:(NSUInteger)height {
    self = [super init];
    if (self) {
        if (!frame->data[0] || !frame->data[1] || !frame->data[2] || width == 0 || height == 0) {
            self = nil;
            return nil;
        }
        self.width = width;
        self.height = height;
        self.luma = [self copyFrameData:frame->data[0] frameSize:(int)frame->linesize[0] width:(int)width height:(int)height];
        self.chromaB = [self copyFrameData:frame->data[1] frameSize:(int)frame->linesize[1] width:(int)(width / 2) height:(int)(height / 2)];
        self.chromaR = [self copyFrameData:frame->data[2] frameSize:(int)frame->linesize[2] width:(int)(width / 2) height:(int)(height  / 2)];
        
        if (self.luma.length == 0 || self.chromaB.length == 0 || self.chromaR.length == 0) {
            self = nil;
            return nil;
        }

    }
    return self;
}

- (void)dealloc {
    self.luma = nil;
    self.chromaB = nil;
    self.chromaR = nil;
}

#pragma mark - Private

- (NSData *)copyFrameData:(UInt8 *)source frameSize:(int)linesize width:(int)width height:(int)height {
    if (linesize == 0 || width == 0 || height == 0) {
        return nil;
    }
    width = MIN(linesize, width);
    NSMutableData *newData = [NSMutableData dataWithLength:width * height];
    Byte *newDataBytes = newData.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(newDataBytes, source, width);
        newDataBytes += width;
        source += linesize;
    }
    return newData;
}

@end
