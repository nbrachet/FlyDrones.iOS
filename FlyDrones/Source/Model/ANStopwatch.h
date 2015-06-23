//
//  ANStopwatch.h
//  VideoChat
//
//  Created by Alexey Naboychenko on 3/10/14.
//  Copyright (c) 2014 Alexey Naboychenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ANStopwatch : NSObject

+ (instancetype)alloc __attribute__((unavailable("alloc not available, call sharedInstance instead")));
+ (instancetype)allocWithZone __attribute__((unavailable("allocWithZone not available, call sharedInstance instead")));
- (instancetype)init __attribute__((unavailable("init not available, call sharedInstance instead")));
- (instancetype)copy __attribute__((unavailable("copy not available, call sharedInstance instead")));
+ (instancetype)copyWithZone __attribute__((unavailable("copyWithZone not available, call sharedInstance instead")));
- (instancetype)mutableCopy __attribute__((unavailable("mutableCopy not available, call sharedInstance instead")));
+ (instancetype)new __attribute__((unavailable("new not available, call sharedInstance instead")));

+ (instancetype)sharedInstance;
+ (void)start:(NSString *)name;
+ (void)stop:(NSString *)name;
+ (void)print:(NSString *)name;

@end

@interface ANStopwatchItem : NSObject

+ (instancetype)itemWithName:(NSString *)name;
- (void)stop;

@end
