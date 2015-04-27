//
//  NSString+PathComponents.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/24/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "NSString+PathComponents.h"

@implementation NSString (PathComponents)

- (NSUInteger)pathPort {
    if (self.length == 0) {
        return 0;
    }
    NSArray *components = [self componentsSeparatedByString:@"://"];
    BOOL isSchemeExist = components.count > 1;
    NSURL *url;
    if (!isSchemeExist) {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"scheme://%@", self]];
    } else {
        url = [NSURL URLWithString:self];
    }

    NSNumber *portNumber = url.port;
    return [portNumber integerValue];
}

- (NSString *)pathHost {
    if (self.length == 0) {
        return 0;
    }
    NSArray *components = [self componentsSeparatedByString:@"://"];
    BOOL isHostExist = components.count > 1;
    NSURL *url;
    if (!isHostExist) {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"scheme://%@", self]];
    } else {
        url = [NSURL URLWithString:self];
    }

    return url.host;
}

@end
