//
//  FDFFmpegWrapper.h
//  FlyDrones
//
//  Created by Sergey Galagan on 1/30/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//


@interface FDFFmpegWrapper : NSObject

#pragma mark - Instance methods

- (instancetype)init;
- (int)openURLPath:(NSString *)urlPath;

#pragma mark -

@end
