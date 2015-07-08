//
//  FDFileReader.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/30/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

@interface FDFileReader : NSObject

- (id)initWithFilePath:(NSString *)path;
- (NSData *)readBytes:(NSUInteger)count;

#if NS_BLOCKS_AVAILABLE
- (void)asyncEnumerateBytesUsingBlock:(void(^)(NSData *data, BOOL *stop))block;
#endif

@end
