//
//  FDTypesAndStructures.h
//  FlyDrones
//
//  Created by Sergey Galagan on 2/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#ifndef FlyDrones_FDTypesAndStructures_h
#define FlyDrones_FDTypesAndStructures_h

typedef struct {
    float Position[3];
    float Color[4];
    float TexCoord[2];
} Vertex;

const Vertex Vertices[] = {
    {{1, -1, 0}, {1, 1, 1, 1}, {1, 1}},
    {{1, 1, 0}, {1, 1, 1, 1}, {1, 0}},
    {{-1, 1, 0}, {1, 1, 1, 1}, {0, 0}},
    {{-1, -1, 0}, {1, 1, 1, 1}, {0, 1}}
};

const GLubyte Indices[] = {
    0, 1, 2,
    2, 3, 0
};

#endif
