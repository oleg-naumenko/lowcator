//
//  Locator.h
//  lowCatOr
//
//  Created by oleg.naumenko on 12/7/17.
//  Copyright © 2017 Bipper USA, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

typedef void(^LocationUpdateBlock)(void);
typedef void(^RunningStateBlock)(BOOL running);

@interface Locator : NSObject
- (void) start;
- (void) stop;

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, assign) BOOL significantOnly;
@property (nonatomic, readonly) CLLocation * location;
@property (nonatomic, copy) LocationUpdateBlock updateBlock;
@property (nonatomic, copy) RunningStateBlock runStateBlock;

@end
