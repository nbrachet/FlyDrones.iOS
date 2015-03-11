//
//  FDVideoStreamingController.m
//  FlyDrones
//
//  Created by Sergey Galagan on 2/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDVideoStreamingController.h"
#import "FDFFmpegFrameEntity.h"

#import "FDTypesAndStructures.h"

#import "UIView+Utils.h"
#import "FDMacro.h"


#pragma mark - Static

static CGFloat const kFDScreenWidth = 1280.0f;
static CGFloat const kFDScreenHeight = 720.0f;


#pragma mark - Private itnerface methods

@interface FDVideoStreamingController ()
{
    float _curRed;
    BOOL _increasing;
    
    GLuint _vertexBuffer;
    GLuint _indexBuffer;
    
    GLuint _positionSlot;
    GLuint _colorSlot;
    
    uint16_t _textureWidth;
    uint16_t _textureHeight;
    GLuint _yTexture;
    GLuint _uTexture;
    GLuint _vTexture;
    GLuint _texCoordSlot;
    GLuint _yTextureUniform;
    GLuint _uTextureUniform;
    GLuint _vTextureUniform;
    
    dispatch_semaphore_t _textureUpdateRenderSemaphore;
}


#pragma mark - Properties

@property (nonatomic, strong) EAGLContext *context;

@end


#pragma mark - Public interface methods

@implementation FDVideoStreamingController

#pragma mark - Instance methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self intefaceInitialization];
    [self performData];
}

- (int)loadVideoEntity:(FDFFmpegFrameEntity *)videoEntity
{
    int statusCode = 0;
    
    if (videoEntity && self.context)
    {
        [EAGLContext setCurrentContext:self.context];
        if (_yTexture && _uTexture && _vTexture)
        {
            [self updateTexture:videoEntity.colorPlane0 width:videoEntity.width.intValue height:videoEntity.height.intValue textureIndex:0];
            [self updateTexture:videoEntity.colorPlane1 width:videoEntity.width.intValue/2 height:videoEntity.height.intValue/2 textureIndex:1];
            [self updateTexture:videoEntity.colorPlane2 width:videoEntity.width.intValue/2 height:videoEntity.height.intValue/2 textureIndex:2];
           
            _textureWidth = videoEntity.width.intValue;
            _textureHeight = videoEntity.height.intValue;
        }
    }
    else
    {
        statusCode = -1;
    }
    
    
    return statusCode;
}


#pragma mark - Interface initialization methods

- (void)intefaceInitialization
{
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context)
        NSLog(@"Failed to create ES context");
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    
    [self setupGL];
    [self compileShaders];
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
    _textureUpdateRenderSemaphore = dispatch_semaphore_create((long)1);
}

- (void)resizeToFrame:(CGRect )frame
{
    [self.view updateSize:frame.size];
}


#pragma mark - Misc methods

- (void)performData
{
    _textureWidth = kFDScreenWidth;
    _textureHeight = kFDScreenHeight;
    _yTexture = [self setupTexture:nil width:_textureWidth height:_textureHeight textureIndex:0];
    _uTexture = [self setupTexture:nil width:_textureWidth/2 height:_textureHeight/2 textureIndex:1];
    _vTexture = [self setupTexture:nil width:_textureWidth/2 height:_textureHeight/2 textureIndex:2];
}


#pragma mark - Texture setup

- (void)updateTexture:(NSData *)textureData width:(uint)width height:(uint)height textureIndex:(GLuint)index
{
    long renderStatus = dispatch_semaphore_wait(_textureUpdateRenderSemaphore, DISPATCH_TIME_NOW);
    if (renderStatus==0)
    {
        GLubyte *glTextureData;
        if (textureData)
        {
            glTextureData = (GLubyte*)(textureData.bytes);
        }
        else
        {
            glTextureData = (GLubyte *) malloc(width*height);
            memset(glTextureData, 0, width*height);
        }
        
        glActiveTexture(GL_TEXTURE0+index);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width, height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, glTextureData);
        
        if (!textureData)
        {
            free(glTextureData);
        }
        dispatch_semaphore_signal(_textureUpdateRenderSemaphore);
    }
}

- (GLuint)setupTexture:(NSData *)textureData width:(uint)width height:(uint)height textureIndex:(GLuint)index
{
    GLuint texName;
    
    glGenTextures(1, &texName);
    glActiveTexture(GL_TEXTURE0+index);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    [self updateTexture:textureData width:width height:height textureIndex:index];
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    
    return texName;
}


#pragma mark - compile and load shaders

- (GLuint)compileShader:(NSString *)shaderString withType:(GLenum)shaderType
{
    GLuint shaderHandle = glCreateShader(shaderType);
    
    if (shaderHandle == 0 || shaderHandle == GL_INVALID_ENUM)
    {
        NSLog(@"Failed to create shader %d", shaderType);
        exit(1);
    }

    const char * shaderStringUTF8 = shaderString.UTF8String;
    int shaderStringLength = (int)shaderString.length;
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    glCompileShader(shaderHandle);
    
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    
    if (compileSuccess == GL_FALSE)
    {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    
    return shaderHandle;
}

- (void)compileShaders
{
    GLuint vertexShader = [self compileShader:vertexShaderString withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:rgbFragmentShaderString withType:GL_FRAGMENT_SHADER];
    
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);
    
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE)
    {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glUseProgram(programHandle);
    
    _positionSlot = glGetAttribLocation(programHandle, "Position");
    _colorSlot = glGetAttribLocation(programHandle, "SourceColor");
    glEnableVertexAttribArray(_positionSlot);
    glEnableVertexAttribArray(_colorSlot);
    
    // set the shader slots
    _texCoordSlot = glGetAttribLocation(programHandle, "TexCoordIn");
    glEnableVertexAttribArray(_texCoordSlot);
    _yTextureUniform = glGetUniformLocation(programHandle, "s_texture_y");
    _uTextureUniform = glGetUniformLocation(programHandle, "s_texture_u");
    _vTextureUniform = glGetUniformLocation(programHandle, "s_texture_v");
    _yTexture = 0;
    _uTexture = 0;
    _vTexture = 0;
}


#pragma mark - Render code

- (void)setGLViewportToScale
{
    CGFloat scaleFactor = [UIScreen mainScreen].scale;
    
    if (_textureHeight != 0 && _textureWidth != 0)
    {
        float targetRatio = _textureWidth/(_textureHeight*1.0);
        float viewRatio = self.view.bounds.size.width/(self.view.bounds.size.height*1.0);
        uint16_t x, y, width, height;
       
        if (targetRatio > viewRatio)
        {
            width = self.view.bounds.size.width * scaleFactor;
            height = width/targetRatio;
            x = 0;
            y = (self.view.bounds.size.height * scaleFactor - height)/2;
            
        }
        else
        {
            height = self.view.bounds.size.height*scaleFactor;
            width = height * targetRatio;
            y = 0;
            x = (self.view.bounds.size.width*scaleFactor - width)/2;
        }
        glViewport(x,y,width,height);
    }
    else
    {
        glViewport(self.view.bounds.origin.x, self.view.bounds.origin.y,
                   self.view.bounds.size.width * scaleFactor, self.view.bounds.size.height * scaleFactor);
    }
}

- (void)render
{
    [EAGLContext setCurrentContext:self.context];
    
    [self setGLViewportToScale];
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*) (sizeof(float) * 3));
    glVertexAttribPointer(_texCoordSlot, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*) (sizeof(float) * 7));
    
    glUniform1i(_yTextureUniform, 0);
    glUniform1i(_uTextureUniform, 1);
    glUniform1i(_vTextureUniform, 2);
    
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}


#pragma mark - GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    long textureUpdateStatus = dispatch_semaphore_wait(_textureUpdateRenderSemaphore, DISPATCH_TIME_NOW);
    
    if (textureUpdateStatus == 0)
    {
        glClearColor(0.0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        [self render];
        dispatch_semaphore_signal(_textureUpdateRenderSemaphore);
    }
}


#pragma mark - GLKViewControllerDelegate

- (void)update
{
    if (_increasing)
    {
        _curRed += 1.0 * self.timeSinceLastUpdate;
    }
    else
    {
        _curRed -= 1.0 * self.timeSinceLastUpdate;
    }
    
    if (_curRed >= 1.0)
    {
        _curRed = 1.0;
        _increasing = NO;
    }
    
    if (_curRed <= 0.0)
    {
        _curRed = 0.0;
        _increasing = YES;
    }
}


#pragma mark - Memory management methods

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    
    glDeleteTextures(1, &_yTexture);
    glDeleteTextures(1, &_uTexture);
    glDeleteTextures(1, &_vTexture);
}

- (void)viewDidUnload
{
    if ([EAGLContext currentContext] == self.context)
    {
        [EAGLContext setCurrentContext:nil];
    }
    
    self.context = nil;
    [self tearDownGL];
    
    [super viewDidUnload];
}

#pragma mark -

@end
