//
//  FDContextWrapper.h
//  FlyDrones
//
//  Created by Sergey Galagan on 3/16/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "avformat.h"


@interface FDContextWrapper : NSObject

- (instancetype)initWithSourcePath:(NSString *)path;

- (void)initAVFormatContext:(AVFormatContext *)pCtx;
@end
