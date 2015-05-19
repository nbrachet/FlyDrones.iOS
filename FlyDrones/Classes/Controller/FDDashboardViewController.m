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
#import <SWRevealViewController/SWRevealViewController.h>
#import "FDBatteryButton.h"
#import "FDDroneStatus.h"
#import "FDCompassView.h"
#import "FDJoystickView.h"

@interface FDDashboardViewController () <FDConnectionManagerDelegate, FDMovieDecoderDelegate, FDDroneControlManagerDelegate, UIAlertViewDelegate>

@property (nonatomic, weak) IBOutlet UIButton *menuButton;
@property (nonatomic, weak) IBOutlet FDBatteryButton *batteryButton;
@property (nonatomic, weak) IBOutlet FDCompassView *compassView;
@property (nonatomic, weak) IBOutlet FDMovieGLView *movieGLView;
@property (nonatomic, weak) IBOutlet UIButton *altitudeButton;
@property (nonatomic, weak) IBOutlet UIButton *temperatureButton;
@property (nonatomic, weak) IBOutlet UIButton *worldwideLocationButton;
@property (nonatomic, weak) IBOutlet FDJoystickView *leftJoystickView;
@property (nonatomic, weak) IBOutlet FDJoystickView *rightJoystickView;
@property (nonatomic, weak) IBOutlet UILabel *modeLabel;

@property (nonatomic, strong) FDConnectionManager *connectionManager;
@property (nonatomic, strong) FDMovieDecoder *movieDecoder;
@property (nonatomic, strong) FDDroneControlManager *droneControlManager;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation FDDashboardViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self customSetup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    
    self.droneControlManager = [[FDDroneControlManager alloc] init];
    self.droneControlManager.delegate = self;
    
    self.connectionManager = [[FDConnectionManager alloc] init];
    self.connectionManager.delegate = self;
    
    BOOL isConnectedToUDPServer = [self.connectionManager connectToServer:[FDDroneStatus currentStatus].pathForUDPConnection
                                                        portForConnection:[FDDroneStatus currentStatus].portForUDPConnection
                                                          portForReceived:[FDDroneStatus currentStatus].portForUDPConnection];
    if (!isConnectedToUDPServer) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Used UDP port is blocked. Please shut all of the applications that use data streaming"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    
    BOOL isConnectedToTCPServer = [self.connectionManager receiveTCPServer:[FDDroneStatus currentStatus].pathForTCPConnection
                                                                      port:[FDDroneStatus currentStatus].portForTCPConnection];
    if (!isConnectedToTCPServer) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Used TCP port is blocked. Please shut all of the applications that use data streaming"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (![self.timer isValid]) {
        [self startTimer];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self stopTimer];
    
    [self.connectionManager closeConnection];
    self.connectionManager = nil;
    self.movieDecoder = nil;
    self.droneControlManager = nil;
    
    [[FDDroneStatus currentStatus] clearStatus];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ShowBatteryStatus"] ||
        [segue.identifier isEqualToString:@"ShowScaledPressure"] ||
        [segue.identifier isEqualToString:@"ShowVFRInfo"] ||
        [segue.identifier isEqualToString:@"ShowLocationInfo"]) {
        UIViewController *destinationViewController = segue.destinationViewController;
        UIPopoverPresentationController *popoverPresentationController = destinationViewController.popoverPresentationController;
        popoverPresentationController.backgroundColor = destinationViewController.view.backgroundColor;
    }
}

#pragma mark - UIStateRestoration

- (void)applicationFinishedRestoringState {
    [super applicationFinishedRestoringState];
    [self customSetup];
}

#pragma mark - IBActions

- (IBAction)menu:(id)sender {
    if (self.revealViewController != nil) {
        [self.revealViewController revealToggle:sender];
    }
}

- (IBAction)showBatteryStatus:(id)sender {
    [self performSegueWithIdentifier:@"ShowBatteryStatus" sender:sender];
}

#pragma mark - Private

- (void)customSetup {
    if (self.revealViewController != nil) {
        [self.navigationController.navigationBar addGestureRecognizer:self.revealViewController.panGestureRecognizer];
    }
}

- (void)startTimer {
    [self stopTimer];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1f
                                                  target:self
                                                selector:@selector(timerTick:)
                                                userInfo:nil
                                                 repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)timerTick:(NSTimer *)timer {
    static NSUInteger tickCounter = 0;
    tickCounter++;
    if (tickCounter % 10 == 0) {
        [self.connectionManager sendDataFromTCPConnection:[self.droneControlManager heartbeatData]];
    }

    NSData *controlData = [self.droneControlManager messageDataWithPitch:self.leftJoystickView.stickVerticalValue
                                                                    roll:self.leftJoystickView.stickHorisontalValue
                                                                  thrust:self.rightJoystickView.stickVerticalValue
                                                                     yaw:self.rightJoystickView.stickHorisontalValue
                                                          sequenceNumber:1];
    [self.connectionManager sendDataFromTCPConnection:controlData];
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    //    [self back:nil];
}

#pragma mark - FDConnectionManagerDelegate

- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveUDPData:(NSData *)data {
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

#pragma mark - FDDroneControlManagerDelegate

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didParseMessage:(NSString *)messageDescription {
//    NSLog(@"%@", messageDescription);
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleLocationCoordinate:(CLLocationCoordinate2D)locationCoordinate {
    self.worldwideLocationButton.enabled = CLLocationCoordinate2DIsValid(locationCoordinate);
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleBatteryRemaining:(CGFloat)batteryRemaining current:(CGFloat)current voltage:(CGFloat)voltage {
    
    self.batteryButton.batteryRemainingPercent = batteryRemaining;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleVFRInfoForHeading:(NSUInteger)heading altitude:(CGFloat)altitude airspeed:(CGFloat)airspeed groundspeed:(CGFloat)groundspeed climbRate:(CGFloat)climbRate throttleSetting:(CGFloat)throttleSetting {
    self.compassView.heading = heading;

    NSString *altitudeString = (altitude != FDNotAvailable) ? [NSString stringWithFormat:@"%0.2f m", altitude] : @"N/A";
    [UIView performWithoutAnimation:^{
        self.altitudeButton.titleLabel.text = altitudeString;
        [self.altitudeButton setTitle:altitudeString forState:UIControlStateNormal];
    }];
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleNavigationInfo:(CGFloat)navigationBearing {
    self.compassView.navigationBearing = navigationBearing;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleScaledPressureInfo:(CGFloat)temperature absolutePressure:(CGFloat)absolutePressure differentialPressure:(CGFloat)differentialPressure {
    
    NSString *temperatureString = (temperature != FDNotAvailable) ? [NSString stringWithFormat:@"%0.1f°C", temperature] : @"N/A";
    [self.temperatureButton setTitle:temperatureString forState:UIControlStateNormal];
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleHeartbeatInfo:(uint32_t)mavCustomMode mavType:(uint8_t)mavType mavAutopilotType:(uint8_t)mavAutopilotType mavBaseMode:(uint8_t)mavBaseMode mavSystemStatus:(uint8_t)mavSystemStatus {
    NSMutableString *modeString = [NSMutableString string];
    [modeString appendString:@"Mode:\n"];
    if (mavBaseMode & MAV_MODE_FLAG_CUSTOM_MODE_ENABLED) {
        [modeString appendString:@"MAV_MODE_FLAG_CUSTOM_MODE_ENABLED"];
    } else if (mavBaseMode & MAV_MODE_FLAG_TEST_ENABLED) {
        [modeString appendString:@"MAV_MODE_FLAG_TEST_ENABLED"];
    } else if (mavBaseMode & MAV_MODE_FLAG_AUTO_ENABLED) {
        [modeString appendString:@"MAV_MODE_FLAG_AUTO_ENABLED"];
    } else if (mavBaseMode & MAV_MODE_FLAG_STABILIZE_ENABLED) {
        [modeString appendString:@"MAV_MODE_FLAG_STABILIZE_ENABLED"];
    } else if (mavBaseMode & MAV_MODE_FLAG_HIL_ENABLED) {
        [modeString appendString:@"MAV_MODE_FLAG_HIL_ENABLED"];
    } else if (mavBaseMode & MAV_MODE_FLAG_MANUAL_INPUT_ENABLED) {
        [modeString appendString:@"MAV_MODE_FLAG_MANUAL_INPUT_ENABLED"];
    } else if (mavBaseMode & MAV_MODE_FLAG_SAFETY_ARMED) {
        [modeString appendString:@"MAV_MODE_FLAG_SAFETY_ARMED"];
    } else if (mavBaseMode & MAV_MODE_FLAG_ENUM_END) {
        [modeString appendString:@"MAV_MODE_FLAG_ENUM_END"];
    }
    [modeString appendFormat:@"\nCustom Mode:\n%d", mavCustomMode];

    self.modeLabel.text = modeString;
}

@end

