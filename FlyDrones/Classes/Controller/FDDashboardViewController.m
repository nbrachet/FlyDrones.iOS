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
#import "FDCustomModeViewController.h"
#import "FDEnableArmedViewController.h"

#define debugWithLocalLogFile NO

static NSUInteger const FDDashboardViewControllerWaitingHeartbeatHUDTag = 8410;
static NSUInteger const FDDashboardViewControllerConnectingToTCPServerHUDTag = 8411;
static NSUInteger const FDDashboardViewControllerErrorHUDTag = 8412;

@interface FDDashboardViewController () <FDConnectionManagerDelegate, FDMovieDecoderDelegate, FDDroneControlManagerDelegate, UIAlertViewDelegate, FDCustomModeViewControllerDelegate, FDEnableArmedViewControllerDelegate, UIPopoverPresentationControllerDelegate>

@property (nonatomic, weak) IBOutlet UIButton *menuButton;
@property (nonatomic, weak) IBOutlet FDBatteryButton *batteryButton;
@property (nonatomic, weak) IBOutlet FDCompassView *compassView;
@property (nonatomic, weak) IBOutlet FDMovieGLView *movieGLView;
@property (nonatomic, weak) IBOutlet UIButton *armedStatusButton;
@property (nonatomic, weak) IBOutlet UIButton *systemStatusButton;
@property (nonatomic, weak) IBOutlet UIButton *worldwideLocationButton;
@property (nonatomic, weak) IBOutlet FDJoystickView *leftJoystickView;
@property (nonatomic, weak) IBOutlet FDJoystickView *rightJoystickView;

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
    self.enabledControls = YES;
    self.leftJoystickView.mode = FDJoystickViewModeSavedVerticalPosition;
    self.leftJoystickView.isSingleActiveAxis = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.enabledControls = NO;

    self.droneControlManager = [[FDDroneControlManager alloc] init];
    self.droneControlManager.delegate = self;
    
    if (![self.timer isValid]) {
        [self startTimer];
    }
    [self registerForNotifications];
    
    if (debugWithLocalLogFile) {
        [self.droneControlManager parseLogFile:@"2015-05-01 20-19-25" ofType:@"tlog"];
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
    
    [MBProgressHUD hideAllHUDsForView:self.movieGLView animated:NO];
    
    [[FDDroneStatus currentStatus] clearStatus];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    UIViewController *destinationViewController = segue.destinationViewController;
    UIPopoverPresentationController *popoverPresentationController = destinationViewController.popoverPresentationController;
    if (popoverPresentationController != nil) {
        popoverPresentationController.delegate = self;
        popoverPresentationController.backgroundColor = [UIColor clearColor];
    }
    
    if ([destinationViewController isKindOfClass:[FDCustomModeViewController class]]) {
        [((FDCustomModeViewController *)destinationViewController) setDelegate:self];
    }
    if ([destinationViewController isKindOfClass:[FDEnableArmedViewController class]]) {
        [((FDEnableArmedViewController *)destinationViewController) setDelegate:self];
    }

}

#pragma mark - Custom Accessors

- (void)setEnabledControls:(BOOL)enabledControls {
    _enabledControls = enabledControls;
    
    self.batteryButton.enabled = enabledControls;
    self.systemStatusButton.enabled = enabledControls;
    self.compassView.enabled = enabledControls;
    self.armedStatusButton.enabled = enabledControls;
    self.worldwideLocationButton.enabled = enabledControls && CLLocationCoordinate2DIsValid([FDDroneStatus currentStatus].gpsInfo.locationCoordinate);
    
    self.leftJoystickView.userInteractionEnabled = enabledControls;
    self.rightJoystickView.userInteractionEnabled = enabledControls;
    if (!enabledControls) {
        [self.presentedViewController dismissViewControllerAnimated:NO completion:nil];
        [self.leftJoystickView resetPosition];
        [self.rightJoystickView resetPosition];
    } else {
        NSString *armedStatusButtonTitle = ([FDDroneStatus currentStatus].mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED) ? @"ARM" : @"DISARM";
        [self.armedStatusButton setTitle:armedStatusButtonTitle forState:UIControlStateNormal];
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


- (void)connectToServers {
    if (self.connectionManager == nil) {
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
    }
    
    if (![self.connectionManager isTCPConnected]) {

        self.lastReceivedHeartbeatMessageTimeInterval = CACurrentMediaTime();
        self.enabledControls = NO;
        
        MBProgressHUD *progressHUD = [self progressHUDForTag:FDDashboardViewControllerConnectingToTCPServerHUDTag];
        
        if (progressHUD == nil) {
            [MBProgressHUD hideAllHUDsForView:self.movieGLView animated:NO];
            MBProgressHUD *progressHUD = [MBProgressHUD showHUDAddedTo:self.movieGLView animated:YES];
            progressHUD.labelText = NSLocalizedString(@"Connecting to TCP server", @"Connecting to TCP server");
            progressHUD.tag = FDDashboardViewControllerConnectingToTCPServerHUDTag;
        }
        
        BOOL isConnectedToTCPServer = [self.connectionManager receiveTCPServer:[FDDroneStatus currentStatus].pathForTCPConnection
                                                                          port:[FDDroneStatus currentStatus].portForTCPConnection];
        if (!isConnectedToTCPServer) {
            [MBProgressHUD hideAllHUDsForView:self.movieGLView animated:YES];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Used TCP port is blocked. Please shut all of the applications that use data streaming"
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }
    
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
    
    if (![self.connectionManager isTCPConnected] && ! debugWithLocalLogFile) {
        if ((tickCounter % 15 == 0)) {
            [self connectToServers];
        }
        return;
    }
    
    if (tickCounter % 10 == 0) {
        [self.connectionManager sendDataFromTCPConnection:[self.droneControlManager heartbeatData]];
    }
    
    CFTimeInterval delayHeartbeatMessageTimeInterval = CACurrentMediaTime() - self.lastReceivedHeartbeatMessageTimeInterval;
    if (delayHeartbeatMessageTimeInterval > 2.0f) {
        [self dissmissErrorProgressHUD];
        MBProgressHUD *progressHUD = [self progressHUDForTag:FDDashboardViewControllerWaitingHeartbeatHUDTag];
        if (progressHUD == nil) {
            progressHUD = [MBProgressHUD showHUDAddedTo:self.movieGLView animated:YES];
            progressHUD.labelText = NSLocalizedString(@"Waiting heartbeat message", @"Waiting heartbeat message");
            progressHUD.tag = FDDashboardViewControllerWaitingHeartbeatHUDTag;
        }
        progressHUD.detailsLabelText = [NSString stringWithFormat:@"%.1f sec", delayHeartbeatMessageTimeInterval];
        self.enabledControls = NO;
        return;
    }
    
    [self dissmissProgressHUDForTag:FDDashboardViewControllerWaitingHeartbeatHUDTag];
    [self dissmissProgressHUDForTag:FDDashboardViewControllerConnectingToTCPServerHUDTag];

    //send control data
    NSData *controlData = [self.droneControlManager messageDataWithPitch:self.rightJoystickView.stickVerticalValue
                                                                    roll:self.rightJoystickView.stickHorisontalValue
                                                                  thrust:self.leftJoystickView.stickVerticalValue
                                                                     yaw:self.leftJoystickView.stickHorisontalValue
                                                          sequenceNumber:1];
    [self.connectionManager sendDataFromTCPConnection:controlData tag:12];
}

- (MBProgressHUD *)progressHUDForTag:(NSUInteger)tag {
    MBProgressHUD *progressHUD;
    for (UIView *hudView in [MBProgressHUD allHUDsForView:self.movieGLView]) {
        if (hudView.tag == tag) {
            progressHUD = (MBProgressHUD *)hudView;
            break;
        }
    }
    return progressHUD;
}

- (void)dissmissProgressHUDForTag:(NSUInteger)tag {
    MBProgressHUD *progressHUD = [self progressHUDForTag:tag];
    [progressHUD hide:NO];
}

- (void)showErrorProgressHUDWithText:(NSString *)text {
    MBProgressHUD *progressHUD = [self progressHUDForTag:FDDashboardViewControllerErrorHUDTag];
    if (progressHUD == nil) {
        progressHUD = [MBProgressHUD showHUDAddedTo:self.movieGLView animated:YES];
        progressHUD.tag = FDDashboardViewControllerErrorHUDTag;
        progressHUD.mode = MBProgressHUDModeText;
    } else {
        [NSObject cancelPreviousPerformRequestsWithTarget:progressHUD];
    }
    progressHUD.labelText = text;
    [progressHUD hide:NO afterDelay:5.0f];
}

- (void)dissmissErrorProgressHUD {
    [self dissmissProgressHUDForTag:FDDashboardViewControllerErrorHUDTag];
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
    self.worldwideLocationButton.enabled = self.isEnabledControls && CLLocationCoordinate2DIsValid(locationCoordinate);
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleBatteryRemaining:(CGFloat)batteryRemaining current:(CGFloat)current voltage:(CGFloat)voltage {
    self.batteryButton.batteryRemainingPercent = batteryRemaining;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleVFRInfoForHeading:(NSUInteger)heading altitude:(CGFloat)altitude airspeed:(CGFloat)airspeed groundspeed:(CGFloat)groundspeed climbRate:(CGFloat)climbRate throttleSetting:(CGFloat)throttleSetting {
    self.compassView.heading = heading;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleNavigationInfo:(CGFloat)navigationBearing {
    self.compassView.navigationBearing = navigationBearing;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleHeartbeatInfo:(uint32_t)mavCustomMode mavType:(uint8_t)mavType mavAutopilotType:(uint8_t)mavAutopilotType mavBaseMode:(uint8_t)mavBaseMode mavSystemStatus:(uint8_t)mavSystemStatus {
//    NSLog(@"%s", __FUNCTION__);
    
    NSMutableString *sysStatusString = [NSMutableString string];
    if (mavBaseMode & (uint8_t)MAV_MODE_FLAG_CUSTOM_MODE_ENABLED) {
        switch (mavCustomMode) {
            case FDAutoPilotModeAcro:
                [sysStatusString appendString:@"ACRO"];
                break;
            case FDAutoPilotModeAltHold:
                [sysStatusString appendString:@"ALT_HOLD"];
                break;
            case FDAutoPilotModeAuto:
                [sysStatusString appendString:@"AUTO"];
                break;
            case FDAutoPilotModeAutotune:
                [sysStatusString appendString:@"AUTOTUNE"];
                break;
            case FDAutoPilotModeCircle:
                [sysStatusString appendString:@"CIRCLE"];
                break;
            case FDAutoPilotModeDrift:
                [sysStatusString appendString:@"DRIFT"];
                break;
            case FDAutoPilotModeFlip:
                [sysStatusString appendString:@"FLIP"];
                break;
            case FDAutoPilotModeGuided:
                [sysStatusString appendString:@"GUIDED"];
                break;
            case FDAutoPilotModeLand:
                [sysStatusString appendString:@"LAND"];
                break;
            case FDAutoPilotModeLoiter:
                [sysStatusString appendString:@"LOITER"];
                break;
            case FDAutoPilotModeOfLoiter:
                [sysStatusString appendString:@"OF_LOITER"];
                break;
            case FDAutoPilotModePoshold:
                [sysStatusString appendString:@"POSHOLD"];
                break;
            case FDAutoPilotModeRTL:
                [sysStatusString appendString:@"RTL"];
                break;
            case FDAutoPilotModeSport:
                [sysStatusString appendString:@"SPORT"];
                break;
            case FDAutoPilotModeStabilize:
                [sysStatusString appendString:@"STABILIZE"];
                break;
            default:
                [sysStatusString appendFormat:@"N/A (%d)", mavCustomMode];
                break;
        }
    } else {
        [sysStatusString appendString:@"N/A"];
    }

    [self.systemStatusButton setTitle:sysStatusString forState:UIControlStateNormal];

    [self dissmissProgressHUDForTag:FDDashboardViewControllerWaitingHeartbeatHUDTag];
    
    self.lastReceivedHeartbeatMessageTimeInterval = CACurrentMediaTime();
    self.enabledControls = YES;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleErrorMessage:(NSString *)errorText {
    MBProgressHUD *waitingHeartbeatProgressHUD = [self progressHUDForTag:FDDashboardViewControllerWaitingHeartbeatHUDTag];
    if (waitingHeartbeatProgressHUD == nil) {
        [self showErrorProgressHUDWithText:errorText];
    }
}

#pragma mark - FDCustomModeViewControllerDelegate

- (void)didSelectNewMode:(FDAutoPilotMode)mode {
    NSData *messageData = [self.droneControlManager messageDataWithNewCustomMode:mode];
    [self.connectionManager sendDataFromTCPConnection:messageData];
}

#pragma mark - FDEnableArmedViewController

- (void)didEnableArmedStatus:(BOOL)armed {
    NSData *messageData = [self.droneControlManager messageDataWithArmedEnable:armed];
    [self.connectionManager sendDataFromTCPConnection:messageData];
}

#pragma mark - UIPopoverPresentationControllerDelegate

- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    [self.presentedViewController dismissViewControllerAnimated:NO completion:nil];
    return NO;
}

@end

