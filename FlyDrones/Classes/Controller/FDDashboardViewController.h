//
//  FDDashboardViewController.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MovieDecoder;

extern NSString * const FDMovieParameterMinBufferedDuration;    // Float
extern NSString * const FDMovieParameterMaxBufferedDuration;    // Float
extern NSString * const FDMovieParameterDisableDeinterlacing;   // BOOL

@interface FDDashboardViewController : UIViewController

@property (nonatomic, copy) NSString *path;
@property (readonly, getter=isPlaying) BOOL playing;

@end
