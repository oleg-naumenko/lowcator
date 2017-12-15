//
//  EventStore.h
//  lowCatOr
//
//  Created by oleg.naumenko on 12/14/17.
//  Copyright © 2017 Bipper USA, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Realm/Realm.h>
#import "Event.h"

@interface EventStore : NSObject

@property (nonatomic, readonly) RLMResults<Event*> * events;

- (void) addEvent:(Event*)event completion:(void(^)(void))completion;
- (void) removeEvent:(Event*)event completion:(void(^)(void))completion;
- (void) removeAll;

@end
