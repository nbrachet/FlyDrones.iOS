//
//  FDLoginViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDLoginViewController.h"
#import "FDDashboardViewController.h"
#import "NSString+Network.h"
#import "NSFileManager+ANUtils.h"

//ffmpeg -re -i /Users/nab0y4enko/Library/Mobile\ Documents/com\~apple\~CloudDocs/2014-12-19.h264 -vcodec copy -f h264 -f rtp rtp://192.168.1.219:5555
//ffmpeg -re -i /Users/nab0y4enko/Library/Mobile\ Documents/com\~apple\~CloudDocs/2014-12-19.h264 -vcodec copy -f h264 -f h264 udp://192.168.0.100:5555

static NSString * const FDLoginViewControllerCustomNetworkPort = @"5555";

@interface FDLoginViewController ()

@property (nonatomic, weak) IBOutlet UITextField *customPathTextField;

@property (nonatomic, copy) NSString *rtpStreamPath;

@end

@implementation FDLoginViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.rtpStreamPath = [NSString stringWithFormat:@"udp://%@:%@", [NSString getIPAddress], FDLoginViewControllerCustomNetworkPort];
    self.customPathTextField.text = self.rtpStreamPath;
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
    NSString *pathToMovie = self.customPathTextField.text;
    FDDashboardViewController *dashboardViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"FDDashboardViewController"];
    dashboardViewController.path = pathToMovie;
    [self.navigationController pushViewController:dashboardViewController animated:YES];
}

@end
