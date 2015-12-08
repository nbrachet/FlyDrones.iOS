//
//  AppDelegate.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 6/4/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import "AppDelegate.h"
#import "FDLoginViewController.h"

#import <Parse/Parse.h>
#import <ParseCrashReporting/ParseCrashReporting.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    NSLog(@"Calling Application Bundle ID: %@", sourceApplication);
    NSLog(@"URL:%@", url);

    [self setupParseWithOptions:nil];

    self.token = [url host];

#if 0
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSArray<NSURLQueryItem *> *queryItems = [components queryItems];
    for (NSURLQueryItem *item in queryItems) {
        if ([item.name isEqualToString:@"token"])
            self.token = item.value;
    }
#endif

    if ([self.window.rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
        for (UIViewController *viewController in navigationController.viewControllers) {
            if ([viewController isKindOfClass:FDLoginViewController.class]) {
                [navigationController popToViewController:viewController animated:YES];
                break;
            }
        }
//        [navigationController popToRootViewControllerAnimated:YES];
    }

    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self setupParseWithOptions:launchOptions];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Parse

- (void)setupParseWithOptions:(NSDictionary *)launchOptions {
    [ParseCrashReporting enable];
    [Parse setApplicationId:ParseApplicationID clientKey:ParseClientKey];
    [Parse setLogLevel:PFLogLevelDebug];
    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
    NSLog(@"ParseCrashReporting: %@", [ParseCrashReporting isCrashReportingEnabled] ? @"enabled" : @"disabled");
}

@end
