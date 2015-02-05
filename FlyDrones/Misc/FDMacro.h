//
//  FDMacro.h
//  FlyDrones
//
//  Created by Sergey Galagan on 2/5/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#ifndef FlyDrones_FDMacro_h
#define FlyDrones_FDMacro_h

#pragma mark - Shaders section

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 Position; // 1
 attribute vec4 SourceColor; // 2
 
 varying vec4 DestinationColor; // 3
 
 attribute vec2 TexCoordIn;
 varying vec2 TexCoordOut;
 
 void main(void) { // 4
     DestinationColor = SourceColor; // 5
     gl_Position = Position; // 6
     TexCoordOut = TexCoordIn; // New
 }
 );

NSString *const rgbFragmentShaderString = SHADER_STRING
(
 varying highp vec2 TexCoordOut;
 uniform sampler2D s_texture_y;
 uniform sampler2D s_texture_u;
 uniform sampler2D s_texture_v;
 
 void main()
 {
     highp float y = texture2D(s_texture_y, TexCoordOut).r;
     highp float u = texture2D(s_texture_u, TexCoordOut).r - 0.5;
     highp float v = texture2D(s_texture_v, TexCoordOut).r - 0.5;
     
     highp float r = y +             1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     
     gl_FragColor = vec4(r,g,b,1.0);
 }
 );

#endif
