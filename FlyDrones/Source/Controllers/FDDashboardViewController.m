//
//  FDDashboardViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDDashboardViewController.h"
#import <DDPopoverBackgroundView/DDPopoverBackgroundView.h>
#import <SWRevealViewController/SWRevealViewController.h>
#import <MBProgressHUD/MBProgressHUD.h>
#import "FDMovieDecoder.h"
#import "FDMovieGLView.h"
#import "FDConnectionManager.h"
#import "FDDroneControlManager.h"
#import "FDBatteryButton.h"
#import "FDDroneStatus.h"
#import "FDCompassView.h"
#import "FDJoystickView.h"
#import "FDCustomModeViewController.h"
#import "FDEnableArmedViewController.h"
#import "mavlink.h"

static NSUInteger const FDDashboardViewControllerWaitingHeartbeatHUDTag = 8410;
static NSUInteger const FDDashboardViewControllerConnectingToTCPServerHUDTag = 8411;
static NSUInteger const FDDashboardViewControllerErrorHUDTag = 8412;

@interface FDDashboardViewController () <FDConnectionManagerDelegate, FDMovieDecoderDelegate, FDDroneControlManagerDelegate, UIAlertViewDelegate, FDCustomModeViewControllerDelegate, FDEnableArmedViewControllerDelegate, UIPopoverPresentationControllerDelegate>

@property (nonatomic, weak) IBOutlet UIView *topPanelView;
@property (nonatomic, weak) IBOutlet UIButton *menuButton;
@property (nonatomic, weak) IBOutlet FDBatteryButton *batteryButton;
@property (nonatomic, weak) IBOutlet FDCompassView *compassView;
@property (nonatomic, weak) IBOutlet UIButton *armedStatusButton;
@property (nonatomic, weak) IBOutlet UIButton *systemStatusButton;
@property (nonatomic, weak) IBOutlet UIButton *worldwideLocationButton;

@property (nonatomic, weak) IBOutlet UIView *movieBackgroundView;

@property (nonatomic, weak) IBOutlet FDMovieGLView *movieGLView;

@property (nonatomic, weak) IBOutlet FDJoystickView *leftJoystickView;
@property (nonatomic, weak) IBOutlet FDJoystickView *rightJoystickView;

@property (nonatomic, assign, getter=isEnabledControls) BOOL enabledControls;

@property (nonatomic, strong) FDConnectionManager *connectionManager;
@property (nonatomic, strong) FDMovieDecoder *movieDecoder;
@property (nonatomic, strong) FDDroneControlManager *droneControlManager;

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) CFTimeInterval lastReceivedHeartbeatMessageTimeInterval;

@property (nonatomic, assign, getter=isArm) BOOL arm;

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

    self.movieDecoder = [[FDMovieDecoder alloc] init];
    self.movieDecoder.delegate = self;
    
    self.droneControlManager = [[FDDroneControlManager alloc] init];
    self.droneControlManager.delegate = self;
    
    if (![self.timer isValid]) {
        [self startTimer];
    }
    
    [self registerForNotifications];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self stopTimer];
    [self unregisterFromNotifications];
    
    [self.movieDecoder stopDecode];
    self.movieDecoder = nil;
    
    [self.connectionManager closeConnections];
    self.connectionManager = nil;
    self.movieDecoder = nil;
    self.droneControlManager = nil;
    
    [self dismissAllProgressHUDs];
    
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
    if ([destinationViewController respondsToSelector:@selector(popoverPresentationController)]) {
        UIPopoverPresentationController *popoverPresentationController = destinationViewController.popoverPresentationController;
        popoverPresentationController.delegate = self;
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
    
    self.arm = [FDDroneStatus currentStatus].mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED;

    self.leftJoystickView.userInteractionEnabled = enabledControls;
    self.rightJoystickView.userInteractionEnabled = enabledControls;
    
    if (!enabledControls) {
        [self dismissPresentedPopoverAnimated:YES];
        [self.leftJoystickView resetPosition];
        [self.rightJoystickView resetPosition];
    } else {
        NSString *armedStatusButtonTitle = self.isArm ? @"ARM" : @"DISARM";
        [self.armedStatusButton setTitle:armedStatusButtonTitle forState:UIControlStateNormal];
    }
}

- (void)setArm:(BOOL)arm {
    if (_arm == arm) {
        return;
    }
    
    _arm = arm;
    
    NSData *controlData;
    if (arm) {
        controlData = [self.droneControlManager messageDataWithCaptureSettingsFps:[FDDroneStatus currentStatus].videoFps
                                                                          bitrate:[FDDroneStatus currentStatus].videoBitrate];
    } else {
        controlData = [self.droneControlManager messageDataWithCaptureDisable];
    }
    if (controlData.length > 0) {
        [self.connectionManager sendDataToControlServer:controlData];
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
    [self.connectionManager closeConnections];
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
    }
    
    if (![self.connectionManager isConnectedToVideoHost]) {
        [self.connectionManager connectToVideoHost:[FDDroneStatus currentStatus].pathForUDPConnection
                                              port:[FDDroneStatus currentStatus].portForUDPConnection];
    }
    
    if (![self.connectionManager isConnectedToControlHost]) {
        self.lastReceivedHeartbeatMessageTimeInterval = CACurrentMediaTime();
        self.enabledControls = NO;
        
        if (![self progressHUDForTag:FDDashboardViewControllerConnectingToTCPServerHUDTag]) {
            [self dismissAllProgressHUDs];
        }
        MBProgressHUD *progressHUD = [self showProgressHUDWithTag:FDDashboardViewControllerConnectingToTCPServerHUDTag];
        progressHUD.labelText = NSLocalizedString(@"Connecting to TCP server", @"Connecting to TCP server");
        
        BOOL isConnectedToTCPServer = [self.connectionManager connectToControlHost:[FDDroneStatus currentStatus].pathForTCPConnection
                                                                              port:[FDDroneStatus currentStatus].portForTCPConnection];
        if (!isConnectedToTCPServer) {
            [self dismissAllProgressHUDs];
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
    
    if (![self.connectionManager isConnectedToControlHost]) {
        if ((tickCounter % 15 == 0)) {
            [self connectToServers];
        }
        return;
    }
    
    if (tickCounter % 10 == 0) {
        [self.connectionManager sendDataToControlServer:[self.droneControlManager heartbeatData]];
    }
    
    CFTimeInterval delayHeartbeatMessageTimeInterval = CACurrentMediaTime() - self.lastReceivedHeartbeatMessageTimeInterval;
    if (delayHeartbeatMessageTimeInterval > 2.0f) {
        [self dismissErrorProgressHUD];
        MBProgressHUD *progressHUD = [self showProgressHUDWithTag:FDDashboardViewControllerWaitingHeartbeatHUDTag];
        progressHUD.labelText = NSLocalizedString(@"Waiting heartbeat message", @"Waiting heartbeat message");
        progressHUD.detailsLabelText = [NSString stringWithFormat:@"%.1f sec", delayHeartbeatMessageTimeInterval];
        self.enabledControls = NO;
        return;
    }
    
    [self dismissProgressHUDForTag:FDDashboardViewControllerWaitingHeartbeatHUDTag];
    [self dismissProgressHUDForTag:FDDashboardViewControllerConnectingToTCPServerHUDTag];

    //send control data
    NSData *controlData = [self.droneControlManager messageDataWithPitch:self.rightJoystickView.stickVerticalValue
                                                                    roll:self.rightJoystickView.stickHorisontalValue
                                                                  thrust:self.leftJoystickView.stickVerticalValue
                                                                     yaw:self.leftJoystickView.stickHorisontalValue
                                                          sequenceNumber:1];

    [self.connectionManager sendDataToControlServer:controlData];
}

- (MBProgressHUD *)progressHUDForTag:(NSUInteger)tag {
    MBProgressHUD *progressHUD;
    for (UIView *hudView in [MBProgressHUD allHUDsForView:self.movieBackgroundView]) {
        if (hudView.tag == tag) {
            progressHUD = (MBProgressHUD *)hudView;
            break;
        }
    }
    return progressHUD;
}

- (MBProgressHUD *)showProgressHUDWithTag:(NSUInteger)tag {
    MBProgressHUD *progressHUD = [self progressHUDForTag:tag];
    if (progressHUD == nil) {
        progressHUD = [MBProgressHUD showHUDAddedTo:self.movieBackgroundView animated:YES];
        progressHUD.tag = tag;
        progressHUD.color = [UIColor colorWithRed:24.0f/255.0f green:43.0f/255.0f blue:72.0f/255.0f alpha:0.5f];
    } else {
        [NSObject cancelPreviousPerformRequestsWithTarget:progressHUD];
    }
    
    return progressHUD;
}

- (MBProgressHUD *)showErrorProgressHUDWithText:(NSString *)text {
    MBProgressHUD *progressHUD = [self showProgressHUDWithTag:FDDashboardViewControllerErrorHUDTag];
    progressHUD.mode = MBProgressHUDModeText;
    progressHUD.labelText = text;
    [progressHUD hide:NO afterDelay:5.0f];
    return progressHUD;
}

- (void)dismissProgressHUDForTag:(NSUInteger)tag {
    MBProgressHUD *progressHUD = [self progressHUDForTag:tag];
    [progressHUD hide:NO];
}

- (void)dismissAllProgressHUDs {
    [MBProgressHUD hideAllHUDsForView:self.movieBackgroundView animated:NO];
}

- (void)dismissErrorProgressHUD {
    [self dismissProgressHUDForTag:FDDashboardViewControllerErrorHUDTag];
}

- (void)dismissPresentedPopoverAnimated:(BOOL)animated {
    [self.presentedViewController dismissViewControllerAnimated:animated completion:nil];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    //    [self back:nil];
}

#pragma mark - FDConnectionManagerDelegate

- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveVideoData:(NSData *)data {
    if (data.length == 0) {
        return;
    }

    [self.movieDecoder parseAndDecodeInputData:data];
}

- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveControlData:(NSData *)data {
    if (data.length == 0) {
        return;
    }
    
    [self.droneControlManager parseInputData:data];
}

#pragma mark - FDMovieDecoderDelegate

- (void)movieDecoder:(FDMovieDecoder *)movieDecoder decodedVideoFrame:(FDVideoFrame *)videoFrame {
    [self.movieGLView renderVideoFrame:videoFrame];
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

    [self dismissProgressHUDForTag:FDDashboardViewControllerWaitingHeartbeatHUDTag];
    
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
    [self.connectionManager sendDataToControlServer:messageData];
    [self dismissPresentedPopoverAnimated:YES];
}

#pragma mark - FDEnableArmedViewController

- (void)didEnableArmedStatus:(BOOL)armed {
    NSData *messageData = [self.droneControlManager messageDataWithArmedEnable:armed];
    [self.connectionManager sendDataToControlServer:messageData];
    [self dismissPresentedPopoverAnimated:YES];
}

#pragma mark - UIPopoverPresentationControllerDelegate

- (void)prepareForPopoverPresentation:(UIPopoverPresentationController *)popoverPresentationController {
    popoverPresentationController.backgroundColor = [UIColor clearColor];
    popoverPresentationController.passthroughViews = @[self.leftJoystickView, self.rightJoystickView];
    popoverPresentationController.popoverBackgroundViewClass = [DDPopoverBackgroundView class];
    [DDPopoverBackgroundView setTintColor:self.topPanelView.backgroundColor];
    [DDPopoverBackgroundView setShadowEnabled:NO];
    [DDPopoverBackgroundView setContentInset:0.0f];
    [DDPopoverBackgroundView setBackgroundImageCornerRadius:10.0f];
}

- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    [self dismissPresentedPopoverAnimated:NO];
    return NO;
}

@end
