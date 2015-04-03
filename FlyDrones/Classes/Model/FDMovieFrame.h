//
//  FDMovieFrame.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, FDVideoFrameFormat) {
    FDVideoFrameFormatRGB = 0,
    FDVideoFrameFormatYUV,
};


@interface FDMovieFrame : NSObject

@property (nonatomic) CGFloat position;
@property (nonatomic) CGFloat duration;

@end


@interface FDVideoFrame : FDMovieFrame

//@property (nonatomic) FDVideoFrameFormat format;
@property (nonatomic) NSUInteger width;
@property (nonatomic) NSUInteger height;

@end


@interface FDVideoFrameRGB : FDVideoFrame

@property (nonatomic) NSUInteger linesize;
@property (nonatomic, strong) NSData *rgb;
- (UIImage *)asImage;

@end


@interface FDVideoFrameYUV : FDVideoFrame

@property (nonatomic, strong) NSData *luma;
@property (nonatomic, strong) NSData *chromaB;
@property (nonatomic, strong) NSData *chromaR;

@end


@interface FDArtworkFrame : FDMovieFrame

@property (nonatomic, strong) NSData *picture;
- (UIImage *)asImage;

@end


@interface FDSubtitleFrame : FDMovieFrame

@property (nonatomic, strong) NSString *text;

@end
