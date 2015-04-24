//
//  NSString+PathComponents.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/24/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (PathComponents)

- (NSUInteger)pathPort;
- (NSString *)pathHost;

@end
