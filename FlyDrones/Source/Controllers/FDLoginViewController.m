//
//  FDLoginViewController.m
//  FlyDrones
//
//  Created by Oleksii Naboichenko on 4/3/15.
//  Copyright (c) 2015 Oleksii Naboichenko. All rights reserved.
//

@import Foundation;

#import "MBProgressHUD.h"

#import "GIKAnnotation.h"
#import "GIKAnnotationView.h"
#import "GIKCalloutAnnotation.h"
#import "GIKCalloutView.h"

#import "AppDelegate.h"
#import "FDLoginViewController.h"
#import "FDDroneStatus.h"

#define UAS_NET_TIMER 0

@interface FDLoginViewController () <MKMapViewDelegate>
{
#if UAS_NET_TIMER
    NSTimer *timer;
    NSURLConnection *currentConnection;
#endif

    NSInteger httpCode;
    NSMutableData *body;
    NSString *validToken;
    NSDate *validTokenTS;
}

@property (nonatomic, weak) IBOutlet UIButton *button;
@property (weak, nonatomic) IBOutlet UITextField *tokenTextField;
@property (nonatomic, weak) IBOutlet MKMapView *mapView;
@property (nonatomic, weak) MKAnnotationView *selectedAnnotationView;

@end

@implementation FDLoginViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

#if UAS_NET_TIMER
    self.mapView.delegate = self;
    self.mapView.mapType = MKMapTypeSatellite;
    self.mapView.zoomEnabled = YES;
    self.mapView.scrollEnabled = YES;
    self.mapView.pitchEnabled = YES;
    self.mapView.rotateEnabled = NO;
    self.mapView.showsUserLocation = NO;

    self.mapView.showsPointsOfInterest = NO;
    self.mapView.showsBuildings = NO;

    CLLocationCoordinate2D center = { .latitude = 0, .longitude = 0 };
    MKCoordinateSpan span = { .latitudeDelta = 180, .longitudeDelta = 360 };
    MKCoordinateRegion region = { .center = center, .span = span };
    [self.mapView setRegion:region animated:false];

    NSString *version =  [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if (version != nil) {
        [self.button setTitle:version forState:UIControlStateNormal];
    }
#endif

    body = [NSMutableData dataWithCapacity:0];
}

//- (void)viewWillAppear:(BOOL)animated {
//    [super viewWillAppear:animated];
//}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

#if UAS_NET_TIMER
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
#endif

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

#if UAS_NET_TIMER
    [self startTimer];
#endif

    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    if (appDelegate.token && appDelegate.token.length == 9) {
        [self                     textField:self.tokenTextField
              shouldChangeCharactersInRange:NSMakeRange(0, self.tokenTextField.text.length)
                          replacementString:appDelegate.token];
        appDelegate.token = @"";
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

#if UAS_NET_TIMER
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopTimer];
#endif
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    body.length = 0;
}

#if UAS_NET_TIMER
- (void)applicationDidEnterBackground {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];

    [self stopTimer];
}
#endif

- (void)applicationDidBecomeActive {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];

    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    if (appDelegate.token && appDelegate.token.length == 9) {
        [self                     textField:self.tokenTextField
              shouldChangeCharactersInRange:NSMakeRange(0, self.tokenTextField.text.length)
                          replacementString:appDelegate.token];
        appDelegate.token = @"";
    }

#if UAS_NET_TIMER
    [self startTimer];
#endif
}

#pragma - Actions

- (IBAction)buttonTapped:(id)sender {
    NSLog(@"Button Tapped");

    // keep current token valid for 30min

    if ([validToken isEqualToString:self.tokenTextField.text]
            && validTokenTS.timeIntervalSinceNow < 30 * 60) { // 30 min
        [self performSegueWithIdentifier:@"showRootViewController" sender:self];
        return;
    }
    validToken = @"";
    validTokenTS = [NSDate distantPast];

    // if the token is made up of the same character
    // go to the settings view

    BOOL allSame = TRUE;
    unichar c0 = [self.tokenTextField.text characterAtIndex:0];
    for (NSUInteger i = 1; i < self.tokenTextField.text.length; ++i) {
        unichar c = [self.tokenTextField.text characterAtIndex:i];
        if (c != '-' && c0 != c) {
            allSame = FALSE;
            break;
        }
    }
    if (allSame) {
        [self performSegueWithIdentifier:@"showSettingsViewController" sender:self];
        return;
    }

    // validate token with server

#ifndef DEBUG
    static NSString *baseURL = @"http://108.26.177.27:5000/token/";
#else
    static NSString *baseURL = @"http://nick:5000/token/";
#endif

    NSURL *url = [NSURL URLWithString:self.tokenTextField.text
                        relativeToURL:[NSURL URLWithString:baseURL]];
    NSURLRequest *req = [NSURLRequest requestWithURL:url.absoluteURL
                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                     timeoutInterval:20];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:req
                                                                  delegate:self];
    if (! connection) {
        NSLog(@"Error creating connection %@!", url);

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:[NSString stringWithFormat:@"Cannot connect to %@", req.URL]
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    } else {
        [self connectionStarted];
    }
}

#pragma - NSTextFieldDelegate

- (BOOL)            textField:(UITextField * _Nonnull)textField
shouldChangeCharactersInRange:(NSRange)range
            replacementString:(NSString * _Nonnull)string {

    // Prevent crashing undo bug
    if (range.length + range.location > textField.text.length)
        return NO;

    // limit to 9 char (4+"-"+4)
    if (textField.text.length + string.length - range.length > 9)
        return NO;

    // only accept [A-Z0-9-]
    NSCharacterSet *invalidCharSet = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"] invertedSet];
    for (NSUInteger i = 0; i < string.length; ++i) {
        if ([invalidCharSet characterIsMember:[string characterAtIndex:i]])
            return NO;
    }

    NSMutableString *newText = [NSMutableString stringWithString:textField.text];
    [newText replaceOccurrencesOfString:@"-"
                             withString:@""
                                options:0
                                  range:NSMakeRange(0, [newText length])]; // remove existing "-"
    if (range.location + range.length >= 5)
    {
        // adjust range since we've remove the "-" from under it
        if (range.location > 0)
            range.location -= 1;
        else if (range.length > 0)
            range.length -= 1;
    }
    [newText replaceCharactersInRange:range
                           withString:string];
    [newText replaceOccurrencesOfString:@"-"
                             withString:@""
                                options:0
                                  range:NSMakeRange(0, [newText length])]; // remove "-" potentially added by string

    if (newText.length >= 4)
        [newText insertString:@"-" atIndex:4];

    self.button.enabled = newText.length == 9;

    textField.text = newText;
    return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSLog(@"textFieldShouldReturn");
    if (! self.button.enabled)
        return NO;
    [textField resignFirstResponder]; // hide keyboard
    [self buttonTapped:textField];
    return YES;
}

#pragma mark - URLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    httpCode = ((NSHTTPURLResponse *)response).statusCode;
    body.length = 0;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [body appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"Succeeded (%ld)! Received %lu bytes of data", (long)httpCode, (unsigned long)body.length);

    [self connectionEnded];

    if (httpCode == 200) {
        NSLog(@"%@", body);

        NSError *error = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:body
                                                             options:0
                                                               error:&error];
        body.length = 0;
        if (error || ! json) {
            if (error)
                NSLog(@"Error parsing JSON: %@", [error localizedDescription]);
            else
                NSLog(@"Error parsing JSON");

            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Couldn't parse token"
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }

        validToken = self.tokenTextField.text;
        validTokenTS = [NSDate date];

        NSDictionary *control = [json objectForKey:@"control"];
        if (! control) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"No control in token"
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }

        NSDictionary *video = [json objectForKey:@"video"];
        if (! video) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"No video in token"
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }

        FDDroneStatus *currentDroneStatus = [FDDroneStatus currentStatus];
        currentDroneStatus.pathForUDPConnection = [video objectForKey:@"host"];
        currentDroneStatus.portForUDPConnection = ((NSNumber *)[video objectForKey:@"port"]).integerValue;
        currentDroneStatus.pathForTCPConnection = [control objectForKey:@"host"];
        currentDroneStatus.portForTCPConnection = ((NSNumber *)[control objectForKey:@"port"]).integerValue;

        currentDroneStatus.videoSize = CGSizeMake(((NSNumber *)[video objectForKey:@"width"]).integerValue,
                                                  ((NSNumber *)[video objectForKey:@"height"]).integerValue);
        currentDroneStatus.videoFps = ((NSNumber *)[video objectForKey:@"fps"]).integerValue;
        currentDroneStatus.videoResolution = currentDroneStatus.videoSize.width * currentDroneStatus.videoSize.height / 1000.0f / 1000.0f;
        currentDroneStatus.videoBitrate = ((NSNumber *)[video objectForKey:@"bitrate"]).integerValue;

        currentDroneStatus.altitudeMin = 0;

        NSDictionary *limits = [json objectForKey:@"limits"];
        if (limits) {
            NSNumber *altitudeMin = (NSNumber *)[limits objectForKey:@"altitdeMin"];
            if (altitudeMin)
                currentDroneStatus.altitudeMin = altitudeMin.integerValue;
        }

        [self performSegueWithIdentifier:@"showRootViewController" sender:self];
    } else {
        body.length = 0;

        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeText;
        hud.labelText = [NSString stringWithFormat:@"Error %ld", (long)httpCode];
        [hud hide:YES afterDelay:5];

        if (httpCode == 404) { // invalid token
            hud.detailsLabelText = @"Invalid Token";
        } else if (httpCode == 403) { // expired token
            hud.detailsLabelText = @"Expired Token";
        } else {
            // can't use stringWithUTF8String: since body isn't NULL terminated
            hud.detailsLabelText = [[NSString alloc] initWithBytes:body.bytes
                                                            length:body.length
                                                          encoding:NSUTF8StringEncoding]; // FIXME: might not be UTF-8
        }
    }
}

#pragma mark - URLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);

    [self connectionEnded];
    body.length = 0;

    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    if (! hud)
        hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"Error";
    hud.detailsLabelText = [NSString stringWithFormat:@"%@", [error localizedDescription]];
    [hud hide:YES afterDelay:5];
}

#pragma mark -

- (void)connectionStarted {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.color = [UIColor colorWithRed:24.0f/255.0f green:43.0f/255.0f blue:72.0f/255.0f alpha:0.5f];
    hud.mode = MBProgressHUDModeIndeterminate;

    self.tokenTextField.enabled = NO;
    self.button.enabled = NO;
}

- (void)connectionEnded {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [MBProgressHUD hideHUDForView:self.view animated:YES];

    self.tokenTextField.enabled = YES;
    self.button.enabled = YES;
}

#if UAS_NET_TIMER

#pragma mark - Timer

- (void)startTimer {

    if (![timer isValid]) {
        timer = [NSTimer timerWithTimeInterval:30
                                             target:self
                                           selector:@selector(timerFire:)
                                           userInfo:nil
                                            repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer
                                  forMode:NSRunLoopCommonModes];

        [timer fire];
    }
}

- (void)stopTimer {
    [timer invalidate];
    timer = nil;
}

- (void)timerFire:(NSTimer *)timer {

    if (currentConnection) return;

    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://nick:5000/UAS"]
                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                     timeoutInterval:20];
    currentConnection = [[NSURLConnection alloc] initWithRequest:req
                                                        delegate:self];
    if (! currentConnection) {
        NSLog(@"Error creating connection!");

        [MBProgressHUD hideAllHUDsForView:self.mapView animated:NO];

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:[NSString stringWithFormat:@"Cannot connect to %@", req.URL]
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    } else if (self.mapView.annotations.count == 0) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.mapView animated:YES];
        hud.labelText = @"Loading UAS...";
        hud.color = [UIColor colorWithRed:24.0f/255.0f green:43.0f/255.0f blue:72.0f/255.0f alpha:0.5f];
        hud.mode = MBProgressHUDModeIndeterminate;
    }
}

#pragma mark - URLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    body.length = 0;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [body appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"Succeeded! Received %lu bytes of data", (unsigned long)[body length]);

    NSError *error = nil;
    NSArray* json = [NSJSONSerialization JSONObjectWithData:body
                                                    options:0
                                                      error:&error];
    if (error) {
        NSLog(@"Error parsing JSON: %@", [error localizedDescription]);
    } else if (! json) {
        NSLog(@"Error parsing JSON");
    } else {

        NSArray<id<MKAnnotation>> *currentAnnotations = self.mapView.annotations;

        id<MKAnnotation> selectedAnnotation = nil;
        if (self.selectedAnnotationView) {
            selectedAnnotation = (id<MKAnnotation>) self.selectedAnnotationView.annotation;

            NSMutableArray<id<MKAnnotation>> *mutableAnnotations = [NSMutableArray arrayWithCapacity:currentAnnotations.count];
            NSEnumerator *it = [currentAnnotations objectEnumerator];
            id<MKAnnotation> annotation;
            while (annotation = [it nextObject]) {
                if (annotation == selectedAnnotation)
                    continue;
                if (annotation.coordinate.latitude == selectedAnnotation.coordinate.latitude
                        && annotation.coordinate.longitude == selectedAnnotation.coordinate.longitude)
                    continue;
                [mutableAnnotations addObject:annotation];
            }

            currentAnnotations = mutableAnnotations;
        }

        [self.mapView removeAnnotations:currentAnnotations];

        for (NSDictionary *doc in json) {
            NSLog(@"json doc: %@", doc);

            NSDictionary *_id = [doc objectForKey:@"_id"];
            if (! _id) continue;

            NSDictionary *gps = [doc objectForKey:@"gps"];
            if (! gps) continue;

            NSString *type = [gps objectForKey:@"type"];
            if (! type || ![type isEqualToString:@"Point"]) continue;

            NSArray *coordinates = [gps objectForKey:@"coordinates"];
            if (! coordinates || coordinates.count < 2) continue;


#if 1
            GIKAnnotation *annotation = [[GIKAnnotation alloc] initWithLatitude:((NSNumber *)[coordinates objectAtIndex:1]).doubleValue
                                                                      longitude:((NSNumber *)[coordinates objectAtIndex:0]).doubleValue];

#else
            MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
            CLLocationCoordinate2D coord2d = { .latitude = ((NSNumber *)[coordinates objectAtIndex:1]).doubleValue,
                                               .longitude = ((NSNumber *)[coordinates objectAtIndex:0]).doubleValue };
            annotation.coordinate = coord2d;
            annotation.title = @"title";
            annotation.subtitle = @"substitle";
#endif

            if (selectedAnnotation
                    && selectedAnnotation.coordinate.latitude  == annotation.coordinate.latitude
                    && selectedAnnotation.coordinate.longitude == annotation.coordinate.longitude)
                continue;

            [self.mapView addAnnotation:annotation];
        }
    }

    self->currentConnection = nil;
    body.length = 0;

    [MBProgressHUD hideHUDForView:self.mapView animated:YES];
}

#pragma mark - URLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);

    [self.mapView removeAnnotations:self.mapView.annotations];

    self->currentConnection = nil;
    body.length = 0;

    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.mapView];
    if (! hud)
        hud = [MBProgressHUD showHUDAddedTo:self.mapView animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"Error";
    hud.detailsLabelText = [NSString stringWithFormat:@"%@ %@", [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey], [error localizedDescription]];
    [hud hide:YES afterDelay:5];
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKPointAnnotation class]]) {
        static NSString *AnnotationViewIdentifier = @"annotationViewID";

        MKAnnotationView *annotationView = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:AnnotationViewIdentifier];
        if (annotationView == nil) {
            annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AnnotationViewIdentifier];
            annotationView.enabled = YES;
            annotationView.canShowCallout = NO; // We want to show our own callout
            annotationView.image = [UIImage imageNamed:@"Helicopter"];
        }
        annotationView.annotation = annotation;
        return annotationView;
    } else if ([annotation isKindOfClass:[GIKAnnotation class]]) {
        static NSString *kGIKAnnotationID = @"GIKAnnotation";

        GIKAnnotationView *annotationView = (GIKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:kGIKAnnotationID];
        if (annotationView == nil) {
            annotationView = [[GIKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:kGIKAnnotationID];
            annotationView.enabled = YES;
            annotationView.canShowCallout = NO; // We want to show our own callout
            annotationView.image = [UIImage imageNamed:@"Helicopter"];
        }
        annotationView.annotation = annotation;
        return annotationView;
    } else if ([annotation isKindOfClass:[GIKCalloutAnnotation class]]) {
        static NSString *kGIKCalloutID = @"GIKCallout";

        GIKCalloutView *calloutView = (GIKCalloutView *)[mapView dequeueReusableAnnotationViewWithIdentifier:kGIKCalloutID];
        if (calloutView == nil) {
            calloutView = [[GIKCalloutView alloc] initWithAnnotation:annotation reuseIdentifier:kGIKCalloutID];
            calloutView.enabled = YES;
            calloutView.canShowCallout = NO;
        }

        calloutView.parentAnnotationView = self.selectedAnnotationView;
        calloutView.mapView = self.mapView;


        GIKCalloutContentView *calloutContentView = [GIKCalloutContentView viewWithLabelText:@"title"];
        calloutContentView.mode = GIKContentModeDetail;
        calloutContentView.delegate = calloutView;
//        calloutContentView.detailView = self.calloutDetailController.view;

UIView *detailView = [[UIView alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];;
calloutContentView.detailView = detailView;
calloutContentView.detailView.backgroundColor = [UIColor redColor];

        calloutView.calloutContentView = calloutContentView;

//        [calloutView accessoryButtonTapped];
        return calloutView;
    } else {
        return nil;
    }
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray<MKAnnotationView *> *)views {
    NSLog(@"didAddAnnotationViews: %lu", (unsigned long)views.count);
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    if (! [view.annotation isKindOfClass:[GIKAnnotation class]])
        return;

    GIKAnnotation *selectedAnnotation = (GIKAnnotation *)view.annotation;
    if ([mapView.annotations indexOfObject:selectedAnnotation.callout] != NSNotFound)
        return;

    NSLog(@"didSelectAnnotationView: %@", view);

    GIKCalloutAnnotation *callout = [[GIKCalloutAnnotation alloc] initWithLocation:view.annotation.coordinate];
    [mapView addAnnotation:callout];

    selectedAnnotation.callout = callout;
    self.selectedAnnotationView = view;
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view {
    NSLog(@"didDeselectAnnotationView: %@", view);

	// Only remove the custom annotation (GIKCalloutAnnotation) if the parent annotation view can be deselected (selectionEnabled = YES)
    if ([view.annotation isKindOfClass:[GIKAnnotation class]] && ((GIKAnnotationView *)view).selectionEnabled) {
        [mapView removeAnnotation:((GIKAnnotation *)view.annotation).callout];
    }

    self.selectedAnnotationView = nil;
}

#endif

@end
