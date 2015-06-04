//
//  FDEnableArmedViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/28/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDEnableArmedViewController.h"
#import "FDOptionTableViewCell.h"
#import "FDDroneStatus.h"
#import "FDDroneControlManager.h"
#import "mavlink.h"

@interface FDEnableArmedViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, assign) BOOL prevArmedStatus;
@end

@implementation FDEnableArmedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.prevArmedStatus = !([FDDroneStatus currentStatus].mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED);
    [self reloadOptions];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadOptions)
                                                 name:FDDroneControlManagerDidHandleSystemInfoNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private

- (void)reloadOptions {
    BOOL isCurrentArmed = ([FDDroneStatus currentStatus].mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED);
    if (self.prevArmedStatus == isCurrentArmed) {
        return;
    }
    self.prevArmedStatus = isCurrentArmed;
    
    [self.tableView reloadData];
}

- (void)enableArmedStatus:(BOOL)armed {
    if (self.delegate == nil) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(didEnableArmedStatus:)]) {
        [self.delegate didEnableArmedStatus:armed];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ArmedOptionCellIdentifier";
    
    FDOptionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    cell.optionTextLabel.text = ([FDDroneStatus currentStatus].mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED) ? @"DISARMED" : @"ARMED";
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    [self enableArmedStatus:!([FDDroneStatus currentStatus].mavBaseMode & (uint8_t)MAV_MODE_FLAG_SAFETY_ARMED)];
}

@end
