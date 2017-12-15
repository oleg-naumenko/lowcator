//
//  Locator.m
//  lowCatOr
//
//  Created by oleg.naumenko on 12/7/17.
//  Copyright © 2017 Bipper USA, Inc. All rights reserved.
//

#import "Locator.h"
#import <CoreLocation/CoreLocation.h>

@interface Locator()<CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager * locationManager;

@end

@implementation Locator
{
//    BOOL _useTogether;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _significantOnly = NO;
        _isRunning = NO;
//        _useTogether = YES;
    }
    return self;
}

- (void) start
{
    if (_isRunning) [self stop];
    
    if (!self.locationManager) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
    }
    if ([CLLocationManager authorizationStatus] <= kCLAuthorizationStatusDenied) {
        [self.locationManager requestWhenInUseAuthorization];
        [self.locationManager requestAlwaysAuthorization];
    }
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways) {
        [self.locationManager requestAlwaysAuthorization];
    }
    self.locationManager.pausesLocationUpdatesAutomatically = YES;
    self.locationManager.allowsBackgroundLocationUpdates = YES;
    self.locationManager.activityType = CLActivityTypeFitness;//CLActivityTypeAutomotiveNavigation;//
    [self.locationManager disallowDeferredLocationUpdates];
    
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways) {
        [self postUpdate:@"NOT AUTH FOR 'ALWAYS'!!!"];
        return;
    }
    [self.locationManager startMonitoringSignificantLocationChanges];
    
    if (!_significantOnly) {
        self.locationManager.distanceFilter = 100.;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        [self.locationManager startUpdatingLocation];
    }
    _isRunning = YES;
    [self postUpdate:[NSString stringWithFormat:@"STARTED: %@", (_significantOnly?@"sign":@"norm")]];
}

- (void) stop
{
    [self.locationManager stopUpdatingLocation];
    [self.locationManager stopMonitoringSignificantLocationChanges];
    _isRunning = NO;
    [self postUpdate:[NSString stringWithFormat:@"STOPPED: %@", (_significantOnly?@"sign":@"norm")]];
}

- (void) setSignificantOnly:(BOOL)significantOnly
{
    BOOL wasRunning = _isRunning;
    if (_isRunning) {
        [self stop];
    }
    _significantOnly = significantOnly;
    if (wasRunning) {
        [self start];
    }
}

- (void) postUpdate:(NSString *)string;
{
//    UIApplication * app = [UIApplication sharedApplication];
//    UIBackgroundTaskIdentifier bid = UIBackgroundTaskInvalid;
//    if (app.applicationState == UIApplicationStateBackground) {
//        [self postUpdate:@"== Asked for background task =="];
//        bid = [app beginBackgroundTaskWithExpirationHandler:^{
//            [self postUpdate:@"== Background task expired =="];
//        }];
//    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"LocationCenterUpdate" object:self userInfo:@{@"upd":string}];
    
//    if (bid != UIBackgroundTaskInvalid) {
//        [app endBackgroundTask:bid];
//    }
}

- (CLLocation *)location
{
    return self.locationManager.location;
}

- (CLLocation *)bestLocationFromLocations:(NSArray *)locations
{
    CLLocation* myBestLocation = nil;
    for (CLLocation *location in locations) {
//        NSLog(@"location horizontal accuracy: {%f,%f,%f}", location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy);
//        NSLog(@"Best location was: {%f,%f}", myBestLocation.coordinate.latitude, myBestLocation.coordinate.longitude);
        
        NSTimeInterval timeDelta = [location.timestamp timeIntervalSinceDate:myBestLocation.timestamp];
        myBestLocation = myBestLocation ? (timeDelta < 120. && location.horizontalAccuracy>0 && location.horizontalAccuracy < myBestLocation.horizontalAccuracy ? location : myBestLocation): location;
        NSLog(@"Best location is: {%f, %f, acc = %2.1f} out of %lu", myBestLocation.coordinate.latitude, myBestLocation.coordinate.longitude, myBestLocation.horizontalAccuracy, locations.count);
    }
    return myBestLocation;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
//    CLLocation * location = [self bestLocationFromLocations:locations];
//    _location = location;
    if (self.updateBlock) {
        self.updateBlock();
    }
//    CLLocationCoordinate2D coordinate = location.coordinate;
    //[NSString stringWithFormat: @"%2.5f,%2.5f-%lu", coordinate.latitude, coordinate.longitude, locations.count]];
}

- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager
{
    [self postUpdate:@"### PAUSED"];
    if (self.runStateBlock) self.runStateBlock(NO);
}

- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager
{
    [self postUpdate:@"### RESUMED"];
    if (self.runStateBlock) self.runStateBlock(YES);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSString * str = @"";
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:
            str = @"NotDetermined";
            break;
        case kCLAuthorizationStatusRestricted:
            str = @"Restricted";
            break;
        case kCLAuthorizationStatusDenied:
            str = @"StatusDenied";
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
            str = @"Always";
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            str = @"WhenInUse";
            break;
            
        default:
            break;
    }
    [self postUpdate:[NSString stringWithFormat: @"Auth: %@", str]];
}

- (void)locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(NSError *)error
{
    [self postUpdate:[NSString stringWithFormat: @"WAS DEFERRED"]];
}


@end
