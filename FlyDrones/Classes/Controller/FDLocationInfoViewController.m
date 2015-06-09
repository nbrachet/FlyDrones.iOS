//
//  FDLocationInfoViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/11/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDLocationInfoViewController.h"
#import "FDDroneControlManager.h"
#import "CLLocation+Utils.h"

@interface FDLocationInfoViewController ()

@property (nonatomic, assign) CLLocationCoordinate2D prevRegionLocationCoordinate;

@end

@implementation FDLocationInfoViewController

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
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
    FDGPSInfo *gpsInfo = [FDDroneStatus currentStatus].gpsInfo;
    CLLocationCoordinate2D locationCoordinate = gpsInfo.locationCoordinate;
    
    if (!CLLocationCoordinate2DIsValid(locationCoordinate)) {
        return;
    }
    
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:locationCoordinate];
    CLLocation *prevLocation = [[CLLocation alloc] initWithCoordinate:self.prevRegionLocationCoordinate];
    CLLocationDistance distance = [location distanceFromLocation:prevLocation];
    if (distance > 100) {
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(locationCoordinate, 160, 160);
        [self.mapView setRegion:region animated:NO];
        self.prevRegionLocationCoordinate = locationCoordinate;
    }
    if (distance > 1) {
        [self.mapView removeAnnotations:self.mapView.annotations];
        MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
        annotation.coordinate = locationCoordinate;
        [self.mapView addAnnotation:annotation];
    }
    
    NSString *satelliteInfoString;
    if (gpsInfo.fixType <= 2) {
        satelliteInfoString = @"N/A";
    } else {
        satelliteInfoString = [NSString stringWithFormat:@"Satellites:%lu HDOP:%ld", (unsigned long)gpsInfo.satelliteCount, (long)gpsInfo.hdop];
    }
    self.satelliteInfoLabel.text = satelliteInfoString;
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    
    static NSString *AnnotationViewIdentifier = @"annotationViewID";
    MKAnnotationView *annotationView = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:AnnotationViewIdentifier];
    if (annotationView == nil) {
        annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AnnotationViewIdentifier];
    }
    
    annotationView.image = [UIImage imageNamed:@"Helicopter"];
    annotationView.annotation = annotation;
    
    return annotationView;
}

@end
