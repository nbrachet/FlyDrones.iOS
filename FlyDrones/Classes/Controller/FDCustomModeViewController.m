//
//  FDCustomModeViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 5/28/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

#import "FDCustomModeViewController.h"
#import "FDOptionTableViewCell.h"
#import "FDDroneStatus.h"
#import "FDDroneControlManager.h"

@interface FDCustomModeViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSArray *modes;
@property (nonatomic, assign) FDAutoPilotMode prevMode;

@end

@implementation FDCustomModeViewController

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.prevMode = FDAutoPilotModeNA;
    [self reloadTable];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadTable)
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

#pragma mark - IBActions

#pragma mark - Private

- (void)reloadTable {
    FDAutoPilotMode currentMode = [FDDroneStatus currentStatus].mavCustomMode;
    if (self.prevMode == currentMode) {
        return;
    }
    
    self.prevMode = currentMode;
    NSMutableArray *modes = [@[[FDDroneStatus nameFromMode:FDAutoPilotModeStabilize],
                               [FDDroneStatus nameFromMode:FDAutoPilotModeAltHold],
                               [FDDroneStatus nameFromMode:FDAutoPilotModeLoiter],
                               [FDDroneStatus nameFromMode:FDAutoPilotModeRTL],
                               [FDDroneStatus nameFromMode:FDAutoPilotModeLand],
                               [FDDroneStatus nameFromMode:FDAutoPilotModeDrift],
                               [FDDroneStatus nameFromMode:FDAutoPilotModePoshold]] mutableCopy];
    NSString *currentModeName = [FDDroneStatus nameFromMode:currentMode];
    if ([modes containsObject:currentModeName]) {
        [modes removeObject:currentModeName];
    }
    self.modes = [modes copy];
    [self.tableView reloadData];
}

- (void)changeModeTo:(FDAutoPilotMode)mode {
    if (self.delegate == nil) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(didSelectNewMode:)]) {
        [self.delegate didSelectNewMode:mode];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.modes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ModeOptionCellIdentifier";
    
    FDOptionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    cell.optionTextLabel.text = self.modes[indexPath.row];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView  willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = [UIColor clearColor];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    FDOptionTableViewCell *cell = (FDOptionTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    NSString *name = cell.optionTextLabel.text;
    [self changeModeTo:[FDDroneStatus modeFromName:name]];
}

@end
