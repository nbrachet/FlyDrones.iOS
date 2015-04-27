//
//  NSFileManager+ANUtils.h
//  ANUtils
//
//  Created by Oleksii Naboichenko on 6/3/13.
//  Copyright (c) 2013 Oleksii Naboichenko. All rights reserved.
//

@interface NSFileManager (ANUtils)

+ (NSString *)applicationDocumentsDirectoryPath;
- (NSString *)applicationDocumentsDirectoryPath;

+ (NSString *)applicationCacheDirectoryPath;
- (NSString *)applicationCacheDirectoryPath;

+ (NSString *)applicationTemporaryDirectoryPath;
- (NSString *)applicationTemporaryDirectoryPath;

+ (NSURL *)searchFile:(NSString *)fileName inRootDirectoryPath:(NSString *)directoryPath;
+ (NSURL *)searchFile:(NSString *)fileName inRootDirectoryURL:(NSURL *)directoryURL;

@end