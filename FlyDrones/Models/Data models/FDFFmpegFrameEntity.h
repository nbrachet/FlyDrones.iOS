//
//  FDFFmpegFrameEntity.h
//  FlyDrones
//
//  Created by Sergey Galagan on 1/30/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//


@interface FDFFmpegFrameEntity : NSObject

#pragma mark - Properties

@property (nonatomic, strong) NSMutableData *colorPlane0;
@property (nonatomic, strong) NSMutableData *colorPlane1;
@property (nonatomic, strong) NSMutableData *colorPlane2;
@property (nonatomic, strong) NSNumber *lineSize0;
@property (nonatomic, strong) NSNumber *lineSize1;
@property (nonatomic, strong) NSNumber *lineSize2;
@property (nonatomic, strong) NSNumber *width;
@property (nonatomic, strong) NSNumber *height;

@end
