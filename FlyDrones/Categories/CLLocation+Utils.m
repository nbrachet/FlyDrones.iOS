//
//  CLLocation+Utils.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 6/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "CLLocation+Utils.h"

@implementation CLLocation (Utils)

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate {
    return [self initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
}

@end
