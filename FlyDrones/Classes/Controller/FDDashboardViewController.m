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

static NSUInteger const FDDashboardViewControllerWaitingHeartbeatHUDTag = 8410;

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

@property (nonatomic, assign, getter=isEnabledControls) BOOL enabledControls;

@property (nonatomic, strong) FDConnectionManager *connectionManager;
@property (nonatomic, strong) FDMovieDecoder *movieDecoder;
@property (nonatomic, strong) FDDroneControlManager *droneControlManager;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) CFTimeInterval lastReceivedHeartbeatMessageTimeInterval;

@end

@implementation FDDashboardViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self customSetup];
    self.enabledControls = NO;
    self.leftJoystickView.mode = FDJoystickViewModeSavedVerticalPosition;
    self.leftJoystickView.isSingleActiveAxis = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.droneControlManager = [[FDDroneControlManager alloc] init];
    self.droneControlManager.delegate = self;

    [self connectToServers];
    
    if (![self.timer isValid]) {
        [self startTimer];
    }
    [self registerForNotifications];
}

- (void)connectToServers {
    if (self.connectionManager != nil) {
        return;
    }
    
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

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self stopTimer];
    [self unregisterFromNotifications];
    
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

#pragma mark - Custom Accessors

- (void)setEnabledControls:(BOOL)enabledControls {
    _enabledControls = enabledControls;
    
    self.batteryButton.enabled = enabledControls;
    self.altitudeButton.enabled = enabledControls;
//    self.worldwideLocationButton.enabled = enabledControls;
    self.leftJoystickView.userInteractionEnabled = enabledControls;
    self.rightJoystickView.userInteractionEnabled = enabledControls;
    
    if (!enabledControls) {
        [[self presentingViewController] dismissViewControllerAnimated:YES completion:nil];
        [self.leftJoystickView resetPosition];
        [self.rightJoystickView resetPosition];
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

- (void)registerForNotifications {
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(applicationDidEnterBackground)
                                                name:UIApplicationDidEnterBackgroundNotification
                                              object:nil];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(applicationDidBecomeActive)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
}

- (void)unregisterFromNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationDidEnterBackground {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self stopTimer];
    [self.connectionManager closeConnection];
    self.connectionManager = nil;
}

- (void)applicationDidBecomeActive {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self connectToServers];
    [self startTimer];
}

- (void)startTimer {
    self.lastReceivedHeartbeatMessageTimeInterval = CACurrentMediaTime();

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
    
    CFTimeInterval delayHeartbeatMessageTimeInterval = CACurrentMediaTime() - self.lastReceivedHeartbeatMessageTimeInterval;
    if (delayHeartbeatMessageTimeInterval > 2.0f) {
        MBProgressHUD *progressHUD = [MBProgressHUD HUDForView:self.movieGLView];
        if (progressHUD == nil) {
            progressHUD = [MBProgressHUD showHUDAddedTo:self.movieGLView animated:YES];
            progressHUD.labelText = NSLocalizedString(@"Waiting heartbeat message", @"Waiting heartbeat message");
            progressHUD.tag = FDDashboardViewControllerWaitingHeartbeatHUDTag;
        }
        progressHUD.detailsLabelText = [NSString stringWithFormat:@"%.1f sec", delayHeartbeatMessageTimeInterval];
        self.enabledControls = NO;
        return;
    }
    
    //send control data
    NSData *controlData = [self.droneControlManager messageDataWithPitch:self.rightJoystickView.stickVerticalValue
                                                                    roll:self.rightJoystickView.stickHorisontalValue
                                                                  thrust:self.leftJoystickView.stickVerticalValue
                                                                     yaw:self.leftJoystickView.stickHorisontalValue
                                                          sequenceNumber:1];
    [self.connectionManager sendDataFromTCPConnection:controlData];
}

- (void)dissmissProgressHUDForTag:(NSUInteger)tag {
    for (UIView *hudView in [MBProgressHUD allHUDsForView:self.movieGLView]) {
        if (hudView.tag == tag) {
            [hudView removeFromSuperview];
            break;
        }
    }
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
//    self.worldwideLocationButton.enabled =  CLLocationCoordinate2DIsValid(locationCoordinate);
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

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleHeartbeatInfo:(uint32_t)mavCustomMode mavType:(uint8_t)mavType mavAutopilotType:(uint8_t)mavAutopilotType mavBaseMode:(uint8_t)mavBaseMode mavSystemStatus:(uint8_t)mavSystemStatus {
    
    [self dissmissProgressHUDForTag:FDDashboardViewControllerWaitingHeartbeatHUDTag];
    
    self.lastReceivedHeartbeatMessageTimeInterval = CACurrentMediaTime();
    self.enabledControls = YES;

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
    } else {
        [modeString appendFormat:@"%d", mavBaseMode];
    }
    
    [modeString appendFormat:@"\nCustom Mode:\n"];
    switch (mavCustomMode) {
        case FDAutoPilotModeAcro:
            [modeString appendString:@"ACRO"];
            break;
        case FDAutoPilotModeAltHold:
            [modeString appendString:@"ALT_HOLD"];
            break;
        case FDAutoPilotModeAuto:
            [modeString appendString:@"AUTO"];
            break;
        case FDAutoPilotModeAutotune:
            [modeString appendString:@"AUTOTUNE"];
            break;
        case FDAutoPilotModeCircle:
            [modeString appendString:@"CIRCLE"];
            break;
        case FDAutoPilotModeDrift:
            [modeString appendString:@"DRIFT"];
            break;
        case FDAutoPilotModeFlip:
            [modeString appendString:@"FLIP"];
            break;
        case FDAutoPilotModeGuided:
            [modeString appendString:@"GUIDED"];
            break;
        case FDAutoPilotModeLand:
            [modeString appendString:@"LAND"];
            break;
        case FDAutoPilotModeLoiter:
            [modeString appendString:@"LOITER"];
            break;
        case FDAutoPilotModeOfLoiter:
            [modeString appendString:@"OF_LOITER"];
            break;
        case FDAutoPilotModePoshold:
            [modeString appendString:@"POSHOLD"];
            break;
        case FDAutoPilotModeRTL:
            [modeString appendString:@"RTL"];
            break;
        case FDAutoPilotModeSport:
            [modeString appendString:@"SPORT"];
            break;
        case FDAutoPilotModeStabilize:
            [modeString appendString:@"STABILIZE"];
            break;
        default:
            [modeString appendFormat:@"%d", mavCustomMode];
            break;
    }
    
    self.modeLabel.text = modeString;
}

@end

