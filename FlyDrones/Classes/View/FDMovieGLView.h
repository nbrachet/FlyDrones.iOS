//
//  FDMovieGLView.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FDVideoFrame;
@class FDMovieDecoder;

@interface FDMovieGLView : UIView

- (id) initWithFrame:(CGRect)frame
             decoder: (FDMovieDecoder *) decoder;

- (void) render: (FDVideoFrame *) frame;

@end