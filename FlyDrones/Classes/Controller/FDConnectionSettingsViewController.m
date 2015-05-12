//
//  FDConnectionSettingsViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/8/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDConnectionSettingsViewController.h"
#import "FDDroneStatus.h"

static NSString * const FDConnectionSettingsViewControllerCustomUDPHost = @"192.168.1.58";
static NSString * const FDConnectionSettingsViewControllerCustomTCPHost = @"192.168.1.58";
//static NSString * const FDConnectionSettingsViewControllerCustomUDPHost = @"192.168.0.103";
//static NSString * const FDConnectionSettingsViewControllerCustomTCPHost = @"192.168.0.103";
//static NSString * const FDLoginViewControllerCustomNetworkHost = @"108.26.177.27";

static NSString * const FDConnectionSettingsViewControllerCustomUDPPort = @"5556";
static NSString * const FDConnectionSettingsViewControllerCustomTCPPort = @"5555";

@interface FDConnectionSettingsViewController ()

@property (nonatomic, weak) IBOutlet UITextField *hostForConnectionTextField;
@property (nonatomic, weak) IBOutlet UITextField *portForConnectionTextField;

@property (nonatomic, weak) IBOutlet UITextField *hostForTCPConnectionTextField;
@property (nonatomic, weak) IBOutlet UITextField *portForTCPConnectionTextField;

@end

@implementation FDConnectionSettingsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.hostForConnectionTextField.text = FDConnectionSettingsViewControllerCustomUDPHost;
    self.portForConnectionTextField.text = FDConnectionSettingsViewControllerCustomUDPPort;
    
    self.hostForTCPConnectionTextField.text = FDConnectionSettingsViewControllerCustomTCPHost;
    self.portForTCPConnectionTextField.text = FDConnectionSettingsViewControllerCustomTCPPort;
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier isEqualToString:@"ShowDashboard"]) {

        NSString *hostForUDPConnection = self.hostForConnectionTextField.text;
        NSUInteger portForUDPConnection = [self.portForConnectionTextField.text integerValue];
        NSString *hostForTCPConnection = self.hostForTCPConnectionTextField.text;
        NSUInteger portForTCPConnection = [self.portForTCPConnectionTextField.text integerValue];
        
        if (hostForUDPConnection.length == 0 || portForUDPConnection <= 0 || hostForTCPConnection.length == 0 || portForTCPConnection <= 0) {
            [[[UIAlertView alloc] initWithTitle:@"Warning" message:@"Please fill all fields correctly" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            return NO;
        }
        
        FDDroneStatus *currentDroneStatus = [FDDroneStatus currentStatus];
        currentDroneStatus.pathForUDPConnection = hostForUDPConnection;
        currentDroneStatus.portForUDPConnection = portForUDPConnection;
        currentDroneStatus.pathForTCPConnection = hostForTCPConnection;
        currentDroneStatus.portForTCPConnection = portForTCPConnection;
    }
    return YES;
}

@end
