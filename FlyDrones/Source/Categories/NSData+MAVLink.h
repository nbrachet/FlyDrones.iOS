//
//  NSData+MAVLink.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/14/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "mavlink_types.h"

@interface NSData (MAVLink)

+ (NSData *)dataWithMAVLinkMessage:(mavlink_message_t *)message;

@end
