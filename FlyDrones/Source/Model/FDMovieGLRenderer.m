//
//  FDMovieGLRenderer.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 6/17/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import "FDMovieGLRenderer.h"
#import "FDVideoFrame.h"

@interface FDMovieGLRenderer () {
    GLint _uniformSamplers[3];
    GLuint _textures[3];
}

@property (nonatomic, copy) NSString *fragmentShaderString;
@property (nonatomic, copy) NSString *vertexShaderString;

@end

@implementation FDMovieGLRenderer

- (BOOL)isValid {
    return (_textures[0] != 0);
}

- (NSString *)fragmentShaderString {
    if (_fragmentShaderString.length == 0) {
        NSString *fragmentShaderFilePath = [[NSBundle mainBundle] pathForResource:@"YUVFragmentShader" ofType:@"glsl"];
        _fragmentShaderString = [NSString stringWithContentsOfFile:fragmentShaderFilePath
                                                          encoding:NSUTF8StringEncoding
                                                             error:nil];
    }
    return _fragmentShaderString;
}

- (NSString *)vertexShaderString {
    if (_vertexShaderString.length == 0) {
        NSString *vertexShaderFilePath = [[NSBundle mainBundle] pathForResource:@"VertexShader" ofType:@"glsl"];
        _vertexShaderString = [NSString stringWithContentsOfFile:vertexShaderFilePath
                                                        encoding:NSUTF8StringEncoding
                                                           error:nil];
    }
    return _vertexShaderString;
}

- (void)resolveUniforms:(GLuint)program {
    _uniformSamplers[0] = glGetUniformLocation(program, "s_texture_y");
    _uniformSamplers[1] = glGetUniformLocation(program, "s_texture_u");
    _uniformSamplers[2] = glGetUniformLocation(program, "s_texture_v");
}

- (void)setVideoFrame:(FDVideoFrame *)videoFrame {    
    assert(videoFrame.luma.length == videoFrame.width * videoFrame.height);
    assert(videoFrame.chromaB.length == (videoFrame.width * videoFrame.height) / 4);
    assert(videoFrame.chromaR.length == (videoFrame.width * videoFrame.height) / 4);
    
    NSUInteger frameWidth = videoFrame.width;
    NSUInteger frameHeight = videoFrame.height;
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (_textures[0] == 0) {
        glGenTextures(3, _textures);
    }
    
    const UInt8 *pixels[3] = {videoFrame.luma.bytes, videoFrame.chromaB.bytes, videoFrame.chromaR.bytes};
    const NSInteger widths[3] = {frameWidth, frameWidth / 2, frameWidth / 2};
    const NSInteger heights[3] = {frameHeight, frameHeight / 2, frameHeight / 2};
    
    for (int i = 0; i < 3; ++i) {
        glBindTexture(GL_TEXTURE_2D, _textures[i]);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, (GLsizei)widths[i], (GLsizei)heights[i], 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, pixels[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}

- (BOOL)prepareRender {
    if (_textures[0] == 0) {
        return NO;
    }
    
    for (int i = 0; i < 3; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, _textures[i]);
        glUniform1i(_uniformSamplers[i], i);
    }
    
    return YES;
}

- (void)dealloc {
    if (_textures[0]) {
        glDeleteTextures(3, _textures);
    }
}

@end
