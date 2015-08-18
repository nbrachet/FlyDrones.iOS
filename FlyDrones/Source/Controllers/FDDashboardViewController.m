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
#import "FDVerticalScaleView.h"
#import "FDLocationInfoViewController.h"
#import "FDOptionsListViewController.h"

typedef NS_ENUM(NSUInteger, FDDashboardViewControllerHUDTag) {
    FDDashboardViewControllerHUDTagWaitingHeartbeat = 8410,
    FDDashboardViewControllerHUDTagConnectingToTCPServer,
    FDDashboardViewControllerHUDTagWarning
};

static NSString * const FDDashboardViewControllerArmedStatusListIdentifier = @"ArmedStatusListIdentifier";
static NSString * const FDDashboardViewControllerCustomModesListIdentifier = @"CustomModesListIdentifier";

@interface FDDashboardViewController () <FDConnectionManagerDelegate, FDMovieDecoderDelegate, FDDroneControlManagerDelegate, UIAlertViewDelegate, FDOptionsListViewControllerDelegate, UIPopoverPresentationControllerDelegate> {
    CGSize _frameSize;
}

@property (nonatomic, weak) IBOutlet UIView *topPanelView;
@property (nonatomic, weak) IBOutlet UIButton *menuButton;
@property (nonatomic, weak) IBOutlet FDBatteryButton *batteryButton;
@property (nonatomic, weak) IBOutlet FDCompassView *compassView;
@property (nonatomic, weak) IBOutlet UIButton *armedStatusButton;
@property (nonatomic, weak) IBOutlet UIButton *customModesButton;

@property (nonatomic, weak) IBOutlet UIButton *mapButton;
@property (nonatomic, assign, getter=isHideMapAfterConnectionRestored) BOOL hideMapAfterConnectionRestored;

@property (nonatomic, weak) IBOutlet UIView *movieBackgroundView;

@property (nonatomic, weak) IBOutlet FDMovieGLView *movieGLView;

@property (nonatomic, weak) IBOutlet FDVerticalScaleView *altitudeVerticalScaleView;

@property (nonatomic, weak) IBOutlet FDJoystickView *leftJoystickView;
@property (nonatomic, weak) IBOutlet FDJoystickView *rightJoystickView;

@property (nonatomic, assign, getter=isEnabledControls) BOOL enabledControls;

@property (nonatomic, strong) FDConnectionManager *connectionManager;
@property (nonatomic, strong) FDMovieDecoder *movieDecoder;
@property (nonatomic, strong) FDDroneControlManager *droneControlManager;

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) CFTimeInterval lastReceivedHeartbeatMessageTimeInterval;
@property (nonatomic, assign) CFTimeInterval lastConnectionTimeInterval;

@property (nonatomic, assign, getter=isArm) BOOL arm;

@property (nonatomic, weak) MBProgressHUD *currentProgressHUD;

@property (nonatomic, copy) NSArray *customModesOptionsNames;
@property (nonatomic, copy) NSArray *armedModesOptionsNames;

@property (nonatomic, assign, getter=isRequestDataStreamsSent) BOOL requestDataStreamsSent;

@end

@implementation FDDashboardViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self customSetup];
    
    self.leftJoystickView.mode = FDJoystickViewModeSavedVerticalPosition;
    self.leftJoystickView.isSingleActiveAxis = YES;
    
    //Correct size of video
    CGSize movieSize = [FDDroneStatus currentStatus].videoSize;
    NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.movieBackgroundView
                                                                  attribute:NSLayoutAttributeWidth
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.movieBackgroundView
                                                                  attribute:NSLayoutAttributeHeight
                                                                 multiplier:movieSize.width/movieSize.height
                                                                   constant:0.0f];
    [self.movieBackgroundView addConstraint:constraint];
    
    self.enabledControls = YES;
    self.mapButton.enabled = NO;

    self.lastConnectionTimeInterval = CACurrentMediaTime();
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    //application should not fall asleep
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
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

    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    [self stopTimer];
    [self unregisterFromNotifications];
    
    [self.movieDecoder stopDecode];
    self.movieDecoder = nil;
    
    [self.connectionManager closeConnections];
    self.connectionManager = nil;
    self.movieDecoder = nil;
    self.droneControlManager = nil;
    
    [self hideProgressHUD];
    
    [[FDDroneStatus currentStatus] synchronize];
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
    
    if ([destinationViewController isKindOfClass:[FDOptionsListViewController class]]) {
        FDOptionsListViewController *optionsListViewController = (FDOptionsListViewController *)destinationViewController;
        optionsListViewController.delegate = self;
        if (sender == self.armedStatusButton) {
            optionsListViewController.identifier = FDDashboardViewControllerArmedStatusListIdentifier;
        } else if (sender == self.customModesButton) {
            optionsListViewController.identifier = FDDashboardViewControllerCustomModesListIdentifier;
        }
    }
}

#pragma mark - Custom Accessors

- (void)setEnabledControls:(BOOL)enabledControls {
    _enabledControls = enabledControls;
    
    self.batteryButton.enabled = enabledControls;
    self.customModesButton.enabled = enabledControls;
    self.compassView.enabled = enabledControls;
    self.altitudeVerticalScaleView.enabled = enabledControls;
    self.armedStatusButton.enabled = enabledControls;
    
    self.arm = [FDDroneStatus currentStatus].mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED;

    self.leftJoystickView.userInteractionEnabled = enabledControls;
    self.rightJoystickView.userInteractionEnabled = enabledControls;
    
    if (!enabledControls) {
        [self dismissPresentedPopoverAnimated:YES ignoredControllersFromClassesNamed:@[NSStringFromClass([FDLocationInfoViewController class])]];
        [self.leftJoystickView resetPosition];
        [self.rightJoystickView resetPosition];
        [self.armedStatusButton setTitle:@"N/A" forState:UIControlStateNormal];
        [self.customModesButton setTitle:@"N/A" forState:UIControlStateNormal];
    } else {
        NSString *armedStatusButtonTitle = self.isArm ? @"ARMED" : @"DISARMED";
        [self.armedStatusButton setTitle:armedStatusButtonTitle forState:UIControlStateNormal];
    }
}

- (void)setArm:(BOOL)arm {
    if (_arm == arm) {
        return;
    }
    
    _arm = arm;
    [[FDDroneStatus currentStatus] synchronize];
}

- (NSArray *)customModesOptionsNames {
    NSMutableArray *customModesOptionsNames = [@[[NSString nameFromArducopterMode:ARDUCOPTER_MODE_STABILIZE],
                                                 [NSString nameFromArducopterMode:ARDUCOPTER_MODE_ALT_HOLD],
                                                 [NSString nameFromArducopterMode:ARDUCOPTER_MODE_AUTO],
                                                 [NSString nameFromArducopterMode:ARDUCOPTER_MODE_LOITER],
                                                 [NSString nameFromArducopterMode:ARDUCOPTER_MODE_RTL],
                                                 [NSString nameFromArducopterMode:ARDUCOPTER_MODE_LAND],
                                                 [NSString nameFromArducopterMode:ARDUCOPTER_MODE_DRIFT],
                                                 [NSString nameFromArducopterMode:ARDUCOPTER_MODE_POSHOLD]] mutableCopy];
    enum ARDUCOPTER_MODE currentMode = [FDDroneStatus currentStatus].mavCustomMode;
    NSString *currentModeName = [NSString nameFromArducopterMode:currentMode];
    if ([customModesOptionsNames containsObject:currentModeName]) {
        [customModesOptionsNames removeObject:currentModeName];
    }
    _customModesOptionsNames = customModesOptionsNames;
    return _customModesOptionsNames;
}

- (NSArray *)armedModesOptionsNames {
    NSMutableArray *armedModesOptionsNames = [NSMutableArray array];
    [armedModesOptionsNames addObject:([FDDroneStatus currentStatus].mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED) ? @"DISARM" : @"ARM"];
    [armedModesOptionsNames addObject:@"Start Video"];
    [armedModesOptionsNames addObject:@"Stop Video"];
    _armedModesOptionsNames = armedModesOptionsNames;
    return _armedModesOptionsNames;
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
    
    [[FDDroneStatus currentStatus] synchronize];
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
        CFTimeInterval disconnectedTimeInterval = CACurrentMediaTime() - self.lastConnectionTimeInterval;
        if (disconnectedTimeInterval >= 2.0f) {
            self.enabledControls = NO;
        }
        [self showProgressHUDWithTag:FDDashboardViewControllerHUDTagConnectingToTCPServer
                           labelText:NSLocalizedString(@"Connecting to TCP server", @"Connecting to TCP server")
                     detailLabelText:nil
                   activityIndicator:YES];
        
        BOOL isConnectedToTCPServer = [self.connectionManager connectToControlHost:[FDDroneStatus currentStatus].pathForTCPConnection
                                                                              port:[FDDroneStatus currentStatus].portForTCPConnection];
        if (!isConnectedToTCPServer) {
            [self hideProgressHUD];
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
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)timerTick:(NSTimer *)timer {
    static NSUInteger tickCounter = 0;
    tickCounter++;
    
    if (![self.connectionManager isConnectedToControlHost]) {
        if (self.mapButton.enabled && ![self.presentedViewController isKindOfClass:[FDLocationInfoViewController class]]) {
            [self dismissPresentedPopoverAnimated:NO ignoredControllersFromClassesNamed:nil];
            [self performSegueWithIdentifier:@"ShowLocationInfo" sender:self.mapButton];
            self.hideMapAfterConnectionRestored = YES;
        }
        if ((tickCounter % 15 == 0)) {
            [self connectToServers];
        }
        return;
    }
    if (self.isHideMapAfterConnectionRestored) {
        self.hideMapAfterConnectionRestored = NO;
        [self dismissPresentedPopoverAnimated:YES ignoredControllersFromClassesNamed:nil];
    }

    self.lastConnectionTimeInterval = CACurrentMediaTime();
    
    if (tickCounter % 10 == 0) {
        [self.connectionManager sendDataToControlServer:[self.droneControlManager heartbeatData]];
    }
    
    CFTimeInterval delayHeartbeatMessageTimeInterval = CACurrentMediaTime() - self.lastReceivedHeartbeatMessageTimeInterval;
    if (delayHeartbeatMessageTimeInterval > 2.0f) {
        [self showProgressHUDWithTag:FDDashboardViewControllerHUDTagWaitingHeartbeat
                           labelText:NSLocalizedString(@"Waiting for heartbeat message", @"Waiting for heartbeat message")
                     detailLabelText:[NSString stringWithFormat:@"%.0f sec", delayHeartbeatMessageTimeInterval]
                   activityIndicator:YES];
        if (delayHeartbeatMessageTimeInterval > 3.0f) {
            self.enabledControls = NO;
            self.requestDataStreamsSent = NO;
        }
        return;
    }
    
    [self hideProgressHUDWithTag:FDDashboardViewControllerHUDTagWaitingHeartbeat];
    [self hideProgressHUDWithTag:FDDashboardViewControllerHUDTagConnectingToTCPServer];

    //send control data
    NSData *controlData = [self.droneControlManager messageDataWithPitch:self.rightJoystickView.stickVerticalValue
                                                                    roll:self.rightJoystickView.stickHorizontalValue
                                                                  thrust:self.leftJoystickView.stickVerticalValue
                                                                     yaw:self.leftJoystickView.stickHorizontalValue
                                                          sequenceNumber:1];
    [self.connectionManager sendDataToControlServer:controlData];
}

- (void)showProgressHUDWithTag:(NSUInteger)tag labelText:(NSString *)labelText detailLabelText:(NSString *)detailLabelText activityIndicator:(BOOL)activityIndicator {
    MBProgressHUD *progressHUD = self.currentProgressHUD;
    
    if (progressHUD.tag != tag) {
        [progressHUD hide:NO];
        progressHUD = nil;
    }
    
    if (progressHUD == nil) {
        progressHUD = [MBProgressHUD showHUDAddedTo:self.movieBackgroundView animated:NO];
        progressHUD.tag = tag;
        progressHUD.color = [UIColor colorWithRed:24.0f/255.0f green:43.0f/255.0f blue:72.0f/255.0f alpha:0.5f];
    } else {
        [NSObject cancelPreviousPerformRequestsWithTarget:progressHUD];
    }
    
    progressHUD.labelText = labelText;
    progressHUD.detailsLabelText = detailLabelText;
    progressHUD.mode = activityIndicator ? MBProgressHUDModeIndeterminate : MBProgressHUDModeText;
    self.currentProgressHUD = progressHUD;
}

- (void)hideProgressHUDWithTag:(NSUInteger)tag {
    if (self.currentProgressHUD.tag == tag) {
        [self.currentProgressHUD hide:NO];
        self.currentProgressHUD = nil;
    }
}

- (void)hideProgressHUDWithTag:(NSUInteger)tag afterDelay:(NSTimeInterval)delay {
    if (self.currentProgressHUD.tag == tag) {
        [self.currentProgressHUD hide:NO afterDelay:delay];
    }
}

- (void)hideProgressHUD {
    [self.currentProgressHUD hide:NO];
    self.currentProgressHUD = nil;
}

- (void)dismissPresentedPopoverAnimated:(BOOL)animated ignoredControllersFromClassesNamed:(NSArray *)ignoredClassesNamed {
    BOOL isNeedDismissController = YES;
    for (NSString *className in ignoredClassesNamed) {
        if ([self.presentedViewController isKindOfClass:NSClassFromString(className)]) {
            isNeedDismissController = NO;
            break;
        }
    }
    if (isNeedDismissController) {
        [self.presentedViewController dismissViewControllerAnimated:animated completion:nil];
    }
}

- (void)requestDataStreams {
    // Requests MAVLINK_MSG_ID_SYS_STATUS and MAVLINK_MSG_ID_GPS_RAW_INT messages
    [self.connectionManager sendDataToControlServer:[self.droneControlManager messageDataForRequestDataStream:MAV_DATA_STREAM_EXTENDED_STATUS start:YES]];
    // Request MAVLINK_MSG_ID_VFR_HUD messages
    [self.connectionManager sendDataToControlServer:[self.droneControlManager messageDataForRequestDataStream:MAV_DATA_STREAM_EXTRA2 start:YES]];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    //    [self back:nil];
}

#pragma mark - FDConnectionManagerDelegate

- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveVideoData:(NSData *)data {
    [self.movieDecoder parseAndDecodeInputData:data];
}

- (void)connectionManager:(FDConnectionManager *)connectionManager didReceiveControlData:(NSData *)data {
    if (data.length == 0) {
        return;
    }
    
    [self.droneControlManager parseInputData:data];
}

#pragma mark - FDMovieDecoderDelegate

- (void)movieDecoder:(FDMovieDecoder *)movieDecoder decodedVideoFrame:(AVFrame)videoFrame {
    if (movieDecoder.width > 0 && movieDecoder.height > 0
            && (_frameSize.width != movieDecoder.width || _frameSize.height != movieDecoder.height)) {
        _frameSize = CGSizeMake(movieDecoder.width, movieDecoder.height);
        [self.movieGLView frameSize:_frameSize];
    }
    [self.movieGLView renderVideoFrame:videoFrame];
}

#pragma mark - FDDroneControlManagerDelegate

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didParseMessage:(NSString *)messageDescription {
//    NSLog(@"%@", messageDescription);
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleLocationCoordinate:(CLLocationCoordinate2D)locationCoordinate {
    self.mapButton.enabled = CLLocationCoordinate2DIsValid(locationCoordinate);
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleBatteryRemaining:(CGFloat)batteryRemaining current:(CGFloat)current voltage:(CGFloat)voltage {
    self.batteryButton.batteryRemainingPercent = batteryRemaining;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleVFRInfoForHeading:(NSUInteger)heading altitude:(CGFloat)altitude airspeed:(CGFloat)airspeed groundspeed:(CGFloat)groundspeed climbRate:(CGFloat)climbRate throttleSetting:(CGFloat)throttleSetting {
    self.compassView.heading = heading;
    self.altitudeVerticalScaleView.value = altitude;
    self.altitudeVerticalScaleView.targetDelta = climbRate;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleHeartbeatInfo:(uint32_t)mavCustomMode mavType:(uint8_t)mavType mavAutopilotType:(uint8_t)mavAutopilotType mavBaseMode:(uint8_t)mavBaseMode mavSystemStatus:(uint8_t)mavSystemStatus {
    static BOOL firstHeartbeatMessage = YES;
    if (firstHeartbeatMessage && !(mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED)) {
        firstHeartbeatMessage = NO;
        [self.connectionManager sendDataToControlServer:[self.droneControlManager messageDataForParamRequestList]];
    }
    
    if (self.isRequestDataStreamsSent == NO) {
        self.requestDataStreamsSent = YES;
        [self requestDataStreams];
    }
    
    NSString *customModesButtonTitle = (mavBaseMode & (uint8_t)MAV_MODE_FLAG_CUSTOM_MODE_ENABLED) ? [NSString nameFromArducopterMode:mavCustomMode] : @"N/A";
    [self.customModesButton setTitle:customModesButtonTitle forState:UIControlStateNormal];
    if ([self.presentedViewController isKindOfClass:[FDOptionsListViewController class]]) {
        [(FDOptionsListViewController *)self.presentedViewController updateOptionsNames];
    }
    
    [self hideProgressHUDWithTag:FDDashboardViewControllerHUDTagWaitingHeartbeat];
    
    self.lastReceivedHeartbeatMessageTimeInterval = CACurrentMediaTime();
    self.enabledControls = YES;
}

- (void)droneControlManager:(FDDroneControlManager *)droneControlManager didHandleErrorMessage:(NSString *)errorText {
    if (self.currentProgressHUD.tag != FDDashboardViewControllerHUDTagWaitingHeartbeat) {
        [self showProgressHUDWithTag:FDDashboardViewControllerHUDTagWarning labelText:errorText detailLabelText:nil activityIndicator:NO];
        [self hideProgressHUDWithTag:FDDashboardViewControllerHUDTagWarning afterDelay:3.0];
    }
}

#pragma mark - FDOptionsListViewControllerDelegate

- (NSArray *)optionsNamesForOptionsListViewController:(FDOptionsListViewController *)optionsListViewController {
    NSArray *optionsNames;
    if ([optionsListViewController.identifier isEqualToString:FDDashboardViewControllerArmedStatusListIdentifier]) {
        optionsNames = self.armedModesOptionsNames;
    } else if ([optionsListViewController.identifier isEqualToString:FDDashboardViewControllerCustomModesListIdentifier]) {
        optionsNames = self.customModesOptionsNames;
    }
    return optionsNames;
}

- (void)optionsListViewController:(FDOptionsListViewController *)optionsListViewController didSelectOptionForIndex:(NSUInteger)optionIndex {
    NSData *optionMessageData;
    if ([optionsListViewController.identifier isEqualToString:FDDashboardViewControllerArmedStatusListIdentifier]) {
        NSArray *armedModesOptionsNames = self.armedModesOptionsNames;
        NSString *optionName = armedModesOptionsNames[optionIndex];
        if ([optionName isEqualToString:@"ARM"]) {
            optionMessageData = [self.droneControlManager messageDataWithArmedEnable:YES];
        } else if ([optionName isEqualToString:@"DISARM"]) {
            optionMessageData = [self.droneControlManager messageDataWithArmedEnable:NO];
        } else if ([optionName isEqualToString:@"Start Video"]) {
            optionMessageData = [self.droneControlManager messageDataWithCaptureSettingsFps:[FDDroneStatus currentStatus].videoFps
                                                                                 resolution:[FDDroneStatus currentStatus].videoResolution
                                                                                    bitrate:[FDDroneStatus currentStatus].videoBitrate];
        } else if ([optionName isEqualToString:@"Stop Video"]) {
            optionMessageData = [self.droneControlManager messageDataForCaptureDisableCommand];
        }
    } else if ([optionsListViewController.identifier isEqualToString:FDDashboardViewControllerCustomModesListIdentifier]) {
        NSArray *customModesOptionsNames = self.customModesOptionsNames;
        if (optionIndex >= customModesOptionsNames.count) {
            return;
        }
        enum ARDUCOPTER_MODE selectedMode = [NSString arducopterModeFromName:customModesOptionsNames[optionIndex]];
        optionMessageData = [self.droneControlManager messageDataWithNewCustomMode:selectedMode];
    }
    [self.connectionManager sendDataToControlServer:optionMessageData];
    [self dismissPresentedPopoverAnimated:YES ignoredControllersFromClassesNamed:nil];
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
    [self dismissPresentedPopoverAnimated:NO ignoredControllersFromClassesNamed:nil];
    return NO;
}

@end
