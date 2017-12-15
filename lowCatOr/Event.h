//
//  Event.h
//  lowCatOr
//
//  Created by oleg.naumenko on 12/14/17.
//  Copyright © 2017 Bipper USA, Inc. All rights reserved.
//

#import <Realm/Realm.h>

typedef enum : NSUInteger {
    EventTypeLocation,
    EventTypeOther
} EventType;

@interface Event : RLMObject

@property NSInteger uid;

@property double coordLatitude;
@property double coordLongitude;
@property double coordAccuracy;

@property BOOL isSignificantChangeMode;

@property NSString * title;
@property NSString * subtitle;
@property NSDate * date;

@property int eventType;

@end
