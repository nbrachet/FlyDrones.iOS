//
//  NSString+MAVLink.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/30/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "mavlink_types.h"

@interface NSString (MAVLink)

+ (NSString *)stringWithMAVLinkMessage:(mavlink_message_t *)msg;

@end
