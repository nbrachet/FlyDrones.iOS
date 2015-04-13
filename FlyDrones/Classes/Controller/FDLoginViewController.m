//
//  FDLoginViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Sergey Galagan. All rights reserved.
//

#import "FDLoginViewController.h"
#import "FDDashboardViewController.h"
#import "NSString+Network.h"
#import "NSFileManager+ANUtils.h"

//ffmpeg -re -i /Users/nab0y4enko/Library/Mobile\ Documents/com\~apple\~CloudDocs/2014-12-19.h264 -vcodec copy -f h264 -f rtp rtp://192.168.1.219:5555
//ffmpeg -re -i /Users/nab0y4enko/Library/Mobile\ Documents/com\~apple\~CloudDocs/2014-12-19.h264 -vcodec copy -f h264 -f h264 udp://192.168.0.100:5555

static NSString * const FDLoginViewControllerCustomNetworkPort = @"5555";

@interface FDLoginViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UISwitch *customPathSwitch;
@property (nonatomic, weak) IBOutlet UITextField *customPathTextField;

@property (nonatomic, copy) NSArray *paths;
@property (nonatomic, copy) NSString *rtpStreamPath;
@property (nonatomic, copy) NSString *sdpFilePath;

@end

@implementation FDLoginViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.rtpStreamPath = [NSString stringWithFormat:@"rtp://%@:%@", [NSString getIPAddress], FDLoginViewControllerCustomNetworkPort];
    self.sdpFilePath = [self createSDPFile];
    
    self.customPathSwitch.on = NO;
    self.customPathTextField.text = self.rtpStreamPath;
    
    self.paths = @[@"rtsp://mpl.dyndns.tv/MPL",
                   @"rtmp://s01.speednext.com:1935/odtuteknokent/odtuteknokent",
                   [[NSBundle mainBundle] pathForResource:@"2014-12-19" ofType:@"h264"],
                   self.rtpStreamPath];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateInterface];
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBActions

- (IBAction)customPathEnable:(id)sender {
    [self updateInterface];
}

- (IBAction)letsFly:(id)sender {
    NSString *pathToMovie;
    if (self.customPathSwitch.on) {
        pathToMovie = self.customPathTextField.text;
    } else if (![self.tableView indexPathForSelectedRow]) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Please select a stream" delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil] show];
        return;
    } else {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        pathToMovie = [cell.textLabel.text isEqualToString:self.rtpStreamPath] ? self.sdpFilePath : cell.textLabel.text;
    }
    
    FDDashboardViewController *dashboardViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"FDDashboardViewController"];
    dashboardViewController.path = pathToMovie;
    [self.navigationController pushViewController:dashboardViewController animated:YES];
}

#pragma mark - Private

- (void)updateInterface {
    self.customPathTextField.enabled = self.customPathSwitch.on;
    self.tableView.userInteractionEnabled = !self.customPathSwitch.on;
    self.tableView.alpha= self.customPathSwitch.on ? 0.5 : 1.0f;
}

- (NSString *)createSDPFile {
    NSError *error;
    NSString *sdpTemplatePath = [[NSBundle mainBundle] pathForResource:@"sdp_template" ofType:nil];
    NSString *sdpTemplate = [[NSString alloc] initWithContentsOfFile:sdpTemplatePath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        return nil;
    }
    NSString *sdpFileContent = [sdpTemplate stringByReplacingOccurrencesOfString:@"ip_address" withString:[NSString getIPAddress]];
    sdpFileContent = [sdpFileContent stringByReplacingOccurrencesOfString:@"port_number" withString:FDLoginViewControllerCustomNetworkPort];
    if (sdpFileContent.length == 0) {
        return nil;
    }
    
    NSString *applicationCacheDirectoryPath = [NSFileManager applicationCacheDirectoryPath];
    NSString *sdpFilePath = [applicationCacheDirectoryPath stringByAppendingPathComponent:@"stream.sdp"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:sdpFilePath]) {
        [fileManager createFileAtPath:sdpFilePath contents:nil attributes:nil];
    }
    
    [sdpFileContent writeToFile:sdpFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        return nil;
    }
    return sdpFilePath;
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.paths.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"PathsCellIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    cell.textLabel.text = self.paths[indexPath.row];
    return cell;
}

@end
