//
//  FDMovieGLView.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDMovieGLView.h"
#import "FDMovieGLRenderer.h"
#import "FDDroneStatus.h"
#import "FDGLHelper.h"

typedef NS_ENUM(GLuint, FDMovieGLViewShaderAttribute) {
    FDMovieGLViewShaderAttributeVertex,
    FDMovieGLViewShaderAttributeTexcoord
};

@interface FDMovieGLView () {
    GLuint _framebuffer;
    GLuint _renderbuffer;
    GLint _backingWidth;
    GLint _backingHeight;
    GLuint _program;
    GLint _uniformMatrix;
    GLint _frameWidth;
    GLint _frameHeight;
    GLfloat _vertices[8];
}

@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) FDMovieGLRenderer *renderer;

@end

@implementation FDMovieGLView

#pragma mark - Initialization

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initializeGL];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self initializeGL];
    }
    return self;
}

#pragma mark - Public

- (void)frameSize:(CGSize)frameSize {
    _frameWidth = frameSize.width;
    _frameHeight = frameSize.height;
    [self updateVertices];
}

- (void)renderVideoFrame:(AVFrame)videoFrame {
    if (!videoFrame.data[0] ||
        !videoFrame.data[1] ||
        !videoFrame.data[2]) {
        return;
    }
    
    static const GLfloat texCoords[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    [EAGLContext setCurrentContext:self.context];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(_program);
    
    if (![self.renderer setVideoFrame:videoFrame]) {
        return;
    };

    @try {
        if ([self.renderer prepareRender]) {
            GLfloat modelviewProj[16];
            mat4f_LoadOrtho(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f, modelviewProj);
            glUniformMatrix4fv(_uniformMatrix, 1, GL_FALSE, modelviewProj);
            
            glVertexAttribPointer(FDMovieGLViewShaderAttributeVertex, 2, GL_FLOAT, 0, 0, _vertices);
            glEnableVertexAttribArray(FDMovieGLViewShaderAttributeVertex);
            glVertexAttribPointer(FDMovieGLViewShaderAttributeTexcoord, 2, GL_FLOAT, 0, 0, texCoords);
            glEnableVertexAttribArray(FDMovieGLViewShaderAttributeTexcoord);
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        }
        
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
        [self.context presentRenderbuffer:GL_RENDERBUFFER];
    }
    @catch (NSException *exception) {
        NSLog(@"Exception:%@",exception.description);
    }
}

#pragma mark - Custom Accessors

- (void)setContentMode:(UIViewContentMode)contentMode {
    [super setContentMode:contentMode];

    if (_backingWidth > 0 && _backingHeight > 0) {
        [self updateVertices];
    }
}

#pragma mark - Lifecycle

- (void)layoutSubviews {
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *) self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object %x", status);
    } else {
        NSLog(@"OK setup GL framebuffer %d:%d", _backingWidth, _backingHeight);
    }
    
    [self updateVertices];
}

#pragma mark - Private

- (void)initializeGL {
    self.renderer = [[FDMovieGLRenderer alloc] init];
    
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8,
                                     kEAGLDrawablePropertyRetainedBacking: @NO};
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    self.context.multiThreaded = YES;
    if (!self.context || ![EAGLContext setCurrentContext:self.context]) {
        NSLog(@"failed to setup EAGLContext");
        return;
    }

    glGenFramebuffers(1, &_framebuffer);
    glGenRenderbuffers(1, &_renderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object %x", status);
        return;
    }

    GLenum glError = glGetError();
    if (GL_NO_ERROR != glError) {
        NSLog(@"Failed to setup GL %x", glError);
        return;
    }

    if (![self loadShaders]) {
        return;
    }

    _frameWidth = _backingWidth;
    _frameHeight = _backingHeight;
    // no need to update vertices here... they'll be updated in layoutSubviews

#if 0
    _vertices[0] = -1.0f;  // x0
    _vertices[1] = -1.0f;  // y0
    _vertices[2] = 1.0f;  // ..
    _vertices[3] = -1.0f;
    _vertices[4] = -1.0f;
    _vertices[5] = 1.0f;
    _vertices[6] = 1.0f;  // x3
    _vertices[7] = 1.0f;  // y3
#endif

    NSLog(@"OK setup GL");
}

- (void)dealloc {
    self.renderer = nil;
    
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }

    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }

    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }

    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }

    self.context = nil;
}

- (BOOL)loadShaders {
    BOOL result = NO;
    _program = glCreateProgram();
    GLuint vertexShader = compileShader(GL_VERTEX_SHADER, self.renderer.vertexShaderString);
    GLuint fragmentShader = compileShader(GL_FRAGMENT_SHADER, self.renderer.fragmentShaderString);
    if (vertexShader && fragmentShader) {
        glAttachShader(_program, vertexShader);
        glAttachShader(_program, fragmentShader);
        glBindAttribLocation(_program, FDMovieGLViewShaderAttributeVertex, "position");
        glBindAttribLocation(_program, FDMovieGLViewShaderAttributeTexcoord, "texcoord");

        glLinkProgram(_program);

        GLint status;
        glGetProgramiv(_program, GL_LINK_STATUS, &status);
        if (status == GL_FALSE) {
            NSLog(@"Failed to link program %d", _program);
        } else {
            result = validateProgram(_program);
            _uniformMatrix = glGetUniformLocation(_program, "modelViewProjectionMatrix");
            [self.renderer resolveUniforms:_program];
        }
    }

    if (vertexShader) {
        glDeleteShader(vertexShader);
    }
    
    if (fragmentShader) {
        glDeleteShader(fragmentShader);
    }

    if (result) {
        NSLog(@"OK setup GL programm");
    } else {
        glDeleteProgram(_program);
        _program = 0;
    }

    return result;
}

- (void)updateVertices {

    if (_frameWidth == _backingWidth && _frameHeight == _backingHeight) { // includes init case where everything is == 0
NSLog(@"scale factor w: 1 h: 1");
        _vertices[0] = -1.0f;  // x0
        _vertices[1] = -1.0f;  // y0
        _vertices[2] = 1.0f;  // ..
        _vertices[3] = -1.0f;
        _vertices[4] = -1.0f;
        _vertices[5] = 1.0f;
        _vertices[6] = 1.0f;  // x3
        _vertices[7] = 1.0f;  // y3
        return;
    }

    const BOOL fit = (self.contentMode == UIViewContentModeScaleAspectFit);
    const float width = _frameWidth; // [FDDroneStatus currentStatus].videoSize.width;
    const float height = _frameHeight; // [FDDroneStatus currentStatus].videoSize.height;
    const float dH = (float) _backingHeight / height;
    const float dW = (float) _backingWidth / width;
    const float dd = fit ? MIN(dH, dW) : MAX(dH, dW);
    const float h = (height * dd / (float)_backingHeight);
    const float w = (width * dd / (float)_backingWidth);

NSLog(@"scale factor w: %g h: %g", w, h);

    _vertices[0] = -w;
    _vertices[1] = -h;
    _vertices[2] = w;
    _vertices[3] = -h;
    _vertices[4] = -w;
    _vertices[5] = h;
    _vertices[6] = w;
    _vertices[7] = h;
}

@end
