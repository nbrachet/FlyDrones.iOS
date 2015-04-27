//
//  NSString+Network.m
//  FlyDrones
//
//  Created by Sergey Galagan on 2/13/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "NSString+Network.h"
#import "ifaddrs.h"
#import "arpa/inet.h"


@implementation NSString (Network)

+ (NSString *)getIPAddress {
    NSString *address;
    struct ifaddrs *interfaces = nil;

    if (!getifaddrs(&interfaces)) {
        for (struct ifaddrs *addr = interfaces; addr != NULL; addr = addr->ifa_next) {
            if (([[NSString stringWithUTF8String:addr->ifa_name] isEqualToString:@"en0"]) && (addr->ifa_addr->sa_family == AF_INET)) {
                struct sockaddr_in *sa = (struct sockaddr_in *) addr->ifa_addr;
                address = [NSString stringWithUTF8String:inet_ntoa(sa->sin_addr)];
                break;
            }
        }
    }
    freeifaddrs(interfaces);

    return address;
}

@end
