//
//  NSString+MAVLink.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/30/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "NSString+MAVLink.h"
#import "mavlink_types.h"

static const mavlink_message_info_t message_info[256] = MAVLINK_MESSAGE_INFO;

@interface NSString ()

static NSString* primitiveFieldToNSString(mavlink_message_t *, const mavlink_field_info_t *, int);
static NSString* fieldToNSString(mavlink_message_t *, const mavlink_field_info_t *);

@end

@implementation NSString (MAVLink)

#pragma mark - Public

+ (NSString *)stringWithMAVLinkMessage:(mavlink_message_t *)message {
    const mavlink_message_info_t *messageInfo = &message_info[message->msgid];
    const mavlink_field_info_t *fields = messageInfo->fields;
    NSMutableString *string = [NSMutableString stringWithFormat:@"SEQ: %hhu %s { ", message->seq, messageInfo->name];
    for (NSUInteger i = 0; i < messageInfo->num_fields; i++) {
        [string appendFormat:@"%@ ", fieldToNSString(message, &fields[i])];
    }
    [string appendString:@" }"];
    return [string copy];
}

#pragma mark - Private

static NSString* fieldToNSString(mavlink_message_t *message, const mavlink_field_info_t *field) {
    NSMutableString *string = [NSMutableString stringWithFormat:@"%s: ", field->name];
    if (field->array_length == 0) {
        [string appendFormat:@"%@ ", primitiveFieldToNSString(message, field, 0)];
    } else {
        unsigned i;
        /* print an array */
        if (field->type == MAVLINK_TYPE_CHAR) {
            [string appendFormat:@"'%.*s'", field->array_length, field->wire_offset+(const char *)_MAV_PAYLOAD(message)];
        } else {
            [string appendString:@"[ "];
            for (i=0; i < field->array_length; i++) {
                [string appendString:primitiveFieldToNSString(message, field, i)];
                if (i < field->array_length) {
                    [string appendString:@", "];
                }
            }
            [string appendString:@"]"];
        }
    }
    return [string copy];
}

static NSString* primitiveFieldToNSString(mavlink_message_t *message, const mavlink_field_info_t *field, int index) {
    switch (field->type) {
        case MAVLINK_TYPE_CHAR:
            return [NSString stringWithFormat:@"%c", _MAV_RETURN_char(message, field->wire_offset+index*1)];
            break;
        case MAVLINK_TYPE_UINT8_T:
            return [NSString stringWithFormat:@"%u", _MAV_RETURN_uint8_t(message, field->wire_offset+index*1)];
            break;
        case MAVLINK_TYPE_INT8_T:
            return [NSString stringWithFormat:@"%d", _MAV_RETURN_int8_t(message, field->wire_offset+index*1)];
            break;
        case MAVLINK_TYPE_UINT16_T:
            return [NSString stringWithFormat:@"%u", _MAV_RETURN_uint16_t(message, field->wire_offset+index*2)];
            break;
        case MAVLINK_TYPE_INT16_T:
            return [NSString stringWithFormat:@"%d", _MAV_RETURN_int16_t(message, field->wire_offset+index*2)];
            break;
        case MAVLINK_TYPE_UINT32_T:
            return [NSString stringWithFormat:@"%lu", (unsigned long)_MAV_RETURN_uint32_t(message, field->wire_offset+index*4)];
            break;
        case MAVLINK_TYPE_INT32_T:
            return [NSString stringWithFormat:@"%ld", (long)_MAV_RETURN_int32_t(message, field->wire_offset+index*4)];
            break;
        case MAVLINK_TYPE_UINT64_T:
            return [NSString stringWithFormat:@"%llu", (unsigned long long)_MAV_RETURN_uint64_t(message, field->wire_offset+index*8)];
            break;
        case MAVLINK_TYPE_INT64_T:
            return [NSString stringWithFormat:@"%lld", (long long)_MAV_RETURN_int64_t(message, field->wire_offset+index*8)];
            break;
        case MAVLINK_TYPE_FLOAT:
            return [NSString stringWithFormat:@"%f", (double)_MAV_RETURN_float(message, field->wire_offset+index*4)];
            break;
        case MAVLINK_TYPE_DOUBLE:
            return [NSString stringWithFormat:@"%f", _MAV_RETURN_double(message, field->wire_offset+index*8)];
            break;
    }
    return @"";
}


@end
