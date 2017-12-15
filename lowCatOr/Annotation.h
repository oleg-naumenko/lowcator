//
//  Annotation.h
//  lowCatOr
//
//  Created by oleg.naumenko on 12/14/17.
//  Copyright © 2017 Bipper USA, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MapKit/MapKit.h>

@interface Annotation : NSObject<MKAnnotation>

@property (nonatomic, readwrite) CLLocationCoordinate2D coordinate;
@property (nonatomic, readwrite, copy) NSString * title;
@property (nonatomic, readwrite, copy) NSString * subtitle;

@property (nonatomic, assign) NSInteger uid;

@end
