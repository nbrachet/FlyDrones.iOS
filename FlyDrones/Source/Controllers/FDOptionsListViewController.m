//
//  FDOptionsListViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 7/23/15.
//  Copyright (c) 2015 QArea. All rights reserved.
//

#import "FDOptionsListViewController.h"
#import "FDOptionTableViewCell.h"

@interface FDOptionsListViewController ()

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *tableViewTopLayoutConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *tableViewBottomLayoutConstraint;

@end

@implementation FDOptionsListViewController

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    
    [self updateOptionsNames];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Public

- (void)updateOptionsNames {
    NSArray *optionsNames;
    if ([self.delegate respondsToSelector:@selector(optionsNamesForOptionsListViewController:)]) {
        optionsNames = [self.delegate optionsNamesForOptionsListViewController:self];
    }
    
    if ([self.optionsNames isEqualToArray:optionsNames]) {
        return;
    }
    
    self.optionsNames = optionsNames;
    [self.tableView reloadData];
    self.preferredContentSize = CGSizeMake(self.preferredContentSize.width,
                                           self.tableView.contentSize.height + self.tableViewTopLayoutConstraint.constant + self.tableViewBottomLayoutConstraint.constant);
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.optionsNames.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"OptionTableViewCellIdentifier";
    
    FDOptionTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    cell.optionTextLabel.text = self.optionsNames[indexPath.row];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView  willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = [UIColor clearColor];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if ([self.delegate respondsToSelector:@selector(optionsListViewController:didSelectOptionForIndex:)]) {
        [self.delegate optionsListViewController:self didSelectOptionForIndex:indexPath.row];
    }
}

@end
