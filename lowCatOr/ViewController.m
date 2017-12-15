//
//  ViewController.m
//  lowCatOr
//
//  Created by oleg.naumenko on 12/7/17.
//  Copyright © 2017 Bipper USA, Inc. All rights reserved.
//

#import <UserNotifications/UserNotifications.h>
#import <MapKit/MapKit.h>
#import <libextobjc/extobjc.h>
#import "ViewController.h"
#import "Locator.h"
#import "Annotation.h"
#import "EventStore.h"

@interface ViewController () <MKMapViewDelegate>
@property (nonatomic, strong) Locator * locator;
@property (nonatomic, weak) IBOutlet UITextView * textView;
@property (nonatomic, weak) IBOutlet UIButton * startButton;
@property (nonatomic, weak) IBOutlet UIButton * clearButton;
@property (nonatomic, weak) IBOutlet UIButton * signButton;
@property (nonatomic, weak) IBOutlet UIButton * textShowButton;

@property (nonatomic, strong) EventStore * store;
@property (nonatomic, strong) MKMapView * mapView;

@end

@implementation ViewController
{
    CGRect maxiTextRect;
    CGRect miniTextRect;
    BOOL _textMinimized;
    RLMNotificationToken * _storeToken;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.store = [[EventStore alloc] init];
    [self addEventWithTitle:@"===== AWAKE =====" type:EventTypeOther];
    
    _storeToken = [self.store.events addNotificationBlock:^(RLMResults<Event *> * results,
                                                            RLMCollectionChange * change,
                                                            NSError * error) {
        
        NSLog(@"REALM: c: %lu - in: %lu (%@) del: %lu (%@)", results.count, change.insertions.count, change.insertions.firstObject, change.deletions.count, change.deletions.firstObject);
        
        for (NSNumber * indexNum in change.insertions) {
            Event * event = results[indexNum.integerValue];
            NSLog(@"E: %@ %2.6f", event.title, event.coordLongitude);

            if (event.eventType == EventTypeLocation) {
                Annotation * ann = [[Annotation alloc] init];
                CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(event.coordLatitude, event.coordLongitude);
                ann.coordinate = coordinate;
                ann.title = event.title;
                ann.subtitle = event.subtitle;
                ann.uid = event.uid;
                [self.mapView addAnnotation:ann];
                [self.mapView setCenterCoordinate:coordinate animated:YES];
                
                NSString * str = [NSString stringWithFormat: @"%2.5f,%2.5f", coordinate.latitude, coordinate.longitude];
                [self logString:str forDate:event.date];
            } else {
                [self logString:event.title forDate:event.date];
            }
        }
        for (NSNumber * indexNum in change.deletions) {
            NSLog(@"Deleted: %@", indexNum);
        }
    }];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_storeToken invalidate];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    maxiTextRect = self.textView.frame;
    miniTextRect = maxiTextRect;
    miniTextRect.size.height = self.textShowButton.bounds.size.height;
    
    NSNotificationCenter * nCenter = [NSNotificationCenter defaultCenter];
    [nCenter addObserver:self selector:@selector(onUpdateNotification:) name:@"LocationCenterUpdate" object:nil];
    [nCenter addObserver:self selector:@selector(onAppState:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [nCenter addObserver:self selector:@selector(onAppState:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [nCenter addObserver:self selector:@selector(onAppState:) name:UIApplicationWillTerminateNotification object:nil];
    [nCenter addObserver:self selector:@selector(onAppState:) name:UIApplicationWillResignActiveNotification object:nil];
    [nCenter addObserver:self selector:@selector(onAppState:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    self.mapView = ({
        MKMapView *mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
        mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        mapView.delegate = self;
        mapView.showsCompass = YES;
        mapView.showsUserLocation = YES;
        mapView.mapType = MKMapTypeSatellite;
        MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(self.locator.location.coordinate, 1000, 1000);
        MKCoordinateRegion adjustedRegion = [mapView regionThatFits:viewRegion];
        [mapView setRegion:adjustedRegion animated:YES];
        mapView;
    });
    [self.view insertSubview:self.mapView atIndex:0];
    
    for (Event * event in self.store.events) {
        Annotation * ann = [[Annotation alloc] init];
        if (event.coordLongitude && event.coordLatitude) {
            ann.coordinate = CLLocationCoordinate2DMake(event.coordLatitude, event.coordLongitude);
            ann.title = event.title;
            ann.subtitle = event.subtitle;
            ann.uid = event.uid;
            [self.mapView addAnnotation:ann];
        }
    }
    for (Event * event in self.store.events) {
        NSString * str = nil;
        if (event.eventType == EventTypeLocation) {
            str = [NSString stringWithFormat: @"%2.5f,%2.5f", event.coordLatitude, event.coordLongitude];
        } else {
            str = event.title;
        }
        [self logString:str forDate:event.date];
    }
    
    self.locator = [[Locator alloc] init];
    NSNumber * num = [[NSUserDefaults standardUserDefaults] objectForKey:@"significant"];
    self.locator.significantOnly = num.boolValue;
    
    @weakify(self);
    self.locator.updateBlock = ^{
        @strongify(self);
        [self addEventWithTitle:@"Loc" type:EventTypeLocation];
        [self sendLocalNotificationIfNotActiveAndSignificant];
    };
    self.locator.runStateBlock = ^(BOOL running) {
        @strongify(self);
        [self sendLocalNotificationOnStateChange:running];
    };
    
    [self.locator start];
}


- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self updateButton];
}

- (void) updateButton
{
    if (self.locator.isRunning) {
        [self.startButton setTitle:@"STOP" forState:(UIControlStateNormal)];
        self.clearButton.hidden = YES;
        self.signButton.enabled = NO;
    } else {
        [self.startButton setTitle:@"START" forState:(UIControlStateNormal)];
        self.clearButton.hidden = NO;
        self.signButton.enabled = YES;
    }
    
    [self.signButton setTitle:(self.locator.significantOnly?@"sign":@"norm") forState:(UIControlStateNormal)];
}

- (IBAction)onStartButton:(UIButton*)sender
{
    if (self.locator.isRunning) {
        [self.locator stop];
    } else {
        [self.locator start];
    }
    [self updateButton];
}

- (IBAction)onClearButton:(UIButton*)sender
{
    [self.textView setText:nil];
    [self.store removeAll];
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self updateButton];
}

- (IBAction)onSignificantButton:(UIButton*)sender
{
    self.locator.significantOnly = !self.locator.significantOnly;
    [self updateButton];
    [[NSUserDefaults standardUserDefaults] setObject:@(self.locator.significantOnly) forKey:@"significant"];
}


- (IBAction)onTextShowButton:(UIButton*)sender
{
    _textMinimized  = !_textMinimized;
    if (_textMinimized) {
        self.textView.frame = miniTextRect;
        [self.textShowButton setTitle:@">" forState:(UIControlStateNormal)];
    } else {
        self.textView.frame = maxiTextRect;
        [self.textShowButton setTitle:@"^" forState:(UIControlStateNormal)];
    }
}

- (void) onAppState:(NSNotification*)n
{
    UIApplication * app = [UIApplication sharedApplication];
    if ([n.name isEqualToString:UIApplicationWillTerminateNotification]) {
        
        UIBackgroundTaskIdentifier bid = [app beginBackgroundTaskWithExpirationHandler:nil];
        
        [self addEventWithTitle:@"----- TERMINATE -----" type:EventTypeOther];
        NSUserDefaults * defs = [NSUserDefaults standardUserDefaults];
        [defs synchronize];
        [app endBackgroundTask:bid];
    }
    
    NSString * str = [[n.name stringByReplacingOccurrencesOfString:@"UIApplication" withString:@"*"] stringByReplacingOccurrencesOfString:@"Notification" withString:@""];
    str = [[str stringByReplacingOccurrencesOfString:@"Will" withString:@""] stringByReplacingOccurrencesOfString:@"Did" withString:@""];
    [self logString:str];
    [self updateButton];
}

- (void) onUpdateNotification:(NSNotification*)n
{
    NSDictionary * dict = n.userInfo;
    NSString * str = dict[@"upd"];
    [self addEventWithTitle:str type:EventTypeOther];
}

- (void) addEventWithTitle:(NSString*)title type:(EventType)type
{
    Event * event = [self eventWithTitle:title date:[self currentDate] type:type];
    [self.store addEvent:event completion:nil];
}

- (void) logString:(NSString*)str
{
    [self logString:str forDate:[self currentDate]];
}

- (void) logString:(NSString*)str forDate:(NSDate*)date
{
    NSString * desc = date.description;
    desc = [desc stringByReplacingOccurrencesOfString:@" +0000" withString:@""];
    
    NSString * outStr = [NSString stringWithFormat:@"%@ : %@\n", desc, str];
    [self.textView insertText:outStr];
    NSRange range = NSMakeRange(self.textView.text.length - 1, 0);
    [self.textView scrollRangeToVisible:range];
}

- (Event*)eventWithTitle:(NSString*)title date:(NSDate*)date type:(EventType)type
{
    Event * event = [[Event alloc] init];
    CLLocation * location = self.locator.location;
    event.isSignificantChangeMode = self.locator.significantOnly;
    event.coordLatitude = location.coordinate.latitude;
    event.coordLongitude = location.coordinate.longitude;
    event.coordAccuracy = location.horizontalAccuracy;
    event.date = date;
    event.uid = self.store.events.count;
    event.eventType = type;
    
    NSString * str = [NSString stringWithFormat: @"%2.5f,%2.5f", location.coordinate.latitude, location.coordinate.longitude];
    event.subtitle = str;
    
    if (event.eventType == EventTypeLocation) {
        NSString * desc = date.description;
        desc = [desc stringByReplacingOccurrencesOfString:@" +0000" withString:@""];
        event.title = desc;
    } else {
        event.title = title;
    }
    
    return event;
}

- (NSDate*)currentDate
{
    NSDate* currentDate = [NSDate date];
    NSTimeZone* currentTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    NSTimeZone* nowTimeZone = [NSTimeZone systemTimeZone];
    
    NSInteger currentGMTOffset = [currentTimeZone secondsFromGMTForDate:currentDate];
    NSInteger nowGMTOffset = [nowTimeZone secondsFromGMTForDate:currentDate];
    
    NSTimeInterval interval = nowGMTOffset - currentGMTOffset;
    NSDate* nowDate = [[NSDate alloc] initWithTimeInterval:interval sinceDate:currentDate];
    return nowDate;
}

- (NSString*)currentDateString
{
    NSString * desc = [self currentDate].description;
    return [desc stringByReplacingOccurrencesOfString:@" +0000" withString:@""];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void) sendLocalNotificationIfNotActiveAndSignificant
{
    UIApplication * app = [UIApplication sharedApplication];
    if (app.applicationState != UIApplicationStateActive && self.locator.significantOnly)
    {
        [self addEventWithTitle:@"Significant Backgr: YES" type:EventTypeOther];

        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1
                                                                                                        repeats:NO];
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.title = @"Significant Location Update";
//        content.subtitle = 
        CLLocation * loc = self.locator.location;
        content.body = [NSString stringWithFormat: @"Coords: %f, %f, %2.1f", loc.coordinate.latitude, loc.coordinate.latitude, loc.horizontalAccuracy];
        
        NSString *identifier = @"LoCatOrLocalNotification";
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                              content:content
                                                                              trigger:trigger];
        
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"Something went wrong: %@",error);
            }
        }];
    }
}

- (void) sendLocalNotificationOnStateChange:(BOOL)running
{
    UIApplication * app = [UIApplication sharedApplication];
    if (app.applicationState != UIApplicationStateActive)
    {
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1
                                                                                                        repeats:NO];
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.title = @"Location Manager State Change";
        content.body = (running?@"RESUME":@"PAUSED");
        
        NSString *identifier = @"LoCatOrLocalNotification";
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                              content:content
                                                                              trigger:trigger];
        
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"Something went wrong: %@",error);
            }
        }];
    }
}

@end
