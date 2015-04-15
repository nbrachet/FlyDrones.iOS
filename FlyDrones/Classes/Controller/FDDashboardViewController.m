//
//  FDDashboardViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDDashboardViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "FDMovieDecoder.h"
#import "FDMovieGLView.h"
#import "FDDisplayInfoView.h"

NSString * const FDMovieParameterMinBufferedDuration = @"FDMovieParameterMinBufferedDuration";
NSString * const FDMovieParameterMaxBufferedDuration = @"FDMovieParameterMaxBufferedDuration";
NSString * const FDMovieParameterDisableDeinterlacing = @"FDMovieParameterDisableDeinterlacing";

#define NETWORK_MIN_BUFFERED_DURATION 2.0
#define NETWORK_MAX_BUFFERED_DURATION 4.0

@interface FDDashboardViewController () <UIGestureRecognizerDelegate> {
    
    FDMovieDecoder      *_decoder;
    dispatch_queue_t    _dispatchQueue;
    NSMutableArray      *_videoFrames;
//    NSMutableArray      *_subtitles;
    CGFloat             _moviePosition;
//    BOOL                _disableUpdateHUD;
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    NSUInteger          _tickCounter;
    BOOL                _restoreIdleTimer;
//    BOOL                _interrupted;
    
    FDMovieGLView       *_glView;
    UIImageView         *_imageView;

//    UIToolbar           *_bottomBar;
//    
//    UIBarButtonItem     *_playBtn;
//    UIBarButtonItem     *_pauseBtn;
    

    
    CGFloat             _bufferedDuration;
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
    BOOL                _buffered;
    
    BOOL                _savedIdleTimer;
    
    NSDictionary        *_parameters;
}

@property (nonatomic, weak) IBOutlet FDDisplayInfoView *displayInfoView;

@property (nonatomic, readwrite, getter=isPlaying) BOOL playing;
@property (readwrite) BOOL decoding;

@end

@implementation FDDashboardViewController

#pragma mark - Lifecycle

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _moviePosition = 0;

    __weak __typeof(self) weakSelf = self;
    FDMovieDecoder *decoder = [[FDMovieDecoder alloc] init];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [decoder openFile:self.path];
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [strongSelf setMovieDecoder:decoder];
                [strongSelf play];
            });
        }
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.displayInfoView showDisplayInfo];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    _savedIdleTimer = [[UIApplication sharedApplication] isIdleTimerDisabled];
    
    if (_decoder) {
        [self play];
    }
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewWillDisappear:animated];
    
    
    if (_decoder) {
        [self pause];
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:_savedIdleTimer];
    
    _buffered = NO;
    
    NSLog(@"viewWillDisappear %@", self);
}


- (void)dealloc {
    [self pause];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_dispatchQueue) {
        _dispatchQueue = NULL;
    }
    
    NSLog(@"%@ dealloc", self);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    if (self.playing) {
        [self pause];
        [self freeBufferedFrames];
        
        if (_maxBufferedDuration > 0) {
            
            _minBufferedDuration = _maxBufferedDuration = 0;
            [self play];
            
            NSLog(@"didReceiveMemoryWarning, disable buffering and continue playing");
        } else {
            // force ffmpeg to free allocated memory
            [_decoder closeFile];
            [_decoder openFile:nil];
            
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                        message:NSLocalizedString(@"Out of memory", nil)
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                              otherButtonTitles:nil] show];
        }
    } else {
        [self freeBufferedFrames];
        [_decoder closeFile];
        [_decoder openFile:nil];
    }
}

- (void)applicationWillResignActive: (NSNotification *)notification {
    [self pause];
    
    NSLog(@"applicationWillResignActive");
}

#pragma mark - Public

- (void)play {
    if (self.playing) {
        return;
    }
    
    if (!_decoder.validVideo) {
        return;
    }

    self.playing = YES;
    _tickCorrectionTime = 0;
    _tickCounter = 0;
    
    [self asyncDecodeFrames];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });
    
    NSLog(@"Play movie");
}

- (void) pause {
    if (!self.playing) {
        return;
    }
    
    self.playing = NO;
    NSLog(@"Pause movie");
}

#pragma mark - IBActions

- (IBAction)back:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)playDidTouch:(id)sender {
    if (self.playing) {
        [self pause];
    } else {
        [self play];
    }
}

#pragma mark - Private

- (void)setMovieDecoder:(FDMovieDecoder *)decoder {
    NSLog(@"setMovieDecoder");
    
    if (decoder) {
        _decoder = decoder;
        _dispatchQueue = dispatch_queue_create("FDMovie", DISPATCH_QUEUE_SERIAL);
        _videoFrames = [NSMutableArray array];
    
            _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
        
        if (!_decoder.validVideo) {
            _minBufferedDuration *= 10.0; // increase for audio
        }
        
        // allow to tweak some parameters at runtime
        if (_parameters.count) {
            
            id val;
            
            val = [_parameters valueForKey: FDMovieParameterMinBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]]) {
                _minBufferedDuration = [val floatValue];
            }
            
            val = [_parameters valueForKey: FDMovieParameterMaxBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]]) {
                _maxBufferedDuration = [val floatValue];
            }
            
            val = [_parameters valueForKey: FDMovieParameterDisableDeinterlacing];
            if ([val isKindOfClass:[NSNumber class]]) {
                _decoder.disableDeinterlacing = [val boolValue];
            }
            
            if (_maxBufferedDuration < _minBufferedDuration) {
                _maxBufferedDuration = _minBufferedDuration * 2;
            }
        }
        
        NSLog(@"buffered limit: %.1f - %.1f", _minBufferedDuration, _maxBufferedDuration);
        
        if (self.isViewLoaded) {
            [self setupPresentView];
        }
    }
}

- (void)setupPresentView {
    CGRect bounds = self.view.bounds;
    
    if (_decoder.validVideo) {
        _glView = [[FDMovieGLView alloc] initWithFrame:bounds decoder:_decoder];
    }
    
    if (!_glView) {
        NSLog(@"fallback to use RGB video frame and UIKit");
        [_decoder setupVideoFrameFormat:FDVideoFrameFormatRGB];
        _imageView = [[UIImageView alloc] initWithFrame:bounds];
        _imageView.backgroundColor = [UIColor blackColor];
    }
    
    UIView *frameView = [self frameView];
    frameView.contentMode = UIViewContentModeScaleAspectFit;
    frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view insertSubview:frameView atIndex:0];

    self.view.backgroundColor = [UIColor clearColor];
}

- (UIView *)frameView {
    return _glView ? _glView : _imageView;
}

- (BOOL)addFrames:(NSArray *)frames {
    if (_decoder.validVideo) {
        @synchronized(_videoFrames) {
            for (FDMovieFrame *frame in frames) {
                if ([frame isKindOfClass:[FDVideoFrameRGB class]] || [frame isKindOfClass:[FDVideoFrameYUV class]]) {
                    [_videoFrames addObject:frame];
                    _bufferedDuration += frame.duration;
                }
            }
        }
    }
    
    return self.playing && _bufferedDuration < _maxBufferedDuration;
}

- (BOOL)decodeFrames {
    NSArray *frames = nil;
    
    if (_decoder.validVideo) {
        
        frames = [_decoder decodeFrames:0];
    }
    
    if (frames.count) {
        return [self addFrames: frames];
    }
    return NO;
}

- (void)asyncDecodeFrames {
    if (self.decoding)
        return;
    
    __weak __typeof(self) weakSelf = self;
    __weak FDMovieDecoder *weakDecoder = _decoder;
    
//    const CGFloat duration = _decoder.isNetwork ? .0f : 0.1f;
    CGFloat duration = 0;
    
    self.decoding = YES;
    dispatch_async(_dispatchQueue, ^{
        
        {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf.playing)
                return;
        }
        
        BOOL good = YES;
        while (good) {
            
            good = NO;
            
            @autoreleasepool {
                
                __strong FDMovieDecoder *decoder = weakDecoder;
                
                if (decoder && decoder.validVideo) {
                    
                    NSArray *frames = [decoder decodeFrames:duration];
                    if (frames.count) {
                        
                        __strong __typeof(weakSelf) strongSelf = weakSelf;
                        if (strongSelf)
                            good = [strongSelf addFrames:frames];
                    }
                }
            }
        }
        
        {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) strongSelf.decoding = NO;
        }
    });
}

- (void)tick {
    if (_buffered && ((_bufferedDuration > _minBufferedDuration) || _decoder.isEOF)) {
        _tickCorrectionTime = 0;
        _buffered = NO;
    }
    
    CGFloat interval = 0;
    if (!_buffered)
        interval = [self presentFrame];
    
    if (self.playing) {
        
        const NSUInteger leftFrames = (_decoder.validVideo ? _videoFrames.count : 0);
        
        if (0 == leftFrames) {
            
            if (_decoder.isEOF) {
                [self pause];
                return;
            }
            
            if (_minBufferedDuration > 0 && !_buffered) {
                _buffered = YES;
            }
        }
        
        if (!leftFrames ||
            !(_bufferedDuration > _minBufferedDuration)) {
            
            [self asyncDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const CGFloat fps = (_decoder.fps > 0) ? _decoder.fps : 25.0f;
        const NSTimeInterval time = MAX(interval + correction, 1.0f/fps);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
    }
    
//    if ((_tickCounter++ % 3) == 0) {
//        [self updateHUD];
//    }
}

- (CGFloat)tickCorrection {
    if (_buffered)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!_tickCorrectionTime) {
        
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    //if ((_tickCounter % 200) == 0)
    //    LoggerStream(1, @"tick correction %.4f", correction);
    
    if (correction > 1.f || correction < -1.f) {
        
        NSLog(@"tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
}

- (CGFloat)presentFrame {
    CGFloat interval = 0;
    if (_decoder.validVideo) {
        FDVideoFrame *frame;
        @synchronized(_videoFrames) {
            if (_videoFrames.count > 0) {
                frame = _videoFrames[0];
                [_videoFrames removeObjectAtIndex:0];
                _bufferedDuration -= frame.duration;
            }
        }
        
        if (frame) {
            interval = [self presentVideoFrame:frame];
        }
    }
    return interval;
}

- (CGFloat) presentVideoFrame:(FDVideoFrame *)frame {
    if (_glView) {
        
        [_glView render:frame];
        
    } else {
        
        FDVideoFrameRGB *rgbFrame = (FDVideoFrameRGB *)frame;
        _imageView.image = [rgbFrame asImage];
    }
    
    _moviePosition = frame.position;
    
    return frame.duration;
}

- (void)setMoviePositionFromDecoder {
    _moviePosition = _decoder.position;
}

- (void)setDecoderPosition:(CGFloat)position {
    _decoder.position = position;
}

- (void)freeBufferedFrames {
    @synchronized(_videoFrames) {
        [_videoFrames removeAllObjects];
    }

    _bufferedDuration = 0;
}

//- (BOOL) interruptDecoder {
//    return _interrupted;
//}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return ![touch.view isKindOfClass:[UIButton class]];
}

@end

