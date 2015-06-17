//
//  FDMovieGLRenderer.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 6/17/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>

@class FDVideoFrame;

@interface FDMovieGLRenderer : NSObject

@property (nonatomic, copy, readonly) NSString *fragmentShaderString;
@property (nonatomic, copy, readonly) NSString *vertexShaderString;

- (void)setVideoFrame:(FDVideoFrame *)videoFrame;
- (BOOL)isValid;
- (void)resolveUniforms:(GLuint)program;
- (BOOL)prepareRender;

@end
