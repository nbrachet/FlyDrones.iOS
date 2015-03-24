//
//  FDVideoStreamingController.h
//  FlyDrones
//
//  Created by Sergey Galagan on 2/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import <GLKit/GLKit.h>


#pragma mark - Forward class

@class FDFFmpegFrameEntity;


@interface FDVideoStreamingController : GLKViewController

#pragma mark - Instance methods

- (int)loadVideoEntity:(FDFFmpegFrameEntity *)videoEntity;
- (void)resizeToFrame:(CGRect )frame;

#pragma mark -

@end
