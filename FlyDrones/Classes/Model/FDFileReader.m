//
//  FDFileReader.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/30/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDFileReader.h"

@interface FDFileReader ()

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic) unsigned long long currentOffset;
@property (nonatomic) unsigned long long totalFileLength;

@end

@implementation FDFileReader

- (id)initWithFilePath:(NSString *)path {
    if (self = [super init]) {
        self.fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
        if (self.fileHandle == nil) {
            self = nil;
            return nil;
        }
        
        self.filePath = path;
        self.currentOffset = 0ULL;
        [self.fileHandle seekToEndOfFile];
        self.totalFileLength = [self.fileHandle offsetInFile];
        //we don't need to seek back, since readLine will do that.
    }
    return self;
}

- (void)dealloc {
    [self.fileHandle closeFile];
    self.fileHandle = nil;
    self.filePath = nil;
    self.currentOffset = 0ULL;
}

- (NSData *)readBytes:(NSUInteger)count  {
    if (self.currentOffset + count >= self.totalFileLength) {
        return nil;
    }
    
    [self.fileHandle seekToFileOffset:self.currentOffset];
    NSData *data = [self.fileHandle readDataOfLength:count];
    self.currentOffset += data.length;
    return data;
}

#if NS_BLOCKS_AVAILABLE

- (void)enumerateBytesUsingBlock:(void(^)(NSData *, BOOL *))block {
    NSData *data = nil;
    BOOL stop = NO;
    while (stop == NO /* && (data = [self readBytes:1])*/) {
        @autoreleasepool {
            data = [self readBytes:1];
            if (data.length == 0) {
                break;
            }
            block(data, &stop);
        }
    }
}

#endif

@end
