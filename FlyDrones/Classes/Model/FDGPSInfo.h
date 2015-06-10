//
//  FDGPSInfo.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 6/9/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDGPSInfo : NSObject

@property (nonatomic, assign) CLLocationCoordinate2D locationCoordinate;
@property (nonatomic, assign) NSUInteger fixType;
@property (nonatomic, assign) NSUInteger satelliteCount;
@property (nonatomic, assign) CGFloat hdop;   //Horizontal Dilution of Precision

@end
