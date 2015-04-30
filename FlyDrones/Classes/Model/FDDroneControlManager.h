//
//  FDDroneControlManager.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/29/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDDroneControlManager : NSObject

- (void)parseLogFile:(NSString *)name ofType:(NSString *)type;

@end
