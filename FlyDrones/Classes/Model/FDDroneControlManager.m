//
//  FDDroneControlManager.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/29/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDDroneControlManager.h"
#import "FDFileReader.h"
#import "NSString+MAVLink.h"

@interface FDDroneControlManager () {
    mavlink_message_t msg;
    mavlink_status_t status;
}

@end

@implementation FDDroneControlManager

#pragma mark - Public

- (void)parseLogFile:(NSString *)name ofType:(NSString *)type {
    if (name.length == 0) {
        return;
    }
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:name ofType:type];
    if (filePath.length == 0) {
        return;
    }
    
    FDFileReader *fileReader = [[FDFileReader alloc] initWithFilePath:filePath];
    [fileReader enumerateBytesUsingBlock:^(NSData *data, BOOL *stop) {
        if (data.length == 0) {
            *stop = YES;
            return;
        }
        
        const char *bytes = (const char *) [data bytes];
        if (mavlink_parse_char(MAVLINK_COMM_0, bytes[0], &msg, &status)) {
            NSLog(@"%@", [NSString stringWithMAVLinkMessage:&msg]);
//
//            switch (msg.msgid) {
//                case MAVLINK_MSG_ID_HEARTBEAT:
//                    NSLog(@"MAVLINK_MSG_ID_HEARTBEAT");
//                    break;
//                case MAVLINK_MSG_ID_RADIO_STATUS:
//                    NSLog(@"MAVLINK_MSG_ID_RADIO_STATUS");
//                    break;
//                case MAVLINK_MSG_ID_RADIO:
//                    NSLog(@"MAVLINK_MSG_ID_RADIO");
//                    break;
//                case MAVLINK_MSG_ID_STATUSTEXT:
//                    NSLog(@"MAVLINK_MSG_ID_STATUSTEXT");
//                    break;
//                case MAVLINK_MSG_ID_SYS_STATUS:
//                    NSLog(@"MAVLINK_MSG_ID_SYS_STATUS");
//                    break;
//                case MAVLINK_MSG_ID_BATTERY_STATUS:
//                    NSLog(@"MAVLINK_MSG_ID_BATTERY_STATUS");
//                    break;
//                default:
//                    NSLog(@"The msg id is %d (0x%x)", msg.msgid, msg.msgid);
//                break;
//            }
        }
    }];
}

@end
