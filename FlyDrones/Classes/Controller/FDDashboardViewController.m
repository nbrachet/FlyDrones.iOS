//
//  FDDashboardViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDDashboardViewController.h"
#import "FDMovieDecoder.h"
#import "FDMovieGLView.h"
#import "FDDisplayInfoView.h"
#import "FDConnectionManager.h"
#import "FDDroneControlManager.h"

@interface FDDashboardViewController () <FDConnectionManagerDelegate, FDMovieDecoderDelegate, FDDroneControlManagerDelegate, UIAlertViewDelegate>

@property (nonatomic, weak) IBOutlet FDMovieGLView *movieGLView;
@property (nonatomic, weak) IBOutlet UILabel *locationLabel;
@property (nonatomic, weak) IBOutlet UILabel *batteryRemainingLabel;
@property (nonatomic, weak) IBOutlet UILabel *batteryCurrentLabel;
@property (nonatomic, weak) IBOutlet UILabel *batteryVoltageLabel;
@property (nonatomic, weak) IBOutlet UILabel *attitudeStatusLabel;
@property (nonatomic, weak) IBOutlet UILabel *altitudeLabel;

@property (nonatomic, weak) IBOutlet UITextView *outputTextView;

@property (nonatomic, strong) FDConnectionManager *connectionManager;
@property (nonatomic, strong) FDMovieDecoder *movieDecoder;

@property (nonatomic, strong) FDDroneControlManager *droneControlManager;

@end

@implementation FDDashboardViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.connectionManager = [[FDConnectionManager alloc] init];
    self.connectionManager.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    BOOL isConnected = [self.connectionManager connectToServer:self.hostForConnection portForConnection:self.portForConnection portForReceived:self.portForReceived];
    if (!isConnected) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Used port is blocked. Please shut all of the applications that use data streaming"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    [self.connectionManager receiveTCPServer:self.hostForTCPConnection port:self.portForTCPConnection];
    
//    [self.droneControlManager parseLogFile:@"2015-04-15 10-57-47" ofType:@"tlog"];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self.connectionManager closeConnection];
    self.connectionManager = nil;
    
    self.movieDecoder = nil;
    self.droneControlManager = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - Public


#pragma mark - IBActions

- (IBAction)back:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Private


#pragma mark - FDConnectionManagerDelegate

- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveData:(NSData *)data {
    if (data.length == 0) {
        return;
    }

    if (self.movieDecoder == nil) {
        self.movieDecoder = [[FDMovieDecoder alloc] initFromReceivedData:data delegate:self];
    }

    [self.movieDecoder parseAndDecodeInputData:data];
}

- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveTCPData:(NSData *)data {
    if (data.length == 0) {
        return;
    }
    
    if (self.droneControlManager == nil) {
        self.droneControlManager = [[FDDroneControlManager alloc] init];
        self.droneControlManager.delegate = self;
    }
    
    [self.droneControlManager parseInputData:data];
}

#pragma mark - FDMovieDecoderDelegate

- (void)movieDecoder:(FDMovieDecoder *)movieDecoder decodedVideoFrame:(FDVideoFrame *)videoFrame {
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        [strongSelf.movieGLView renderVideoFrame:videoFrame];
    });
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self back:nil];
}

#pragma mark - FDDroneControlManagerDelegate

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didParseMessage:(NSString *)messageDescription {
    NSLog(@"%@", messageDescription);

    if (self.outputTextView.text.length == 0) {
        self.outputTextView.text = messageDescription;
    } else {
        self.outputTextView.text = [self.outputTextView.text stringByAppendingFormat:@"\n%@", messageDescription];
    }
    self.outputTextView.textColor = [UIColor whiteColor];
    
    [self.outputTextView scrollRangeToVisible:NSMakeRange(self.outputTextView.text.length, 0)];
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleBatteryRemaining:(NSInteger)batteryRemaining current:(CGFloat)current voltage:(CGFloat)voltage {
    NSMutableString *batteryRemainingString = [NSMutableString stringWithString:@"Battery Remaining: "];
    if (batteryRemaining == -1) {
        [batteryRemainingString appendString:@"unknown"];
    } else {
        [batteryRemainingString appendFormat:@"%ld%%", (long)batteryRemaining];
    }
    self.batteryRemainingLabel.text = batteryRemainingString;
    
    NSMutableString *batteryCurrentString = [NSMutableString stringWithString:@"Battery Current: "];
    if (current == -1) {
        [batteryCurrentString appendString:@"unknown"];
    } else {
        [batteryCurrentString appendFormat:@"%0.3fA", current];
    }
    self.batteryCurrentLabel.text = batteryCurrentString;
    
    NSMutableString *batteryVoltageString = [NSMutableString stringWithString:@"Battery Voltage: "];
    if (voltage == -1) {
        [batteryVoltageString appendString:@"unknown"];
    } else {
        [batteryVoltageString appendFormat:@"%0.3fV", voltage];
    }
    self.batteryVoltageLabel.text = batteryVoltageString;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleLocationCoordinate:(CLLocationCoordinate2D)locationCoordinate {
    NSMutableString *location = [NSMutableString stringWithString:@"Location Coordinate: "];
    if (locationCoordinate.latitude == 0.0f || locationCoordinate.longitude == 0.0f) {
        [location appendString:@"unknown"];
    } else {
        [location appendFormat:@"%f %f", locationCoordinate.latitude, locationCoordinate.longitude];
    }
    self.locationLabel.text = location;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleVFRInfoForHeading:(NSUInteger)heading airspeed:(CGFloat)airspeed altitude:(CGFloat)altitude {
    
    
    self.altitudeLabel.text = [NSString stringWithFormat:@"Altitude: %0.2f", altitude];
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleAttitudeRoll:(CGFloat)roll pitch:(CGFloat)pitch yaw:(CGFloat)yaw rollspeed:(CGFloat)rollspeed pitchspeed:(CGFloat)pitchspeed yawspeed:(CGFloat)yawspeed {
    
    NSMutableString *attitudeStatusString = [NSMutableString string];
    [attitudeStatusString appendFormat:@"Roll:  %f\n", roll];
    [attitudeStatusString appendFormat:@"Pitch: %f\n", pitch];
    [attitudeStatusString appendFormat:@"Yaw:   %f", yaw];
    
    self.attitudeStatusLabel.text = attitudeStatusString;
}

@end

