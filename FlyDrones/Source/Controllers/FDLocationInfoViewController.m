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

#import <MapKit/MapKit.h>

@interface FDLocationInfoViewController () <MKMapViewDelegate>

@property (nonatomic, assign) CLLocationCoordinate2D prevRegionLocationCoordinate;

@end

@implementation FDLocationInfoViewController

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.mapBackgroundView addSubview:[self mapView]];
    [self mapView].delegate = self;
    
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

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[self mapView] removeFromSuperview];
    [self mapView].delegate = nil;
}

#pragma mark - Private

- (MKMapView *)mapView {
    static MKMapView *mapView = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mapView = [[MKMapView alloc] initWithFrame:self.mapBackgroundView.bounds];
        mapView.mapType = MKMapTypeSatellite;
        mapView.showsPointsOfInterest = NO;
        mapView.pitchEnabled = NO;
        mapView.zoomEnabled = NO;
        mapView.scrollEnabled = NO;
        mapView.rotateEnabled = NO;
        mapView.showsUserLocation = NO;
    });
    return mapView;
}

- (void)refreshInfo:(NSNotification *)notification {
    FDGPSInfo *gpsInfo = [FDDroneStatus currentStatus].gpsInfo;
    CLLocationCoordinate2D locationCoordinate = gpsInfo.locationCoordinate;

    if (!CLLocationCoordinate2DIsValid(locationCoordinate) || gpsInfo.fixType < 1) {
        [self.mapView removeAnnotations:self.mapView.annotations];
        self.satelliteInfoLabel.text = @"N/A";
        return;
    }

    self.satelliteInfoLabel.text = [NSString stringWithFormat:@"%0.6f,%0.6f ±%0.1f (%lu)", gpsInfo.locationCoordinate.latitude, gpsInfo.locationCoordinate.longitude, gpsInfo.hdop, (unsigned long)gpsInfo.satelliteCount];
    
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:locationCoordinate];
    CLLocation *prevLocation = [[CLLocation alloc] initWithCoordinate:self.prevRegionLocationCoordinate];
    CLLocationDistance distance = [location distanceFromLocation:prevLocation];
    if (distance > 10) {
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(locationCoordinate, 160, 160);
        [self.mapView setRegion:region animated:NO];
        self.prevRegionLocationCoordinate = locationCoordinate;
    }

    if (distance > 1) {
        [self.mapView removeAnnotations:self.mapView.annotations];
        if (gpsInfo.fixType != 1) {
            MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
            annotation.coordinate = locationCoordinate;
            [self.mapView addAnnotation:annotation];
        }
    }
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
        annotationView.image = [UIImage imageNamed:@"Helicopter"];
    }
    
    annotationView.annotation = annotation;
    
    return annotationView;
}

@end
