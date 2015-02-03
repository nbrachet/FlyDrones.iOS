//
//  FDVideoStreamingController.h
//  FlyDrones
//
//  Created by Sergey Galagan on 2/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import <GLKit/GLKit.h>

@class FDFFmpegFrameEntity;

@interface FDVideoStreamingController : GLKViewController

#pragma mark - Instance methods

- (int)loadVideoEntity:(FDFFmpegFrameEntity *)videoEntity;

#pragma mark -

@end
