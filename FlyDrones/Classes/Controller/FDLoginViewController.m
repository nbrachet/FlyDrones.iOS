//
//  FDLoginViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDLoginViewController.h"
#import "FDDashboardViewController.h"

@interface FDLoginViewController ()

@end

@implementation FDLoginViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBActions

- (IBAction)letsFly:(id)sender {
    NSString *pathToFile = [[NSBundle mainBundle] pathForResource:@"2014-12-19" ofType:@"h264"];
    FDDashboardViewController *dashboardViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"FDDashboardViewController"];
    dashboardViewController.path = pathToFile;
    [self.navigationController pushViewController:dashboardViewController animated:YES];
}

@end
