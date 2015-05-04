//
//  FDFileReader.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/30/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDFileReader : NSObject

//@property (nonatomic, )

- (id)initWithFilePath:(NSString *)path;
- (NSData *)readBytes:(NSUInteger)count;
//- (NSString *)readLine;
//- (NSString *)readTrimmedLine;
//
#if NS_BLOCKS_AVAILABLE
- (void)asyncEnumerateBytesUsingBlock:(void(^)(NSData *data, BOOL *stop))block;
#endif

@end
