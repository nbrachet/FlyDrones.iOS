//
//  ANStopwatch.m
//  VideoChat
//
//  Created by Alexey Naboychenko on 3/10/14.
//  Copyright (c) 2014 Alexey Naboychenko. All rights reserved.
//

#import "ANStopwatch.h"

#pragma mark - ANStopwatch

@interface ANStopwatch()

@property (nonatomic, strong) NSMutableDictionary *items;

@end

@implementation ANStopwatch

#pragma mark - Lifecycle

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super alloc] initInstance];
    });
    return sharedInstance;
}

- (instancetype)initInstance {
    return [super init];
}

#pragma mark - Public

+ (void)start:(NSString *)name {
	[[self sharedInstance] addItemWithName:name];
}

+ (void)stop:(NSString *)name {
	ANStopwatchItem *item = [[self sharedInstance] getItemFromName:name];
	[item stop];
	[[self sharedInstance] printInfoFromItem:item];
}

+ (void)print:(NSString *)name {
	ANStopwatchItem *item = [[self sharedInstance] getItemFromName:name];
    if (item == nil) {
        NSLog(@"No stopwatch named [%@] found", name);
        return;
    }
    [[self sharedInstance] printInfoFromItem:item];
}

#pragma mark - Custom Accessors

- (NSMutableDictionary *)items {
    if (_items == nil) {
        _items = [NSMutableDictionary dictionary];
    }
    return _items;
}

#pragma mark - Private

- (void)addItemWithName:(NSString *)name {
	if (name == nil) {
		return;
	}
	
	[self removeItem:name];
	[self.items setObject:[ANStopwatchItem itemWithName:name] forKey:name];
}

- (void)removeItem:(NSString *)name {
	if (name == nil) {
		return;
	}
    
	[self.items removeObjectForKey:name];
}

- (instancetype)getItemFromName:(NSString *)name {
	if (name == nil) {
		return nil;
	}
	return self.items[name];
}

- (void)printInfoFromItem:(ANStopwatchItem *)item {
	if (item == nil) {
		return;
	}
	NSLog(@"%@", item);
}

@end

#pragma mark - ANStopwatchItem

@interface ANStopwatchItem ()

@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSDate *startedDate;
@property (nonatomic, strong) NSDate *stopDate;

@end

@implementation ANStopwatchItem

#pragma mark - Lifecycle

+ (instancetype)itemWithName:(NSString *)name {
    return [[self alloc] initWithName:name];
}

- (id)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        self.name = name;
        self.startedDate = [NSDate date];
    }
    return self;
}

#pragma mark - Public

- (void)stop {
    self.stopDate = [NSDate date];
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"Stopwatch:[%@] runtime:[%@]", self.name, [self runtimePretty]];
    if (self.stopDate == nil) {
        [description appendString:@" (running)"];
    }
	return description;
}

#pragma mark - Private

- (NSTimeInterval)runtime {
	if (self.startedDate == nil) {
		return 0.0f;
	}
	
	if (self.stopDate == nil) {
		return [self.startedDate timeIntervalSinceNow] * -1.0f;
	}
	
	return [self.startedDate timeIntervalSinceDate:self.stopDate] * -1.0f;
}

- (NSString *)runtimePretty {
	NSTimeInterval secsRem = [self runtime];
    
	int hours = (int)(secsRem / 3600);
	secsRem	= secsRem - (hours * 3600);
	int mins = (int)(secsRem / 60);
	secsRem	= secsRem - (mins * 60);
    
	if (hours > 0) {
		return [NSString stringWithFormat:@"%d:%d:%f", hours, mins, secsRem];
	}
	if (mins > 0) {
		return [NSString stringWithFormat:@"%d:%f", mins, secsRem];
	}
	return [NSString stringWithFormat:@"%f", secsRem];
}

@end