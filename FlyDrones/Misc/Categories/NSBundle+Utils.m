//
//  NSBundle+Utils.m
//  FlyDrones
//
//  Created by Sergey Galagan on 2/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "NSBundle+Utils.h"

@implementation NSBundle (Utils)

- (NSString *)pathOfVideoFile
{
    return [self pathForResource:@"test" ofType:@"h264"];
}

@end
