//
//  NSFileManager+ANUtils.m
//  ANUtils
//
//  Created by Alexey Naboychenko on 6/3/13.
//  Copyright (c) 2013 Alexey Naboychenko. All rights reserved.
//

#import "NSFileManager+ANUtils.h"

@implementation NSFileManager (ANUtils)

+ (NSString *)applicationDocumentsDirectoryPath {
    return [[self defaultManager] applicationDocumentsDirectoryPath];
}

- (NSString *)applicationDocumentsDirectoryPath {
    @synchronized ([NSFileManager class]) {
        static NSString *path = nil;

        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            //user documents folder
            path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
            
            //retain path
            if (path != nil) {
                path = [NSString stringWithString:path];
            }
        });
        
        return path;
    }
}

+ (NSString *)applicationCacheDirectoryPath {
    return [[self defaultManager] applicationCacheDirectoryPath];
}

- (NSString *)applicationCacheDirectoryPath {
    @synchronized ([NSFileManager class]) {
        static NSString *path = nil;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            //cache folder
            path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
            
#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
            //append application bundle ID on Mac OS
            NSString *bundleIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleIdentifierKey];
            path = [path stringByAppendingPathComponent:bundleIdentifier];
#endif
            
            //create the folder if it doesn't exist
            if (![self fileExistsAtPath:path]) {
                [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            
            //retain path
            if (path != nil) {
                path = [NSString stringWithString:path];
            }
        });
        
        return path;
    }
}

+ (NSString *)applicationTemporaryDirectoryPath {
    return [[self defaultManager] applicationTemporaryDirectoryPath];
}

- (NSString *)applicationTemporaryDirectoryPath {
    static NSString *path = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //temporary directory (shouldn't change during app lifetime)
        path = NSTemporaryDirectory();

        //apparently NSTemporaryDirectory() can return nil in some cases
        if (path == nil && self.applicationCacheDirectoryPath != nil) {
            path = [self.applicationCacheDirectoryPath stringByAppendingPathComponent:@"Temporary Files"];
        }

        //retain path
        if (path != nil) {
            path = [NSString stringWithString:path];
        }
    });
    return path;
}

+ (NSURL *)searchFile:(NSString *)fileName inRootDirectoryPath:(NSString *)directoryPath {
    return [[self defaultManager] searchFile:fileName inRootDirectoryPath:directoryPath];
}

+ (NSURL *)searchFile:(NSString *)fileName inRootDirectoryURL:(NSURL *)directoryURL {
    return [[self defaultManager] searchFile:fileName inRootDirectoryURL:directoryURL];
}

#pragma mark - Private

- (NSURL *)searchFile:(NSString *)fileName inRootDirectoryPath:(NSString *)directoryPath {
    if (directoryPath == nil) {
        return nil;
    }
    NSURL *directoryURL = [NSURL fileURLWithPath:directoryPath];
    return [self searchFile:fileName inRootDirectoryURL:directoryURL];
}

- (NSURL *)searchFile:(NSString *)fileName inRootDirectoryURL:(NSURL *)directoryURL {
    if ([fileName length] == 0 || directoryURL == nil ) {
        return nil;
    }
    
    NSArray *enumeratorPropertiesKeys = @[NSURLIsDirectoryKey];
    NSDirectoryEnumerator *enumerator = [self enumeratorAtURL:directoryURL
                                   includingPropertiesForKeys:enumeratorPropertiesKeys
                                                      options:0
                                                 errorHandler:^(NSURL *url, NSError *error) {
                                                        return YES;
                                                 }];
    for (NSURL *metaDataURL in enumerator) {
        NSString *metaDataName = [[metaDataURL absoluteString] lastPathComponent];
        if ([metaDataName isEqualToString:fileName]) {
            return metaDataURL;
        }
    }
    return nil;
}

@end
