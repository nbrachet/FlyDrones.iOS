//
//  FDVideoFrame.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/22/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"

@interface FDVideoFrame : NSObject

@property(nonatomic, copy) NSData *luma;
@property(nonatomic, copy) NSData *chromaB;
@property(nonatomic, copy) NSData *chromaR;
@property(nonatomic) NSUInteger width;
@property(nonatomic) NSUInteger height;

- (instancetype)initWithFrame:(AVFrame *)frame width:(NSUInteger)width height:(NSUInteger)height;

@end
