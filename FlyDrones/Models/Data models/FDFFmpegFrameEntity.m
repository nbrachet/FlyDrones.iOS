//
//  FDFFmpegFrameEntity.m
//  FlyDrones
//
//  Created by Sergey Galagan on 1/30/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDFFmpegFrameEntity.h"


#pragma mark - Public interface methods

@implementation FDFFmpegFrameEntity

- (instancetype)initEntityFrame:(AVFrame *)frame
{
    self = [super init];
    
    if(self)
    {
        self.colorPlane0 = [NSMutableData new];
        self.colorPlane1 = [NSMutableData new];
        self.colorPlane2 = [NSMutableData new];
        
        for (int i = 0; i < frame->height; i++)
        {
            [self.colorPlane0 appendBytes:(void *)(frame->data[0] + i * frame->linesize[0])
                                        length:frame->width];
        }
        
        for (int i = 0; i < frame->height/2; i++)
        {
            [self.colorPlane1 appendBytes:(void *)(frame->data[1] + i * frame->linesize[1])
                                        length:frame->width/2];
            
            [self.colorPlane2 appendBytes:(void *)(frame->data[2] + i * frame->linesize[2])
                                        length:frame->width/2];
        }
        
        self.lineSize0 = @(frame->width);
        self.lineSize1 = @(frame->width/2);
        self.lineSize2 = @(frame->width/2);
        
        self.width = @(frame->width);
        self.height = @(frame->height);
    }
    
    
    return self;
}

@end
