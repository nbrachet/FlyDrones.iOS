//
//  main.m
//  FlyDrones
//
//  Created by Sergey Galagan on 1/27/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "AppDelegate.h"

CFAbsoluteTime StartTime;

int main(int argc, char * argv[])
{
    StartTime = CFAbsoluteTimeGetCurrent();
    
    @autoreleasepool
    {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
