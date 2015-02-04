//
//  Observation.h
//  henge
//
//  Created by Jeff Kunzelman on 2/4/15.
//  Copyright (c) 2015 River.io. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Action, Crop;

@interface Observation : NSManagedObject

@property (nonatomic, retain) NSNumber * vigor;
@property (nonatomic, retain) NSNumber * diseasePests;
@property (nonatomic, retain) NSNumber * ripeness;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSString * photoPath;
@property (nonatomic, retain) Crop *crop;
@property (nonatomic, retain) Action *action;

@end
