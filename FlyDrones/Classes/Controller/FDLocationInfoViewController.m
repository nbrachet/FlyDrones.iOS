//
//  FDLocationInfoViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/11/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDLocationInfoViewController.h"
#import "FDDroneControlManager.h"

@implementation FDLocationInfoViewController

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.mapView.mapType = MKMapTypeSatellite;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshInfo:)
                                                 name:FDDroneControlManagerDidHandleLocationCoordinateNotification
                                               object:nil];
    [self refreshInfo:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private

- (void)refreshInfo:(NSNotification *)notification {
    
    CLLocationCoordinate2D locationCoordinate = [FDDroneStatus currentStatus].locationCoordinate;
    if (!CLLocationCoordinate2DIsValid(locationCoordinate)) {
        return;
    }
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(locationCoordinate, 160, 160);
    [self.mapView setRegion:region animated:NO];
}

@end
