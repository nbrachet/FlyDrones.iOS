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
//static NSString * const FDConnectionSettingsViewControllerCustomUDPHost = @"192.168.0.102";
//static NSString * const FDConnectionSettingsViewControllerCustomUDPHost = @"108.26.177.27";
static NSString * const UDPHostKey = @"UDPHostKey";

static NSString * const FDConnectionSettingsViewControllerCustomUDPPort = @"5556";
static NSString * const UDPPortKey = @"UDPPortKey";

static NSString * const FDConnectionSettingsViewControllerCustomTCPHost = @"192.168.1.58";
//static NSString * const FDConnectionSettingsViewControllerCustomTCPHost = @"192.168.0.102";
static NSString * const TCPHostKey = @"TCPHostKey";

static NSString * const FDConnectionSettingsViewControllerCustomTCPPort = @"5555";
static NSString * const TCPPortKey = @"TCPPortKey";

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
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier isEqualToString:@"ShowDashboard"]) {

        NSString *hostForUDPConnection = self.hostForConnectionTextField.text;
        NSString *portForUDPConnection = self.portForConnectionTextField.text;
        NSString *hostForTCPConnection = self.hostForTCPConnectionTextField.text;
        NSString *portForTCPConnection = self.portForTCPConnectionTextField.text;
        
        if (hostForUDPConnection.length == 0 || portForUDPConnection <= 0 || hostForTCPConnection.length == 0 || portForTCPConnection <= 0) {
            [[[UIAlertView alloc] initWithTitle:@"Warning" message:@"Please fill all fields correctly" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            return NO;
        }
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:hostForUDPConnection forKey:UDPHostKey];
        [userDefaults setObject:portForUDPConnection forKey:UDPPortKey];
        [userDefaults setObject:hostForTCPConnection forKey:TCPHostKey];
        [userDefaults setObject:portForTCPConnection forKey:TCPPortKey];

        FDDroneStatus *currentDroneStatus = [FDDroneStatus currentStatus];
        currentDroneStatus.pathForUDPConnection = hostForUDPConnection;
        currentDroneStatus.portForUDPConnection = [portForUDPConnection integerValue];
        currentDroneStatus.pathForTCPConnection = hostForTCPConnection;
        currentDroneStatus.portForTCPConnection = [portForTCPConnection integerValue];
    }
    return YES;
}

@end
