//
//  FDLoginViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDLoginViewController.h"
#import "FDDashboardViewController.h"
#import "NSString+Network.h"

static NSString * const FDLoginViewControllerCustomNetworkHost = @"192.168.1.80";
//static NSString * const FDLoginViewControllerCustomNetworkHost = @"108.26.177.27";

static NSString * const FDLoginViewControllerCustomNetworkPort = @"5556";

static NSString * const FDLoginViewControllerCustomTCPNetworkPort = @"5555";

@interface FDLoginViewController ()

@property (nonatomic, weak) IBOutlet UITextField *hostForConnectionTextField;
@property (nonatomic, weak) IBOutlet UITextField *portForConnectionTextField;

@property (nonatomic, weak) IBOutlet UITextField *hostForTCPConnectionTextField;
@property (nonatomic, weak) IBOutlet UITextField *portForTCPConnectionTextField;

@end

@implementation FDLoginViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.hostForConnectionTextField.text = FDLoginViewControllerCustomNetworkHost;
    self.portForConnectionTextField.text = FDLoginViewControllerCustomNetworkPort;
    
    self.hostForTCPConnectionTextField.text = FDLoginViewControllerCustomNetworkHost;
    self.portForTCPConnectionTextField.text = FDLoginViewControllerCustomTCPNetworkPort;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - IBActions

- (IBAction)letsFly:(id)sender {
    NSString *hostForConnection = self.hostForConnectionTextField.text;
    NSUInteger portForConnection = [self.portForConnectionTextField.text integerValue];
    NSString *hostForTCPConnection = self.hostForTCPConnectionTextField.text;
    NSUInteger portForTCPConnection = [self.portForTCPConnectionTextField.text integerValue];
    
    if (hostForConnection.length == 0 || portForConnection <= 0 || hostForTCPConnection.length == 0 || portForTCPConnection <= 0) {
        [[[UIAlertView alloc] initWithTitle:@"Warning" message:@"Please fill all fields correctly" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        return;
    }
    
    FDDashboardViewController *dashboardViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"FDDashboardViewController"];
    dashboardViewController.hostForConnection = hostForConnection;
    dashboardViewController.portForConnection = portForConnection;
    dashboardViewController.portForReceived = portForConnection;
    dashboardViewController.hostForTCPConnection = hostForTCPConnection;
    dashboardViewController.portForTCPConnection = portForTCPConnection;
    [self.navigationController pushViewController:dashboardViewController animated:YES];
}

@end
