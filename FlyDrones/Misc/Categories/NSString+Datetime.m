//
//  NSString+Datetime.m
//  FlyDrones
//
//  Created by Sergey Galagan on 3/11/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "NSString+Datetime.h"


#pragma mark - Static

static NSString * const kFDDateFormatString = @"MMM dd, yyyy EEEE";
static NSString * const kFDTimeFormatString = @"HH:mm:ss";


#pragma mark - Public methods

@implementation NSString (Datetime)

#pragma mark - Date/time methods

+ (NSString *)currentDate
{
    NSDate *date = [NSDate date];
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:kFDDateFormatString];
    return [format stringFromDate:date];
}

+ (NSString *)currentTime
{
    NSDate *date = [NSDate date];
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:kFDTimeFormatString];
    return [format stringFromDate:date];
}

#pragma mark -

@end