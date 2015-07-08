//
//  FDConnectionSettingsViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDConnectionSettingsViewController.h"
#import "FDDroneStatus.h"

static NSString * const FDConnectionSettingsViewControllerCustomUDPHost = @"192.168.1.80";
static NSString * const UDPHostKey = @"UDPHostKey";

static NSString * const FDConnectionSettingsViewControllerCustomUDPPort = @"5556";
static NSString * const UDPPortKey = @"UDPPortKey";

static NSString * const FDConnectionSettingsViewControllerCustomTCPHost = @"192.168.1.80";
static NSString * const TCPHostKey = @"TCPHostKey";

static NSString * const FDConnectionSettingsViewControllerCustomTCPPort = @"5555";
static NSString * const TCPPortKey = @"TCPPortKey";

static NSString * const ResolutionWKey = @"ResolutionWKey";
static NSString * const ResolutionHKey = @"ResolutionHKey";
static NSString * const FPSKey = @"FPSKey";
static NSString * const BitrateKey = @"BitRateKey";

@interface FDConnectionSettingsViewController ()

@property (nonatomic, weak) IBOutlet UITextField *hostForConnectionTextField;
@property (nonatomic, weak) IBOutlet UITextField *portForConnectionTextField;

@property (nonatomic, weak) IBOutlet UITextField *hostForTCPConnectionTextField;
@property (nonatomic, weak) IBOutlet UITextField *portForTCPConnectionTextField;

@property (nonatomic, weak) IBOutlet UITextField *resolutionWTextField;
@property (nonatomic, weak) IBOutlet UITextField *resolutionHTextField;
@property (nonatomic, weak) IBOutlet UITextField *fpsTextField;
@property (nonatomic, weak) IBOutlet UITextField *bitrateTextField;

@end

@implementation FDConnectionSettingsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults objectForKey:UDPHostKey]) {
        self.hostForConnectionTextField.text = [userDefaults objectForKey:UDPHostKey];
    } else {
        self.hostForConnectionTextField.text = FDConnectionSettingsViewControllerCustomUDPHost;
    }
    
    if ([userDefaults objectForKey:UDPPortKey]) {
        self.portForConnectionTextField.text = [userDefaults objectForKey:UDPPortKey];
    } else {
        self.portForConnectionTextField.text = FDConnectionSettingsViewControllerCustomUDPPort;
    }
    
    if ([userDefaults objectForKey:TCPHostKey]) {
        self.hostForTCPConnectionTextField.text = [userDefaults objectForKey:TCPHostKey];
    } else {
        self.hostForTCPConnectionTextField.text = FDConnectionSettingsViewControllerCustomTCPHost;
    }
    
    if ([userDefaults objectForKey:TCPPortKey]) {
        self.portForTCPConnectionTextField.text = [userDefaults objectForKey:TCPPortKey];
    } else {
        self.portForTCPConnectionTextField.text = FDConnectionSettingsViewControllerCustomTCPPort;
    }
    
    if ([userDefaults objectForKey:ResolutionWKey]) {
        self.resolutionWTextField.text = [userDefaults objectForKey:ResolutionWKey];
    } else {
        self.resolutionWTextField.text = [NSString stringWithFormat:@"%d", (int)kDefaultVideoSize.width];
    }
    
    if ([userDefaults objectForKey:ResolutionHKey]) {
        self.resolutionHTextField.text = [userDefaults objectForKey:ResolutionHKey];
    } else {
        self.resolutionHTextField.text = [NSString stringWithFormat:@"%d", (int)kDefaultVideoSize.height];
    }
    
    if ([userDefaults objectForKey:FPSKey]) {
        self.fpsTextField.text = [userDefaults objectForKey:FPSKey];
    } else {
        self.fpsTextField.text = [NSString stringWithFormat:@"%d", (int)kDefaultVideoFps];
    }
    
    if ([userDefaults objectForKey:BitrateKey]) {
        self.bitrateTextField.text = [userDefaults objectForKey:BitrateKey];
    } else {
        self.bitrateTextField.text = @"0";
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier isEqualToString:@"ShowDashboard"]) {

        NSString *hostForUDPConnection = self.hostForConnectionTextField.text;
        NSString *portForUDPConnection = self.portForConnectionTextField.text;
        NSString *hostForTCPConnection = self.hostForTCPConnectionTextField.text;
        NSString *portForTCPConnection = self.portForTCPConnectionTextField.text;
        NSString *resolutionW = self.resolutionWTextField.text;
        NSString *resolutionH = self.resolutionHTextField.text;
        NSString *fps = self.fpsTextField.text;
        NSString *bitrate = self.bitrateTextField.text;
        
        if (hostForUDPConnection.length == 0 ||
            portForUDPConnection.length == 0 ||
            hostForTCPConnection.length == 0 ||
            portForTCPConnection.length == 0 ||
            resolutionH.length == 0 ||
            resolutionW.length == 0 ||
            fps.length == 0 ||
            bitrate.length == 0) {
            [[[UIAlertView alloc] initWithTitle:@"Warning" message:@"Please fill all fields correctly" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            return NO;
        }
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:hostForUDPConnection forKey:UDPHostKey];
        [userDefaults setObject:portForUDPConnection forKey:UDPPortKey];
        [userDefaults setObject:hostForTCPConnection forKey:TCPHostKey];
        [userDefaults setObject:portForTCPConnection forKey:TCPPortKey];

        [userDefaults setObject:resolutionW forKey:ResolutionWKey];
        [userDefaults setObject:resolutionH forKey:ResolutionHKey];
        [userDefaults setObject:fps forKey:FPSKey];
        [userDefaults setObject:bitrate forKey:BitrateKey];
        
        FDDroneStatus *currentDroneStatus = [FDDroneStatus currentStatus];
        currentDroneStatus.pathForUDPConnection = hostForUDPConnection;
        currentDroneStatus.portForUDPConnection = [portForUDPConnection integerValue];
        currentDroneStatus.pathForTCPConnection = hostForTCPConnection;
        currentDroneStatus.portForTCPConnection = [portForTCPConnection integerValue];
        
        currentDroneStatus.videoSize = CGSizeMake([resolutionW integerValue], [resolutionH integerValue]);
        currentDroneStatus.videoFps = [fps integerValue];
        currentDroneStatus.videoResolution = currentDroneStatus.videoSize.width * currentDroneStatus.videoSize.height / 1000.0f / 1000.0f;
        currentDroneStatus.videoBitrate = [bitrate floatValue];
    }
    return YES;
}

@end
