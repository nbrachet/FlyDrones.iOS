//
//  FDOptionTableViewCell.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/28/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDOptionTableViewCell.h"

@implementation FDOptionTableViewCell

- (void)awakeFromNib {
    self.backgroundView = nil;
    
    UIView *selectedBackgroundView = [[UIView alloc] init];
    selectedBackgroundView.backgroundColor = self.selectedBackgroundColor;
    [self setSelectedBackgroundView:selectedBackgroundView];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
