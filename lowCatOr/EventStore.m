//
//  EventStore.m
//  lowCatOr
//
//  Created by oleg.naumenko on 12/14/17.
//  Copyright © 2017 Bipper USA, Inc. All rights reserved.
//

#import "EventStore.h"
#import <CoreLocation/CoreLocation.h>

#define SCHEMA_VERSION 4

@implementation EventStore
{
    RLMRealm * realm;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        realm = [RLMRealm defaultRealm];
        
        RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
        config.schemaVersion = SCHEMA_VERSION;
        config.migrationBlock = ^(RLMMigration *migration, uint64_t oldSchemaVersion) {
            NSLog(@"Realm migration from v.%llul to v.%ul", oldSchemaVersion, SCHEMA_VERSION);
        };
        [RLMRealmConfiguration setDefaultConfiguration:config];
        
        RLMResults<Event*> * shots = [Event allObjects];
        _events = [shots sortedResultsUsingKeyPath:@"date" ascending:YES];
    }
    return self;
}

- (void) addEvent:(Event*)event completion:(void(^)(void))completion
{
    [realm transactionWithBlock:^{
        [realm addObject:event];
    }];
    if (completion) completion();
}

- (void)removeEvent:(Event *)event completion:(void (^)(void))completion
{
    [realm transactionWithBlock:^{
        [realm deleteObject:event];
    }];
    if (completion) completion();
}

- (void) removeAll
{
    [realm transactionWithBlock:^{
        [realm deleteAllObjects];
    }];
}

@end
