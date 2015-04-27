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
#import "NSFileManager+ANUtils.h"

static NSString * const FDLoginViewControllerCustomNetworkHost = @"192.168.1.80";
static NSString * const FDLoginViewControllerCustomNetworkPort = @"5555";

@interface FDLoginViewController ()

@property (nonatomic, weak) IBOutlet UITextField *hostForConnectionTextField;
@property (nonatomic, weak) IBOutlet UITextField *portForConnectionTextField;
@property (nonatomic, weak) IBOutlet UITextField *portForReceivedTextField;

@end

@implementation FDLoginViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.hostForConnectionTextField.text = FDLoginViewControllerCustomNetworkHost;
    self.portForConnectionTextField.text = FDLoginViewControllerCustomNetworkPort;
    self.portForReceivedTextField.text = FDLoginViewControllerCustomNetworkPort;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBActions

- (IBAction)letsFly:(id)sender {
    NSString *hostForConnection = self.hostForConnectionTextField.text;
    NSUInteger portForConnection = [self.portForConnectionTextField.text integerValue];
    NSUInteger portForReceived = [self.portForReceivedTextField.text integerValue];
    
    if (hostForConnection.length == 0 || portForConnection <= 0 || portForReceived <= 0) {
        [[[UIAlertView alloc] initWithTitle:@"Warning" message:@"Please fill all fields correctly" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        return;
    }
    
    FDDashboardViewController *dashboardViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"FDDashboardViewController"];
    dashboardViewController.hostForConnection = hostForConnection;
    dashboardViewController.portForConnection = portForConnection;
    dashboardViewController.portForReceived = portForReceived;
    [self.navigationController pushViewController:dashboardViewController animated:YES];
}

@end
