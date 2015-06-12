//
//  FDOptionTableViewCell.h
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/28/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FDOptionTableViewCell : UITableViewCell

@property (nonatomic, copy) IBInspectable UIColor *selectedBackgroundColor;
@property (nonatomic, weak) IBOutlet UILabel *optionTextLabel;

@end
